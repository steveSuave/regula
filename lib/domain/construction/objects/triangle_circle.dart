import '../../math/circle_eq.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';

/// Base for circle objects derived from the three vertices of a triangle
/// (`NinePointCircle`, `InscribedCircle`) — the circle sibling of
/// `TriangleCenterPoint`.
///
/// Subclasses supply the closed form in [computeCircle], returning null
/// for degenerate input (collinear or coincident vertices) — that makes
/// the object undefined until the degeneracy passes, matching the
/// nullable contract of `math/triangle_centers.dart`.
abstract class TriangleCircle extends GeoCircle {
  TriangleCircle({
    required super.id,
    required this.vertex1,
    required this.vertex2,
    required this.vertex3,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint vertex1;
  final GeoPoint vertex2;
  final GeoPoint vertex3;

  CircleEq? _circle;

  @override
  CircleEq? get circle => _circle;

  @override
  List<GeoObject> get parents => [vertex1, vertex2, vertex3];

  /// The circle derived from triangle `abc`, or null when degenerate.
  CircleEq? computeCircle(Vec2 a, Vec2 b, Vec2 c);

  @override
  void recompute() {
    final a = vertex1.position;
    final b = vertex2.position;
    final c = vertex3.position;
    _circle =
        (a == null || b == null || c == null) ? null : computeCircle(a, b, c);
  }
}
