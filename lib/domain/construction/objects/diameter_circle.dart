import '../../math/circle_eq.dart';
import '../geo_object.dart';

/// The circle with the span from [point1] to [point2] as a diameter:
/// centered at their midpoint, radius half their distance — the Thales
/// circle over the two points.
///
/// Defined whenever both parents are defined — coincident parents give a
/// zero-radius circle ([CircleEq] allows that) so the object survives a
/// drag through the degeneracy without flickering undefined.
class DiameterCircle extends GeoCircle {
  DiameterCircle({
    required super.id,
    required this.point1,
    required this.point2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;

  CircleEq? _circle;

  @override
  CircleEq? get circle => _circle;

  @override
  List<GeoObject> get parents => [point1, point2];

  @override
  void recompute() {
    final a = point1.position;
    final b = point2.position;
    _circle = (a == null || b == null)
        ? null
        : CircleEq(a.lerp(b, 0.5), a.distanceTo(b) / 2);
  }
}
