import '../../math/vec2.dart';
import '../geo_object.dart';

/// Base for point objects derived from the three vertices of a triangle
/// (`Centroid`, `Orthocenter`, `Incenter`, `Circumcenter`).
///
/// Subclasses supply the closed form in [computeCenter], returning null
/// for degenerate input (collinear or coincident vertices) — that makes
/// the object undefined until the degeneracy passes, matching the
/// `Vec2?` contract of `math/triangle_centers.dart`.
abstract class TriangleCenterPoint extends GeoPoint {
  TriangleCenterPoint({
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

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [vertex1, vertex2, vertex3];

  /// The center of triangle `abc`, or null when degenerate.
  Vec2? computeCenter(Vec2 a, Vec2 b, Vec2 c);

  @override
  void recompute() {
    final a = vertex1.position;
    final b = vertex2.position;
    final c = vertex3.position;
    _position =
        (a == null || b == null || c == null) ? null : computeCenter(a, b, c);
  }
}
