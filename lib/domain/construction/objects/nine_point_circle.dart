import '../../math/circle_eq.dart';
import '../../math/triangle_centers.dart';
import '../../math/vec2.dart';
import 'triangle_circle.dart';

/// The nine-point (Euler) circle of a triangle: through the three side
/// midpoints, the three feet of the altitudes, and the midpoints between
/// each vertex and the orthocenter.
///
/// Center = midpoint of circumcenter and orthocenter, radius = half the
/// circumradius. Undefined while the vertices are collinear or coincident.
class NinePointCircle extends TriangleCircle {
  NinePointCircle({
    required super.id,
    required super.vertex1,
    required super.vertex2,
    required super.vertex3,
    super.attributes,
  });

  @override
  CircleEq? computeCircle(Vec2 a, Vec2 b, Vec2 c) {
    final o = circumcenter(a, b, c);
    if (o == null) {
      return null;
    }
    // Euler-line identity H = A + B + C − 2O.
    final h = a + b + c - o * 2;
    return CircleEq(o.lerp(h, 0.5), o.distanceTo(a) / 2);
  }
}
