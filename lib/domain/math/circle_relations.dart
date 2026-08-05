import 'circle_eq.dart';
import 'line_eq.dart';
import 'vec2.dart';

/// The radical axis of [c1] and [c2] — the line of points with equal
/// *power* (`|P − center|² − radius²`) with respect to both circles — or
/// `null` when the circles are concentric (within [epsilon]), where no
/// such line exists.
///
/// Equating the two powers cancels the quadratic terms, leaving the line
/// `2(c₂ − c₁)·P + (|c₁|² − |c₂|² − r₁² + r₂²) = 0`. Its normal is the
/// center offset, so the axis is always perpendicular to the line of
/// centers; when the circles intersect it carries their common chord, and
/// for equal radii it is the perpendicular bisector of the centers.
LineEq? radicalAxis(
  CircleEq c1,
  CircleEq c2, [
  double epsilon = defaultEpsilon,
]) {
  if (c1.center.closeTo(c2.center, epsilon)) {
    return null;
  }
  final d = c2.center - c1.center;
  return LineEq(
    2 * d.x,
    2 * d.y,
    c1.center.normSquared -
        c2.center.normSquared -
        c1.radius * c1.radius +
        c2.radius * c2.radius,
  );
}

/// The Apollonius circle over [a] and [b] with distance ratio [ratio] —
/// the locus of points P with `|PA| / |PB| = ratio` — or `null` when the
/// configuration degenerates: [a] and [b] coincide (within [epsilon]),
/// [ratio] is not a finite positive number, or [ratio] is 1 (within
/// [epsilon] on `1 − ratio²`), where the locus is the perpendicular
/// bisector of AB rather than a circle.
///
/// The center lies on line AB at `(A − k²·B) / (1 − k²)` with radius
/// `k·|AB| / |1 − k²|`; the circle cuts AB at the two points dividing it
/// internally and externally in the ratio k.
CircleEq? apolloniusCircle(
  Vec2 a,
  Vec2 b,
  double ratio, [
  double epsilon = defaultEpsilon,
]) {
  if (!ratio.isFinite || ratio <= 0 || a.closeTo(b, epsilon)) {
    return null;
  }
  final k2 = ratio * ratio;
  final denominator = 1 - k2;
  if (denominator.abs() <= epsilon) {
    return null;
  }
  final center = (a - b * k2) * (1 / denominator);
  final radius = ratio * a.distanceTo(b) / denominator.abs();
  return CircleEq(center, radius);
}
