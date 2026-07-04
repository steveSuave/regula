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
    this.labelDragPreview,
  });

  /// Radii (logical px) of an in-progress input marker: a filled dot
  /// inside a hollow ring, visually distinct from a plain point.
  static const double _markerDotRadius = 3;
  static const double _markerRingRadius = 7;

  /// Radius (logical px) of an angle's marker wedge. Like stroke widths,
  /// it does not scale with zoom.
  static const double _angleMarkerRadius = 20;

  /// How much wider (logical px) a selection halo is than the stroke it
  /// sits under; also the extra radius on a selected point's halo disc.
  static const double _haloExtra = 5;

  static const double _haloAlpha = 0.4;

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

  /// A label mid-drag: [offset] replaces the object's stored label
  /// offset for this frame only. The canvas holds the drag as widget
  /// state and commits one `ChangeAttributesCommand` at gesture end, so
  /// the construction is never mutated per frame.
  final ({String id, Offset offset})? labelDragPreview;

  @override
  void paint(Canvas canvas, Size size) {
    // Infinite lines are drawn with far-away endpoints; the clip keeps
    // that overdraw inside the canvas.
    canvas.clipRect(Offset.zero & size);

    for (final object in construction.objects) {
      if (!object.attributes.visible || !object.isDefined) {
        continue;
      }
      if (selectedIds.contains(object.id)) {
        final halo = Paint()
          ..color = selectionColor.withValues(alpha: _haloAlpha)
          ..strokeWidth = object.attributes.strokeWidth + _haloExtra
          ..style = PaintingStyle.stroke;
        _drawObject(canvas, size, object, halo, pointRadiusExtra: _haloExtra);
      }
      final color =
          Color(object.attributes.colorArgb ?? defaultColor.toARGB32());
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
      if (object.attributes.labelVisible &&
          object.attributes.name.isNotEmpty) {
        _drawLabel(canvas, object, color);
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
    }
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

  /// Paints the object's name beside its [labelAnchor], shifted by the
  /// stored label offset (or the in-progress [labelDragPreview]). Like
  /// stroke widths, the font size and offset are in logical pixels and
  /// do not scale with zoom.
  void _drawLabel(Canvas canvas, GeoObject object, Color color) {
    final preview = labelDragPreview;
    final offset = preview != null && preview.id == object.id
        ? preview.offset
        : Offset(object.attributes.labelDx, object.attributes.labelDy);
    final textPainter = TextPainter(
      text: TextSpan(
        text: object.attributes.name,
        style: TextStyle(color: color, fontSize: labelFontSize),
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

  /// Draws an angle as a small wedge outline at its vertex, opening from
  /// the start direction through the sweep (angles negate on screen, as in
  /// [_drawCarrierBranch]). The radius is fixed in screen space.
  void _drawAngleMarker(Canvas canvas, GeoAngle object, Paint paint) {
    final angle = object.angle!;
    final rect = Rect.fromCircle(
      center: viewport.worldToScreen(angle.vertex),
      radius: _angleMarkerRadius,
    );
    canvas.drawArc(
      rect,
      -angle.startDirection.angle,
      -angle.sweep,
      true,
      paint,
    );
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
      oldDelegate.labelDragPreview != labelDragPreview;
}
