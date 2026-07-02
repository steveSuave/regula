import '../../math/angle_bisector.dart';
import '../../math/line_eq.dart';
import '../geo_object.dart';

/// The internal bisector of the angle at [vertex] between the rays toward
/// [arm1] and [arm2].
///
/// Undefined while any parent is, or while an arm point sits on the
/// vertex (see `angleBisector`); recovers when the degeneracy passes.
class AngleBisectorLine extends GeoLine {
  AngleBisectorLine({
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

  LineEq? _line;

  @override
  LineEq? get line => _line;

  @override
  List<GeoObject> get parents => [arm1, vertex, arm2];

  @override
  void recompute() {
    final a = arm1.position;
    final v = vertex.position;
    final b = arm2.position;
    _line = (a == null || v == null || b == null)
        ? null
        : angleBisector(a, v, b);
  }
}
