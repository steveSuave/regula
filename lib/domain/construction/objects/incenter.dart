import '../../math/triangle_centers.dart' as tc;
import '../../math/vec2.dart';
import 'triangle_center_point.dart';

/// The incenter (center of the inscribed circle) of three points.
/// Undefined while the vertices are collinear or coincident.
class Incenter extends TriangleCenterPoint {
  Incenter({
    required super.id,
    required super.vertex1,
    required super.vertex2,
    required super.vertex3,
    super.attributes,
  });

  @override
  Vec2? computeCenter(Vec2 a, Vec2 b, Vec2 c) => tc.incenter(a, b, c);
}
