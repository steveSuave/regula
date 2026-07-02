import '../../math/angle_geometry.dart';
import '../geo_object.dart';

/// The angle at [vertex] swept counter-clockwise from the ray towards
/// [arm1] to the ray towards [arm2].
///
/// The sweep is directed, so the two arm orders mark the two
/// complementary angles (their measures total 2π). Undefined while an arm
/// coincides with the vertex or a parent is undefined.
class VertexAngle extends GeoAngle {
  VertexAngle({
    required super.id,
    required this.arm1,
    required this.vertex,
    required this.arm2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint arm1;
  final GeoPoint vertex;
  final GeoPoint arm2;

  AngleGeometry? _angle;

  @override
  AngleGeometry? get angle => _angle;

  @override
  List<GeoObject> get parents => [arm1, vertex, arm2];

  @override
  void recompute() {
    final a = arm1.position;
    final v = vertex.position;
    final b = arm2.position;
    _angle = (a == null || v == null || b == null)
        ? null
        : AngleGeometry.fromRays(a, v, b);
  }
}
