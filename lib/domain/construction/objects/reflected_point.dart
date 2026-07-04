import '../../math/vec2.dart';
import '../geo_object.dart';

/// The mirror image of [point] across the [mirror] line.
///
/// Undefined while either parent is (e.g. the mirror's defining points
/// coincide); a point lying on the mirror reflects to itself, which is
/// not degenerate. Segments and rays mirror across their infinite
/// carrier, matching `IntersectionPoint`'s carrier semantics.
class ReflectedPoint extends GeoPoint {
  ReflectedPoint({
    required super.id,
    required this.point,
    required this.mirror,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point;
  final GeoLine mirror;

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [point, mirror];

  @override
  void recompute() {
    final p = point.position;
    final line = mirror.line;
    _position = (p == null || line == null) ? null : line.reflect(p);
  }
}
