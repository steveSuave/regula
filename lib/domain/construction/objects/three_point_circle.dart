import '../../math/circle_eq.dart';
import '../../math/triangle_centers.dart';
import '../geo_object.dart';

/// The circle through three points (their circumcircle).
///
/// Undefined while the points are collinear — including any two
/// coincident — since no (finite) circle passes through them; recovers
/// when a drag breaks the degeneracy.
class ThreePointCircle extends GeoCircle {
  ThreePointCircle({
    required super.id,
    required this.point1,
    required this.point2,
    required this.point3,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;
  final GeoPoint point3;

  CircleEq? _circle;

  @override
  CircleEq? get circle => _circle;

  @override
  List<GeoObject> get parents => [point1, point2, point3];

  @override
  void recompute() {
    final p1 = point1.position;
    final p2 = point2.position;
    final p3 = point3.position;
    if (p1 == null || p2 == null || p3 == null) {
      _circle = null;
      return;
    }
    final center = circumcenter(p1, p2, p3);
    _circle = center == null ? null : CircleEq.centerAndPoint(center, p1);
  }
}
