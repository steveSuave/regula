import '../../math/vec2.dart';
import '../geo_object.dart';

/// The point dividing the directed span from [point1] to [point2] at a
/// fixed [ratio]: `position = point1 + ratio · (point2 − point1)`.
///
/// `ratio` 0 is [point1], 1 is [point2], 0.5 the midpoint; values outside
/// [0, 1] extrapolate beyond the endpoints, which is deliberate (the
/// classic "extend AB by its own length" construction is `ratio` 2).
/// Defined whenever both parents are — coincident parents just give the
/// shared position.
class SegmentRatioPoint extends GeoPoint {
  SegmentRatioPoint({
    required super.id,
    required this.point1,
    required this.point2,
    required this.ratio,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;

  /// Interpolation parameter along point1 → point2. Fixed for the
  /// object's lifetime, like `PointOnObject.parameter`.
  final double ratio;

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [point1, point2];

  @override
  void recompute() {
    final p1 = point1.position;
    final p2 = point2.position;
    _position = (p1 == null || p2 == null) ? null : p1.lerp(p2, ratio);
  }
}
