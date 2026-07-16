import '../../math/vec2.dart';
import '../geo_object.dart';

/// The live distance between two points, displayed as canvas text at
/// their midpoint. Undefined while either point is (point–line distance
/// is deferred, per PLAN).
class DistanceMeasurement extends GeoMeasurement {
  DistanceMeasurement({
    required super.id,
    required this.point1,
    required this.point2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;

  double? _value;
  Vec2? _anchor;

  @override
  double? get value => _value;

  @override
  Vec2? get anchor => _anchor;

  @override
  List<GeoObject> get parents => [point1, point2];

  @override
  void recompute() {
    final p1 = point1.position;
    final p2 = point2.position;
    if (p1 == null || p2 == null) {
      _value = null;
      _anchor = null;
      return;
    }
    _value = p1.distanceTo(p2);
    _anchor = p1.lerp(p2, 0.5);
  }
}
