import '../../math/line_eq.dart';
import '../geo_object.dart';

/// The perpendicular bisector of the segment between [point1] and
/// [point2]: the line through their midpoint, perpendicular to the join.
///
/// A dedicated kind on the [AngleBisectorLine] precedent rather than a
/// hidden Midpoint + PerpendicularLine macro — single-valued and
/// continuous. Undefined while either parent is, or while the points
/// coincide (within [defaultEpsilon], the `carrierLineThrough`
/// convention); recovers when they separate.
class PerpendicularBisectorLine extends GeoLine {
  PerpendicularBisectorLine({
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
    final p1 = point1.position;
    final p2 = point2.position;
    _line = (p1 == null || p2 == null || p1.closeTo(p2))
        ? null
        : LineEq.pointDirection((p1 + p2) * 0.5, (p2 - p1).perpendicular);
  }
}
