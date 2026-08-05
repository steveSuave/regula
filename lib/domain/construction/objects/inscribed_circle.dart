import '../../math/circle_eq.dart';
import '../../math/triangle_centers.dart';
import '../../math/vec2.dart';
import 'triangle_circle.dart';

/// The inscribed circle (incircle) of a triangle: centered at the
/// incenter, tangent to all three sides from the inside.
///
/// Undefined while the vertices are collinear or coincident.
class InscribedCircle extends TriangleCircle {
  InscribedCircle({
    required super.id,
    required super.vertex1,
    required super.vertex2,
    required super.vertex3,
    super.attributes,
  });

  @override
  CircleEq? computeCircle(Vec2 a, Vec2 b, Vec2 c) {
    final center = incenter(a, b, c);
    if (center == null) {
      return null;
    }
    return CircleEq(center, inradius(a, b, c)!);
  }
}
