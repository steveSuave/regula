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

/// Paints the construction in insertion order (first added = bottom).
///
/// Skips undefined and invisible objects, per the `GeoObject` contract.
/// Stroke widths and point radii come from `ObjectAttributes` and are in
/// logical pixels — they do not scale with zoom (a hairline stays a
/// hairline). Labels land with the attributes work in Phase 7.
class GeometryPainter extends CustomPainter {
  GeometryPainter({
    required this.construction,
    required this.viewport,
    required this.revision,
    required this.defaultColor,
    required this.selectionColor,
    this.selectedIds = const {},
    this.previewMarkers = const [],
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
      final paint = Paint()
        ..color = Color(object.attributes.colorArgb ?? defaultColor.toARGB32())
        ..strokeWidth = object.attributes.strokeWidth
        ..style = PaintingStyle.stroke;
      _drawObject(canvas, size, object, paint);
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
  void _drawObject(
    Canvas canvas,
    Size size,
    GeoObject object,
    Paint paint, {
    double pointRadiusExtra = 0,
  }) {
    switch (object) {
      case GeoPoint():
        canvas.drawCircle(
          viewport.worldToScreen(object.position!),
          object.attributes.pointSize + pointRadiusExtra,
          paint..style = PaintingStyle.fill,
        );
      case Segment():
        canvas.drawLine(
          viewport.worldToScreen(object.start!),
          viewport.worldToScreen(object.end!),
          paint,
        );
      case Ray():
        _drawRay(canvas, size, object, paint);
      case GeoLine():
        _drawInfiniteLine(canvas, size, object, paint);
      case Arc():
        _drawCarrierBranch(
          canvas,
          object.circle!,
          object.startAngle!,
          object.sweep!,
          paint,
        );
      case Sector():
        _drawCarrierBranch(
          canvas,
          object.circle!,
          object.startAngle!,
          object.sweep!,
          paint,
          closeToCenter: true,
        );
      case GeoCircle():
        final circle = object.circle!;
        canvas.drawCircle(
          viewport.worldToScreen(circle.center),
          viewport.worldToScreenLength(circle.radius),
          paint,
        );
      case GeoAngle():
        _drawAngleMarker(canvas, object, paint);
    }
  }

  /// Draws a ray from its start extending far past the canvas on one side
  /// (the clip in [paint] trims it). Direction comes from the parent
  /// points, not the carrier — the carrier normalizes it away.
  void _drawRay(Canvas canvas, Size size, Ray object, Paint paint) {
    final start = viewport.worldToScreen(object.start!);
    final along = viewport.worldToScreen(object.throughPosition!) - start;
    final direction = along / along.distance;
    final reach = start.distance + size.width + size.height;
    canvas.drawLine(start, start + direction * reach, paint);
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
  }) {
    final rect = Rect.fromCircle(
      center: viewport.worldToScreen(circle.center),
      radius: viewport.worldToScreenLength(circle.radius),
    );
    canvas.drawArc(rect, -startAngle, -sweep, closeToCenter, paint);
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
    canvas.drawLine(
      anchor - direction * reach,
      anchor + direction * reach,
      paint,
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
      !listEquals(oldDelegate.previewMarkers, previewMarkers);
}
