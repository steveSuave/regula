import '../../math/line_eq.dart';
import '../../math/tangents.dart';
import '../geo_object.dart';

/// One of the two tangent lines from [point] to [circle].
///
/// [branch] picks the tangent whose touch point lies to the left (0) or
/// right (1) of the directed line from the circle's center to [point] —
/// `tangentPointsToCircle`'s order, continuous under any drag of the
/// external point. The carrier is built point-direction through the
/// tangent point perpendicular to the radius, which stays
/// well-conditioned near the rim where a through-points form would
/// degenerate. With [point] on the circle both branches collapse to the
/// tangent at the point.
///
/// Undefined while either parent is, while [point] is strictly inside
/// the circle, or while the radius is degenerate; recovers with sides
/// preserved when the degeneracy passes.
class TangentLine extends GeoLine {
  TangentLine({
    required super.id,
    required this.point,
    required this.circle,
    required this.branch,
    super.attributes,
  }) {
    if (branch != 0 && branch != 1) {
      throw ArgumentError.value(branch, 'branch', 'must be 0 or 1');
    }
    recompute();
  }

  final GeoPoint point;
  final GeoCircle circle;
  final int branch;

  LineEq? _line;

  @override
  LineEq? get line => _line;

  @override
  List<GeoObject> get parents => [point, circle];

  @override
  void recompute() {
    final p = point.position;
    final c = circle.circle;
    if (p == null || c == null) {
      _line = null;
      return;
    }
    final touches = tangentPointsToCircle(p, c);
    if (touches.isEmpty) {
      _line = null;
      return;
    }
    final touch = touches.length == 1 ? touches.single : touches[branch];
    _line = LineEq.pointDirection(touch, (touch - c.center).perpendicular);
  }
}
