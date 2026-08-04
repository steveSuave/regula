import 'line_eq.dart';
import 'vec2.dart';

/// The harmonic conjugate of [c] with respect to [a] and [b] — the fourth
/// point D with cross-ratio (A,B;C,D) = −1 — or `null` when the
/// configuration degenerates: [a] and [b] coincide, [c] lies off the line
/// AB (within [isCollinear]'s tolerance), or [c] is the midpoint of AB
/// (D at infinity).
///
/// In the affine coordinate t along AB (A at 0, B at 1) with C at t, D
/// sits at `t / (2t − 1)`: C at either endpoint is its own conjugate, C
/// strictly between the endpoints maps outside the segment, and the map
/// is an involution — the conjugate of the conjugate is C again.
Vec2? harmonicConjugate(
  Vec2 a,
  Vec2 b,
  Vec2 c, [
  double epsilon = defaultEpsilon,
]) {
  if (a.closeTo(b, epsilon) || !isCollinear(a, b, c, epsilon)) {
    return null;
  }
  final ab = b - a;
  final t = (c - a).dot(ab) / ab.normSquared;
  final denominator = 2 * t - 1;
  if (denominator.abs() <= epsilon) {
    return null;
  }
  return a + ab * (t / denominator);
}
