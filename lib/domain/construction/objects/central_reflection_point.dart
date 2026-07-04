import '../../math/vec2.dart';
import '../geo_object.dart';

/// The reflection of [point] about [center] (a half-turn: the center is
/// the midpoint of the point and its image).
///
/// Defined whenever both parents are — a point coinciding with the center
/// reflects to itself.
class CentralReflectionPoint extends GeoPoint {
  CentralReflectionPoint({
    required super.id,
    required this.point,
    required this.center,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point;
  final GeoPoint center;

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [point, center];

  @override
  void recompute() {
    final p = point.position;
    final c = center.position;
    _position = (p == null || c == null) ? null : c * 2 - p;
  }
}
