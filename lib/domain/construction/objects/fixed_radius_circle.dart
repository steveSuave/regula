import '../../math/circle_eq.dart';
import '../geo_object.dart';

/// The circle around [center] with a fixed numeric [radius].
///
/// The radius is given up front (dialog input) rather than by a point, and
/// is fixed for the object's lifetime like `RotatedPoint.angle` — so this
/// serves the circle-by-radius tool directly and doubles as the hidden
/// circle behind the segment-by-length macro. Defined iff the center is.
class FixedRadiusCircle extends GeoCircle {
  FixedRadiusCircle({
    required super.id,
    required this.center,
    required this.radius,
    super.attributes,
  }) {
    if (radius.isNaN || radius.isInfinite || radius <= 0) {
      throw ArgumentError.value(
        radius,
        'radius',
        'must be a finite positive number',
      );
    }
    recompute();
  }

  final GeoPoint center;

  /// Radius in world units, fixed for the object's lifetime.
  final double radius;

  CircleEq? _circle;

  @override
  CircleEq? get circle => _circle;

  @override
  List<GeoObject> get parents => [center];

  @override
  void recompute() {
    final c = center.position;
    _circle = c == null ? null : CircleEq(c, radius);
  }
}
