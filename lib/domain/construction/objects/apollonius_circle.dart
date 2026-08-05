import '../../math/circle_eq.dart';
import '../../math/circle_relations.dart';
import '../geo_object.dart';

/// The Apollonius circle over [point1] (A) and [point2] (B) with the
/// distance ratio supplied by [point3] (C): the locus of points P with
/// `|PA| / |PB| = |CA| / |CB|` — which passes through C itself.
///
/// Undefined while C is equidistant from A and B (the locus degenerates
/// to the perpendicular bisector of AB), while any two of the points
/// coincide, or while a parent is undefined; recovers when a drag breaks
/// the degeneracy.
class ApolloniusCircle extends GeoCircle {
  ApolloniusCircle({
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
    final a = point1.position;
    final b = point2.position;
    final c = point3.position;
    if (a == null || b == null || c == null) {
      _circle = null;
      return;
    }
    // C on B makes the ratio infinite, C on A makes it zero — both are
    // rejected by the helper along with coincident A/B and ratio ≈ 1.
    _circle = apolloniusCircle(a, b, c.distanceTo(a) / c.distanceTo(b));
  }
}
