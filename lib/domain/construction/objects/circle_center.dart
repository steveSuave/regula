import '../../math/vec2.dart';
import '../geo_object.dart';

/// The center point of a circle-valued object.
///
/// The parent may be any [GeoCircle] — for an arc or sector this is the
/// carrier circle's center. Defined whenever the parent is. Not to be
/// confused with `CircleCenterPoint`, the *circle* built from a center
/// and a rim point.
class CircleCenter extends GeoPoint {
  CircleCenter({
    required super.id,
    required this.circle,
    super.attributes,
  }) {
    recompute();
  }

  final GeoCircle circle;

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [circle];

  @override
  void recompute() => _position = circle.circle?.center;
}
