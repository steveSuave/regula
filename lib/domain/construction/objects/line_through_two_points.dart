import '../../math/line_eq.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';

/// The infinite line through two points.
///
/// Undefined while the points coincide (within [defaultEpsilon]) or while
/// either parent is undefined; comes back when they separate.
class LineThroughTwoPoints extends GeoLine {
  LineThroughTwoPoints({
    required super.id,
    required this.point1,
    required this.point2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;

  LineEq? _line;

  @override
  LineEq? get line => _line;

  @override
  List<GeoObject> get parents => [point1, point2];

  @override
  void recompute() {
    _line = carrierLineThrough(point1, point2);
  }
}

/// Carrier line through two point objects, or null when degenerate.
///
/// Shared by [LineThroughTwoPoints] and `Segment` so both agree on what
/// "degenerate" means.
LineEq? carrierLineThrough(GeoPoint point1, GeoPoint point2) {
  final p1 = point1.position;
  final p2 = point2.position;
  if (p1 == null || p2 == null || p1.closeTo(p2)) {
    return null;
  }
  return LineEq.throughPoints(p1, p2);
}
