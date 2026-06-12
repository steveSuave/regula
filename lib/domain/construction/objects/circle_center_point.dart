import '../../math/circle_eq.dart';
import '../geo_object.dart';

/// The circle with a given center, passing through another point.
///
/// Defined whenever both parents are defined — coincident parents give a
/// zero-radius circle ([CircleEq] allows that) so the object survives a
/// drag through the degeneracy without flickering undefined.
class CircleCenterPoint extends GeoCircle {
  CircleCenterPoint({
    required super.id,
    required this.center,
    required this.onCircle,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint center;
  final GeoPoint onCircle;

  CircleEq? _circle;

  @override
  CircleEq? get circle => _circle;

  @override
  List<GeoObject> get parents => [center, onCircle];

  @override
  void recompute() {
    final c = center.position;
    final p = onCircle.position;
    _circle = (c == null || p == null) ? null : CircleEq.centerAndPoint(c, p);
  }
}
