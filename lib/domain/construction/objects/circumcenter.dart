import '../../math/triangle_centers.dart' as tc;
import '../../math/vec2.dart';
import 'triangle_center_point.dart';

/// The circumcenter (center of the circle through all three vertices) of
/// three points. Undefined while the vertices are collinear or coincident.
class Circumcenter extends TriangleCenterPoint {
  Circumcenter({
    required super.id,
    required super.vertex1,
    required super.vertex2,
    required super.vertex3,
    super.attributes,
  });

  @override
  Vec2? computeCenter(Vec2 a, Vec2 b, Vec2 c) => tc.circumcenter(a, b, c);
}
