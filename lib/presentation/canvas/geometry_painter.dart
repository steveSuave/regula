import 'package:flutter/rendering.dart';

import '../../domain/construction/construction.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/segment.dart';
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
  });

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

  @override
  void paint(Canvas canvas, Size size) {
    // Infinite lines are drawn with far-away endpoints; the clip keeps
    // that overdraw inside the canvas.
    canvas.clipRect(Offset.zero & size);

    for (final object in construction.objects) {
      if (!object.attributes.visible || !object.isDefined) {
        continue;
      }
      final paint = Paint()
        ..color = Color(object.attributes.colorArgb ?? defaultColor.toARGB32())
        ..strokeWidth = object.attributes.strokeWidth
        ..style = PaintingStyle.stroke;

      switch (object) {
        case GeoPoint():
          canvas.drawCircle(
            viewport.worldToScreen(object.position!),
            object.attributes.pointSize,
            paint..style = PaintingStyle.fill,
          );
        case Segment():
          canvas.drawLine(
            viewport.worldToScreen(object.start!),
            viewport.worldToScreen(object.end!),
            paint,
          );
        case GeoLine():
          _drawInfiniteLine(canvas, size, object, paint);
        case GeoCircle():
          final circle = object.circle!;
          canvas.drawCircle(
            viewport.worldToScreen(circle.center),
            viewport.worldToScreenLength(circle.radius),
            paint,
          );
      }
    }
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
      oldDelegate.defaultColor != defaultColor;
}
