import 'dart:math' as math;
import 'dart:ui';

import '../../application/providers/viewport_provider.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/math/vec2.dart';
import 'canvas_viewport.dart';

/// Screen pixels kept free around a fitted construction.
const double fitMarginPx = 48;

/// Axis-aligned world bounds (y-up) of the drawable extent of [objects].
/// Null when nothing contributes.
///
/// Hidden and undefined objects don't count — fit frames what the user
/// sees. Per kind: points contribute their position, circles their full
/// carrier disc (arcs/sectors are framed a little loosely, by design —
/// their carrier box is stable while the branch swings during drags),
/// angles their vertex (the marker is screen-sized), and lines nothing:
/// their carrier is unbounded, and their defining points are objects in
/// the construction contributing on their own.
({Vec2 min, Vec2 max})? visibleWorldBounds(Iterable<GeoObject> objects) {
  double? minX, minY, maxX, maxY;
  void include(double x, double y) {
    minX = math.min(minX ?? x, x);
    minY = math.min(minY ?? y, y);
    maxX = math.max(maxX ?? x, x);
    maxY = math.max(maxY ?? y, y);
  }

  for (final object in objects) {
    if (!object.attributes.visible || !object.isDefined) {
      continue;
    }
    switch (object) {
      case GeoPoint(:final position?):
        include(position.x, position.y);
      case GeoCircle(:final circle?):
        include(circle.center.x - circle.radius,
            circle.center.y - circle.radius);
        include(circle.center.x + circle.radius,
            circle.center.y + circle.radius);
      case GeoAngle(:final angle?):
        include(angle.vertex.x, angle.vertex.y);
      case GeoLine():
        break;
      // isDefined held above, so the null-payload cases are unreachable;
      // Dart's exhaustiveness checker still wants them spelled out.
      case GeoPoint():
      case GeoCircle():
      case GeoAngle():
        break;
    }
  }
  final left = minX;
  if (left == null) {
    return null;
  }
  return (min: Vec2(left, minY!), max: Vec2(maxX!, maxY!));
}

/// The viewport framing every visible object centered in [canvasSize]
/// with [marginPx] to spare, or null when there is nothing to frame.
///
/// Scale is clamped to [CanvasViewport.minScale]..[maxScale]; a
/// zero-size extent (a single point) centers at 100 % instead of
/// zooming to the clamp.
ViewportState? fittedViewport(
  Iterable<GeoObject> objects,
  Size canvasSize, {
  double marginPx = fitMarginPx,
}) {
  final bounds = visibleWorldBounds(objects);
  if (bounds == null || canvasSize.shortestSide <= 0) {
    return null;
  }
  final width = bounds.max.x - bounds.min.x;
  final height = bounds.max.y - bounds.min.y;
  final availableWidth = math.max(1.0, canvasSize.width - 2 * marginPx);
  final availableHeight = math.max(1.0, canvasSize.height - 2 * marginPx);
  final scale = (width <= 0 && height <= 0)
      ? 1.0
      : math
          .min(
            width > 0 ? availableWidth / width : double.infinity,
            height > 0 ? availableHeight / height : double.infinity,
          )
          .clamp(CanvasViewport.minScale, CanvasViewport.maxScale)
          .toDouble();
  final center = Vec2(
    (bounds.min.x + bounds.max.x) / 2,
    (bounds.min.y + bounds.max.y) / 2,
  );
  // Solve worldToScreen(center) == canvas center for pan.
  return ViewportState(
    pan: Vec2(
      center.x - canvasSize.width / 2 / scale,
      center.y + canvasSize.height / 2 / scale,
    ),
    scale: scale,
  );
}
