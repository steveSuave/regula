import 'dart:ui';

import '../../domain/construction/construction.dart';
import '../../domain/construction/liftable.dart';
import 'canvas_viewport.dart';

/// The handle that lifts a selected free point off its plane (intent
/// 004, milestone 2): a stem from the point along its plane's normal as
/// the screen shows it, ending in a round [grip].
///
/// Dragging the grip changes the point's height by the pointer's travel
/// along [axis]. A drag across the axis does nothing, so the gesture
/// names one number and cannot slide the point sideways.
class LiftHandle {
  const LiftHandle({
    required this.pointId,
    required this.point,
    required this.axis,
    required this.pixelsPerUnit,
  });

  /// How far from the point the grip sits, in pixels.
  static const double gripDistance = 56;

  /// The grip's drawn radius.
  static const double gripRadius = 14;

  /// The grip's grab radius: a 48 px target, the phone minimum.
  static const double grabRadius = 24;

  /// Within this many pixels of the plane the height is exactly 0. The
  /// snap is the only way back into the plane, since only an exactly
  /// zero height is in it.
  static const double snapPx = 8;

  /// The handle is offered only while one world unit of height moves the
  /// point at least this fraction of the scale on screen. Seen nearly
  /// face-on, the normal points at the camera and a screen drag cannot
  /// name a height: the handle is absent rather than wildly sensitive.
  static const double minForeshortening = 0.2;

  final String pointId;

  /// The point's screen position.
  final Offset point;

  /// The unit screen direction of increasing height.
  final Offset axis;

  /// Screen pixels per world unit of height.
  final double pixelsPerUnit;

  Offset get grip => point + axis * gripDistance;

  bool grabs(Offset pointer) => (pointer - grip).distance <= grabRadius;

  /// The height the point takes when a drag that began at [start], with
  /// the point at [startHeight], has reached [pointer].
  double heightAt(
    Offset pointer, {
    required Offset start,
    required double startHeight,
  }) {
    final travel = pointer - start;
    final height =
        startHeight +
        (travel.dx * axis.dx + travel.dy * axis.dy) / pixelsPerUnit;
    return height.abs() * pixelsPerUnit <= snapPx ? 0 : height;
  }

  /// The handle for [point] under [viewport], or null when the point has
  /// no real position or its plane is seen too nearly face-on.
  static LiftHandle? of(Liftable point, CanvasViewport viewport) {
    final position = point.spacePosition;
    final normal = point.liftFrame?.normal;
    if (position == null || normal == null) {
      return null;
    }
    final at = viewport.spaceToScreen(position);
    final up = viewport.spaceToScreen(position + normal) - at;
    final pixelsPerUnit = up.distance;
    if (pixelsPerUnit < minForeshortening * viewport.state.scale) {
      return null;
    }
    return LiftHandle(
      pointId: point.id,
      point: at,
      axis: up / pixelsPerUnit,
      pixelsPerUnit: pixelsPerUnit,
    );
  }

  /// The handle the selection calls for: exactly one object selected,
  /// and it a visible free point. Null otherwise.
  static LiftHandle? forSelection(
    Construction construction,
    Set<String> selectedIds,
    CanvasViewport viewport,
  ) {
    if (selectedIds.length != 1) {
      return null;
    }
    final object = construction.byId(selectedIds.single);
    if (object is! Liftable || !object.attributes.visible) {
      return null;
    }
    return of(object, viewport);
  }

  /// The foot of a lifted [point] on its plane, on screen; null for a
  /// point in its plane.
  static Offset? footOf(Liftable point, CanvasViewport viewport) {
    final frame = point.liftFrame;
    final position = point.spacePosition;
    if (point.height == 0 || frame == null || position == null) {
      return null;
    }
    return viewport.spaceToScreen(position - frame.normal * point.height);
  }
}
