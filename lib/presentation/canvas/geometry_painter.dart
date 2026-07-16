import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../domain/construction/construction.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/arc.dart';
import '../../domain/construction/objects/ray.dart';
import '../../domain/construction/objects/sector.dart';
import '../../domain/construction/objects/segment.dart';
import '../../domain/math/circle_eq.dart';
import '../../domain/math/vec2.dart';
import 'canvas_viewport.dart';
import 'dash_path.dart';
import 'grid_layout.dart';
import 'label_anchor.dart';
import 'label_layout.dart';

/// Paints the construction in insertion order (first added = bottom).
///
/// Skips undefined and invisible objects, per the `GeoObject` contract.
/// Stroke widths and point radii come from `ObjectAttributes` and are in
/// logical pixels — they do not scale with zoom (a hairline stays a
/// hairline). A named object with `labelVisible` gets its name painted
/// beside its [labelAnchor], in the object's own color.
class GeometryPainter extends CustomPainter {
  GeometryPainter({
    required this.construction,
    required this.viewport,
    required this.revision,
    required this.defaultColor,
    required this.selectionColor,
    this.selectedIds = const {},
    this.previewMarkers = const [],
    this.previewObjectIds = const {},
    this.labelDragPreview,
    this.showHidden = false,
    this.showAxes = false,
    this.showGrid = false,
    this.axisColor = const Color(0xFF757575),
    this.gridColor = const Color(0xFFE3E6EA),
  });

  /// Stroke widths of the background layer (logical px) and the font size
  /// of its tick labels.
  static const double _gridStrokeWidth = 1;
  static const double _axisStrokeWidth = 1.5;
  static const double _tickFontSize = 10;

  /// Screen-px gap between an axis and its tick labels.
  static const double _tickLabelGap = 3;

  /// Radii (logical px) of an in-progress input marker: a filled dot
  /// inside a hollow ring, visually distinct from a plain point.
  static const double _markerDotRadius = 3;
  static const double _markerRingRadius = 7;

  /// How much wider (logical px) a selection halo is than the stroke it
  /// sits under; also the extra radius on a selected point's halo disc.
  static const double _haloExtra = 5;

  static const double _haloAlpha = 0.4;

  /// Opacity factor for hidden objects while [showHidden] is on.
  static const double _hiddenAlpha = 0.35;

  /// Read live at paint time, in insertion (drawing) order.
  final Construction construction;

  final CanvasViewport viewport;

  /// The construction's revision when the painter was created — the
  /// construction mutates in place, so instance comparison alone can't
  /// drive repaints (same trick as `ConstructionState`). The instance
  /// still matters: `replace()` resets the revision, so a swapped-in
  /// construction can carry the same revision number as the old one.
  final int revision;

  /// Color for objects whose attributes carry no explicit color.
  final Color defaultColor;

  /// Ids of selected objects, drawn with a translucent halo underneath.
  final Set<String> selectedIds;

  /// Base color of the selection halo (alpha is the painter's business).
  final Color selectionColor;

  /// World positions of the active tool's in-progress inputs (see
  /// `ToolInputPreview`), drawn as markers on top of the construction.
  final List<Vec2> previewMarkers;

  /// Ids of existing objects the active tool has consumed as inputs
  /// (see `ToolInputPreview.previewObjectIds`), haloed exactly like a
  /// selection — the union with [selectedIds].
  final Set<String> previewObjectIds;

  /// A label mid-drag: [offset] replaces the object's stored label
  /// offset for this frame only. The canvas holds the drag as widget
  /// state and commits one `ChangeAttributesCommand` at gesture end, so
  /// the construction is never mutated per frame.
  final ({String id, Offset offset})? labelDragPreview;

  /// Renders hidden objects (and their labels) at [_hiddenAlpha] opacity
  /// instead of skipping them — the Show/Hide tool's view state, never
  /// persisted and never on in PNG export (which builds its own painter
  /// and leaves the default false).
  final bool showHidden;

  /// Draws the coordinate axes / the background grid behind every object
  /// (the Phase 36 `DocumentSettings` toggles). Both default off, so
  /// existing callers — exporter included — render byte-identically.
  final bool showAxes;
  final bool showGrid;

  /// Colors for the background layer, from the theme's `CanvasColors`
  /// extension (defaults match the light palette for theme-less callers).
  final Color axisColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Infinite lines are drawn with far-away endpoints; the clip keeps
    // that overdraw inside the canvas.
    canvas.clipRect(Offset.zero & size);

    if (showGrid || showAxes) {
      _drawBackground(canvas, size);
    }

    for (final object in construction.objects) {
      final hidden = !object.attributes.visible;
      if ((hidden && !showHidden) || !object.isDefined) {
        continue;
      }
      // A hidden object drawn through [showHidden] dims everything it
      // paints — halo, fill, stroke and label — by the same factor.
      final dim = hidden ? _hiddenAlpha : 1.0;
      if (selectedIds.contains(object.id) ||
          previewObjectIds.contains(object.id)) {
        final halo = Paint()
          ..color = selectionColor.withValues(alpha: _haloAlpha * dim)
          ..strokeWidth = object.attributes.strokeWidth + _haloExtra
          ..style = PaintingStyle.stroke;
        _drawObject(canvas, size, object, halo, pointRadiusExtra: _haloExtra);
      }
      final baseColor =
          Color(object.attributes.colorArgb ?? defaultColor.toARGB32());
      final color = hidden
          ? baseColor.withValues(alpha: baseColor.a * dim)
          : baseColor;
      final fillAlpha = object.attributes.fillAlpha;
      if (fillAlpha != null) {
        _drawFill(
          canvas,
          object,
          Paint()
            ..color = baseColor.withValues(alpha: fillAlpha * dim)
            ..style = PaintingStyle.fill,
        );
      }
      final paint = Paint()
        ..color = color
        ..strokeWidth = object.attributes.strokeWidth
        ..style = PaintingStyle.stroke;
      _drawObject(
        canvas,
        size,
        object,
        paint,
        dashPeriod: object.attributes.dashPeriod,
      );
      final text = labelText(object);
      if (text != null) {
        _drawLabel(canvas, object, text, color);
      }
    }

    final dot = Paint()..color = defaultColor;
    final ring = Paint()
      ..color = defaultColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final marker in previewMarkers) {
      final center = viewport.worldToScreen(marker);
      canvas.drawCircle(center, _markerDotRadius, dot);
      canvas.drawCircle(center, _markerRingRadius, ring);
    }
  }

  /// The Phase 36 background layer: grid hairlines at every multiple of
  /// the adaptive [gridStep], then 1.5-px axes through the world origin
  /// with tick labels — drawn first, so every object paints over it.
  /// Grid and axes are view chrome, not objects: hit testing, selection
  /// and fit never see them.
  void _drawBackground(Canvas canvas, Size size) {
    final step = gridStep(viewport.state.scale);
    // Visible world range; the viewport flips y, so the y extremes swap.
    final topLeft = viewport.screenToWorld(Offset.zero);
    final bottomRight = viewport.screenToWorld(
      Offset(size.width, size.height),
    );

    if (showGrid) {
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = _gridStrokeWidth;
      for (var i = (topLeft.x / step).ceil();
          i * step <= bottomRight.x;
          i++) {
        final x = viewport.worldToScreen(Vec2(i * step, 0)).dx;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      for (var i = (bottomRight.y / step).ceil();
          i * step <= topLeft.y;
          i++) {
        final y = viewport.worldToScreen(Vec2(0, i * step)).dy;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }

    if (showAxes) {
      final axis = Paint()
        ..color = axisColor
        ..strokeWidth = _axisStrokeWidth;
      final origin = viewport.worldToScreen(Vec2.zero);
      final xAxisVisible = origin.dy >= 0 && origin.dy <= size.height;
      final yAxisVisible = origin.dx >= 0 && origin.dx <= size.width;
      if (xAxisVisible) {
        canvas.drawLine(
          Offset(0, origin.dy),
          Offset(size.width, origin.dy),
          axis,
        );
      }
      if (yAxisVisible) {
        canvas.drawLine(
          Offset(origin.dx, 0),
          Offset(origin.dx, size.height),
          axis,
        );
      }
      _drawTickLabels(
        canvas,
        size,
        step,
        origin,
        topLeft: topLeft,
        bottomRight: bottomRight,
        xAxisVisible: xAxisVisible,
        yAxisVisible: yAxisVisible,
      );
    }
  }

  /// Tick labels at every grid multiple along the visible axes: x labels
  /// below the x-axis, y labels left of the y-axis, and a single `0` in
  /// the origin's lower-left quadrant instead of one per axis. Labels
  /// ride their axis — an off-screen axis shows none.
  void _drawTickLabels(
    Canvas canvas,
    Size size,
    double step,
    Offset origin, {
    required Vec2 topLeft,
    required Vec2 bottomRight,
    required bool xAxisVisible,
    required bool yAxisVisible,
  }) {
    void paintLabel(String text, Offset Function(Size textSize) place) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: axisColor, fontSize: _tickFontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, place(textPainter.size));
      textPainter.dispose();
    }

    if (xAxisVisible) {
      for (var i = (topLeft.x / step).ceil();
          i * step <= bottomRight.x;
          i++) {
        if (i == 0) {
          continue;
        }
        final x = viewport.worldToScreen(Vec2(i * step, 0)).dx;
        paintLabel(
          formatTick(i * step),
          (textSize) =>
              Offset(x - textSize.width / 2, origin.dy + _tickLabelGap),
        );
      }
    }
    if (yAxisVisible) {
      for (var i = (bottomRight.y / step).ceil();
          i * step <= topLeft.y;
          i++) {
        if (i == 0) {
          continue;
        }
        final y = viewport.worldToScreen(Vec2(0, i * step)).dy;
        paintLabel(
          formatTick(i * step),
          (textSize) => Offset(
            origin.dx - textSize.width - _tickLabelGap,
            y - textSize.height / 2,
          ),
        );
      }
    }
    if (xAxisVisible && yAxisVisible) {
      paintLabel(
        '0',
        (textSize) => Offset(
          origin.dx - textSize.width - _tickLabelGap,
          origin.dy + _tickLabelGap,
        ),
      );
    }
  }

  /// Draws one object with [paint] — both the normal pass and, with a
  /// wider translucent paint plus [pointRadiusExtra], the selection halo.
  ///
  /// [dashPeriod] > 0 draws stroked kinds dashed; the halo pass leaves it
  /// at 0 (a dashed halo under a dashed stroke is unreadable — the halo
  /// is selection UI, not object style). Points fill regardless, and
  /// angle markers stay solid for the wedge's readability.
  void _drawObject(
    Canvas canvas,
    Size size,
    GeoObject object,
    Paint paint, {
    double pointRadiusExtra = 0,
    double dashPeriod = 0,
  }) {
    switch (object) {
      case GeoPoint():
        canvas.drawCircle(
          viewport.worldToScreen(object.position!),
          object.attributes.pointSize + pointRadiusExtra,
          paint..style = PaintingStyle.fill,
        );
      case Segment():
        _drawStraight(
          canvas,
          viewport.worldToScreen(object.start!),
          viewport.worldToScreen(object.end!),
          paint,
          dashPeriod,
        );
      case Ray():
        _drawRay(canvas, size, object, paint, dashPeriod);
      case GeoLine():
        _drawInfiniteLine(canvas, size, object, paint, dashPeriod);
      case Arc():
        _drawCarrierBranch(
          canvas,
          object.circle!,
          object.startAngle!,
          object.sweep!,
          paint,
          dashPeriod: dashPeriod,
        );
      case Sector():
        _drawCarrierBranch(
          canvas,
          object.circle!,
          object.startAngle!,
          object.sweep!,
          paint,
          closeToCenter: true,
          dashPeriod: dashPeriod,
        );
      case GeoCircle():
        final circle = object.circle!;
        final center = viewport.worldToScreen(circle.center);
        final radius = viewport.worldToScreenLength(circle.radius);
        if (dashPeriod > 0) {
          final rim = Path()
            ..addOval(Rect.fromCircle(center: center, radius: radius));
          canvas.drawPath(dashPath(rim, dashPeriod), paint);
        } else {
          canvas.drawCircle(center, radius, paint);
        }
      case GeoAngle():
        _drawAngleMarker(canvas, object, paint);
      case GeoPolygon():
        final path = _polygonPath(object);
        canvas.drawPath(
          dashPeriod > 0 ? dashPath(path, dashPeriod) : path,
          paint,
        );
    }
  }

  /// The closed screen-space outline over a polygon's vertex loop —
  /// shared by the stroke, fill and halo passes.
  Path _polygonPath(GeoPolygon object) {
    final vertices = object.polygonVertices!;
    final first = viewport.worldToScreen(vertices.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final vertex in vertices.skip(1)) {
      final screen = viewport.worldToScreen(vertex);
      path.lineTo(screen.dx, screen.dy);
    }
    return path..close();
  }

  /// One straight stroke — solid via `drawLine`, or rebuilt as a dashed
  /// path when [dashPeriod] > 0.
  void _drawStraight(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dashPeriod,
  ) {
    if (dashPeriod > 0) {
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
      canvas.drawPath(dashPath(path, dashPeriod), paint);
    } else {
      canvas.drawLine(from, to, paint);
    }
  }

  /// Paints the object's [labelText] beside its [labelAnchor], shifted
  /// by the stored label offset (or the in-progress [labelDragPreview]).
  /// Like stroke widths, the font size and offset are in logical pixels
  /// and do not scale with zoom.
  void _drawLabel(Canvas canvas, GeoObject object, String text, Color color) {
    final preview = labelDragPreview;
    final offset = preview != null && preview.id == object.id
        ? preview.offset
        : Offset(object.attributes.labelDx, object.attributes.labelDy);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: object.attributes.labelFontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, viewport.worldToScreen(labelAnchor(object)) + offset);
    textPainter.dispose();
  }

  /// Draws a ray from its start extending far past the canvas on one side
  /// (the clip in [paint] trims it). Direction comes from the parent
  /// points, not the carrier — the carrier normalizes it away.
  void _drawRay(
    Canvas canvas,
    Size size,
    Ray object,
    Paint paint,
    double dashPeriod,
  ) {
    final start = viewport.worldToScreen(object.start!);
    final along = viewport.worldToScreen(object.throughPosition!) - start;
    final direction = along / along.distance;
    final reach = start.distance + size.width + size.height;
    _drawStraight(canvas, start, start + direction * reach, paint, dashPeriod);
  }

  /// Draws the branch of a circle carrier given by a start angle and a
  /// signed sweep — an arc, or with [closeToCenter] a sector's pie wedge
  /// (the two radii close the outline). World angles are counter-clockwise
  /// with y up; the viewport flips y, so both angles negate on screen.
  void _drawCarrierBranch(
    Canvas canvas,
    CircleEq circle,
    double startAngle,
    double sweep,
    Paint paint, {
    bool closeToCenter = false,
    double dashPeriod = 0,
  }) {
    final center = viewport.worldToScreen(circle.center);
    final rect = Rect.fromCircle(
      center: center,
      radius: viewport.worldToScreenLength(circle.radius),
    );
    if (dashPeriod > 0) {
      // The same screen-angle negation as the solid branch below; with
      // [closeToCenter] the path walks center → arc start → arc → back,
      // so the radii dash too.
      final path = Path();
      if (closeToCenter) {
        path.moveTo(center.dx, center.dy);
      }
      path.arcTo(rect, -startAngle, -sweep, !closeToCenter);
      if (closeToCenter) {
        path.close();
      }
      canvas.drawPath(dashPath(path, dashPeriod), paint);
    } else {
      canvas.drawArc(rect, -startAngle, -sweep, closeToCenter, paint);
    }
  }

  /// Fills the interior of a fillable kind — a sector's pie wedge, an
  /// angle marker's wedge/square, a polygon's region, or a full circle's
  /// disc — with [fill], drawn under the stroke pass. Other kinds have no
  /// filled form and are skipped; an arc's fill shape is ambiguous
  /// (wedge? circular segment?), so arcs deliberately don't fill.
  void _drawFill(Canvas canvas, GeoObject object, Paint fill) {
    switch (object) {
      case Sector():
        final circle = object.circle!;
        final rect = Rect.fromCircle(
          center: viewport.worldToScreen(circle.center),
          radius: viewport.worldToScreenLength(circle.radius),
        );
        canvas.drawArc(rect, -object.startAngle!, -object.sweep!, true, fill);
      case Arc():
        break;
      case GeoCircle():
        final circle = object.circle!;
        canvas.drawCircle(
          viewport.worldToScreen(circle.center),
          viewport.worldToScreenLength(circle.radius),
          fill,
        );
      case GeoAngle():
        _drawAngleMarker(canvas, object, fill);
      case GeoPolygon():
        canvas.drawPath(_polygonPath(object), fill);
      default:
        break;
    }
  }

  /// Draws an angle as a small wedge at its vertex, opening from the
  /// start direction through the sweep (angles negate on screen, as in
  /// [_drawCarrierBranch]). The radius comes from
  /// `attributes.angleMarkerRadius` and is fixed in screen space. A sweep
  /// of exactly π/2 — right angles from perpendicular constructions are
  /// fp-exact — draws the conventional square instead of the arc.
  ///
  /// [paint]'s style decides outline vs interior: the stroke pass and the
  /// fill pass share this geometry.
  void _drawAngleMarker(Canvas canvas, GeoAngle object, Paint paint) {
    final angle = object.angle!;
    if ((angle.sweep - math.pi / 2).abs() <= defaultEpsilon) {
      canvas.drawPath(_rightAngleSquarePath(object), paint);
      return;
    }
    final rect = Rect.fromCircle(
      center: viewport.worldToScreen(angle.vertex),
      radius: object.attributes.angleMarkerRadius,
    );
    canvas.drawArc(
      rect,
      -angle.startDirection.angle,
      -angle.sweep,
      true,
      paint,
    );
  }

  /// The right-angle marker: a closed square with corners at the vertex,
  /// at 0.7 × the marker radius along each arm, and at their vector sum.
  Path _rightAngleSquarePath(GeoAngle object) {
    final angle = object.angle!;
    final vertex = viewport.worldToScreen(angle.vertex);
    final side = 0.7 * object.attributes.angleMarkerRadius;
    final d1 = angle.startDirection;
    final d2 = d1.rotated(angle.sweep);
    // World directions are y-up; the screen flips y.
    Offset corner(Vec2 d) => vertex + Offset(d.x, -d.y) * side;
    final c1 = corner(d1);
    final c12 = corner(d1 + d2);
    final c2 = corner(d2);
    return Path()
      ..moveTo(vertex.dx, vertex.dy)
      ..lineTo(c1.dx, c1.dy)
      ..lineTo(c12.dx, c12.dy)
      ..lineTo(c2.dx, c2.dy)
      ..close();
  }

  /// Draws the visible stretch of an infinite line by extending far past
  /// the canvas on both sides (the clip in [paint] trims it).
  void _drawInfiniteLine(
    Canvas canvas,
    Size size,
    GeoLine object,
    Paint paint,
    double dashPeriod,
  ) {
    final line = object.line!;
    final anchor = viewport.worldToScreen(line.pointOnLine);
    // Screen-space direction; y-flip is handled by the transform.
    final along =
        viewport.worldToScreen(line.pointOnLine + line.direction) - anchor;
    final direction = along / along.distance;
    // Long enough to cross the whole canvas from wherever the anchor sits
    // (the anchor is the line's closest point to the *world* origin and
    // can be far off-screen when panned/zoomed away).
    final reach = anchor.distance + size.width + size.height;
    _drawStraight(
      canvas,
      anchor - direction * reach,
      anchor + direction * reach,
      paint,
      dashPeriod,
    );
  }

  @override
  bool shouldRepaint(GeometryPainter oldDelegate) =>
      !identical(oldDelegate.construction, construction) ||
      oldDelegate.revision != revision ||
      oldDelegate.viewport.state != viewport.state ||
      oldDelegate.defaultColor != defaultColor ||
      oldDelegate.selectionColor != selectionColor ||
      !setEquals(oldDelegate.selectedIds, selectedIds) ||
      !listEquals(oldDelegate.previewMarkers, previewMarkers) ||
      !setEquals(oldDelegate.previewObjectIds, previewObjectIds) ||
      oldDelegate.labelDragPreview != labelDragPreview ||
      oldDelegate.showHidden != showHidden ||
      oldDelegate.showAxes != showAxes ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.axisColor != axisColor ||
      oldDelegate.gridColor != gridColor;
}
