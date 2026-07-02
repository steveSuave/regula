import '../../math/circle_eq.dart';
import '../geo_object.dart';

/// The compass construction: a circle around [center] whose radius is
/// the distance between two other points.
///
/// Defined whenever all parents are — coincident radius points give a
/// zero-radius circle ([CircleEq] allows that), matching
/// `CircleCenterPoint`'s behaviour through degeneracy.
class CompassCircle extends GeoCircle {
  CompassCircle({
    required super.id,
    required this.radiusPoint1,
    required this.radiusPoint2,
    required this.center,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint radiusPoint1;
  final GeoPoint radiusPoint2;
  final GeoPoint center;

  CircleEq? _circle;

  @override
  CircleEq? get circle => _circle;

  @override
  List<GeoObject> get parents => [radiusPoint1, radiusPoint2, center];

  @override
  void recompute() {
    final r1 = radiusPoint1.position;
    final r2 = radiusPoint2.position;
    final c = center.position;
    _circle = (r1 == null || r2 == null || c == null)
        ? null
        : CircleEq(c, r1.distanceTo(r2));
  }
}
