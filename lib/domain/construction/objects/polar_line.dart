import '../../math/circle_relations.dart';
import '../../math/line_eq.dart';
import '../geo_object.dart';

/// The polar line of [point] (the pole) with respect to [circle]:
/// perpendicular to the center→pole join at the pole's inverse point —
/// through the tangent points when the pole is outside, the tangent at
/// the pole when it lies on the circle, and still defined inside.
///
/// Unlike [point]'s two tangent lines the polar is single-valued, so
/// there is no branch. Undefined while either parent is, or while the
/// pole sits on the circle's center (no direction is preferred);
/// recovers when a drag separates them.
class PolarLine extends GeoLine {
  PolarLine({
    required super.id,
    required this.point,
    required this.circle,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point;
  final GeoCircle circle;

  LineEq? _line;

  @override
  LineEq? get line => _line;

  @override
  List<GeoObject> get parents => [point, circle];

  @override
  void recompute() {
    final p = point.position;
    final c = circle.circle;
    _line = (p == null || c == null) ? null : polarLine(p, c);
  }
}
