import '../../math/vec2.dart';
import '../geo_object.dart';

/// The midpoint of two points.
///
/// Defined whenever both parents are defined — coincident parents just
/// give the shared position.
class Midpoint extends GeoPoint {
  Midpoint({
    required super.id,
    required this.point1,
    required this.point2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [point1, point2];

  @override
  void recompute() {
    final p1 = point1.position;
    final p2 = point2.position;
    _position = (p1 == null || p2 == null) ? null : p1.lerp(p2, 0.5);
  }
}
