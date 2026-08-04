import '../../math/harmonic.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';

/// The fourth harmonic point: the conjugate of [point3] with respect to
/// [point1] and [point2], with cross-ratio (A,B;C,D) = −1.
///
/// Undefined while any parent is, while the three points are not
/// collinear (within [harmonicConjugate]'s tolerance), while the base
/// pair coincides, or while [point3] is the midpoint of the base pair
/// (the conjugate at infinity); recovers when the degeneracy passes.
class HarmonicConjugatePoint extends GeoPoint {
  HarmonicConjugatePoint({
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

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [point1, point2, point3];

  @override
  void recompute() {
    final a = point1.position;
    final b = point2.position;
    final c = point3.position;
    _position = (a == null || b == null || c == null)
        ? null
        : harmonicConjugate(a, b, c);
  }
}
