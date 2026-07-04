import '../../math/vec2.dart';
import '../geo_object.dart';

/// [point] rotated around [center] by a fixed [angle].
///
/// Defined whenever both parents are — a point coinciding with the center
/// rotates to itself. The angle is world-space (counter-clockwise for
/// positive values, like every angle in the math layer) and fixed for the
/// object's lifetime, same as `SegmentRatioPoint.ratio`.
class RotatedPoint extends GeoPoint {
  RotatedPoint({
    required super.id,
    required this.point,
    required this.center,
    required this.angle,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point;
  final GeoPoint center;

  /// Rotation angle in radians, counter-clockwise.
  final double angle;

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [point, center];

  @override
  void recompute() {
    final p = point.position;
    final c = center.position;
    _position = (p == null || c == null) ? null : c + (p - c).rotated(angle);
  }
}
