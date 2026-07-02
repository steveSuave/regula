import 'line_eq.dart';
import 'vec2.dart';

/// The internal bisector of the angle at [vertex] between the rays toward
/// [arm1] and [arm2], or null when either arm point (nearly) coincides
/// with the vertex — no ray, no angle.
///
/// Degenerate-but-defined cases: arms on the same ray bisect to that ray;
/// arms on opposite rays (a straight angle) bisect to the perpendicular
/// at the vertex.
LineEq? angleBisector(Vec2 arm1, Vec2 vertex, Vec2 arm2) {
  if (arm1.closeTo(vertex) || arm2.closeTo(vertex)) {
    return null;
  }
  final u = (arm1 - vertex).normalized();
  final v = (arm2 - vertex).normalized();
  final sum = u + v;
  final diff = u - v;
  // For unit vectors, u+v and u−v are orthogonal and can't both be small:
  // the sum bisects ordinary angles but vanishes toward opposite rays,
  // where the difference (norm → 2) takes over via its perpendicular.
  final direction =
      sum.normSquared >= diff.normSquared ? sum : diff.perpendicular;
  return LineEq.pointDirection(vertex, direction);
}
