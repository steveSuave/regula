import 'dart:math' as math;

import '../../math/vec3.dart';
import '../tolerances.dart';
import 'plane3.dart';
import 'point3.dart';

/// A line of real projective 3-space in Plücker coordinates: a
/// [direction] `d` and a [moment] `m`, with `m = p × d` for any finite
/// point `p` on the line, so that `d · m = 0`.
///
/// Join and meet are uniform in these coordinates, and
/// coplanar-versus-skew is the one bilinear quantity [reciprocal]. A line
/// with zero direction and nonzero moment lies in the plane at infinity.
/// The zero sextuple is not a line; it is what an exactly degenerate join
/// or meet answers.
class Line3 {
  const Line3(this.direction, this.moment);

  final Vec3 direction;
  final Vec3 moment;

  double get norm2 => direction.normSquared + moment.normSquared;

  bool get isZero => direction.isZero && moment.isZero;

  /// Whether the line is finite: its direction is not negligible. False
  /// for a line at infinity and the zero sextuple.
  bool isFinite([double eps = projectiveEpsilon]) =>
      !isZero && direction.norm > eps * math.sqrt(norm2);

  /// The point of the line nearest the origin, or null when the line is
  /// not finite.
  Vec3? get anchor {
    final d2 = direction.normSquared;
    if (d2 == 0) {
      return null;
    }
    final a = direction.cross(moment) / d2;
    return a.x.isFinite && a.y.isFinite && a.z.isFinite ? a : null;
  }

  /// The line's point at infinity.
  Point3 get directionPoint => Point3.direction(direction);

  /// The plane through this line and [p]. The zero plane exactly when
  /// [p] lies on the line. Oriented so that the plane through `a`, `b`,
  /// `c` has its normal along `ab × ac`.
  Plane3 joinPoint(Point3 p) {
    final n = direction.cross(p.xyz) + moment * p.w;
    return Plane3(n.x, n.y, n.z, -p.xyz.dot(moment));
  }

  /// The point where this line meets [plane]. The zero point exactly
  /// when the line lies in the plane; a line parallel to the plane meets
  /// it at a point at infinity.
  Point3 meetPlane(Plane3 plane) {
    final n = plane.normal;
    final p = n.cross(moment) - direction * plane.d;
    return Point3(p.x, p.y, p.z, n.dot(direction));
  }

  /// The reciprocal product `d₁·m₂ + d₂·m₁`: zero exactly when the two
  /// lines are coplanar (they meet, possibly at infinity), nonzero when
  /// they are skew. Its sign is the handedness of the pair.
  double reciprocal(Line3 other) =>
      direction.dot(other.moment) + other.direction.dot(moment);

  /// Whether [p] lies on the line, at a relative tolerance.
  bool contains(Point3 p, [double eps = projectiveEpsilon]) {
    if (isZero || p.isZero) {
      return false;
    }
    final plane = joinPoint(p);
    return plane.norm2 <= eps * eps * norm2 * p.norm2;
  }

  /// Whether the line lies in [plane], at a relative tolerance.
  bool liesIn(Plane3 plane, [double eps = projectiveEpsilon]) {
    if (isZero || plane.isZero) {
      return false;
    }
    final point = meetPlane(plane);
    return point.norm2 <= eps * eps * norm2 * plane.norm2;
  }

  /// Projective equality at a relative tolerance: the sextuples are
  /// parallel, in either orientation. False if either is zero.
  bool closeTo(Line3 other, [double eps = projectiveEpsilon]) {
    if (isZero || other.isZero) {
      return false;
    }
    final a = [
      direction.x,
      direction.y,
      direction.z,
      moment.x,
      moment.y,
      moment.z,
    ];
    final b = [
      other.direction.x,
      other.direction.y,
      other.direction.z,
      other.moment.x,
      other.moment.y,
      other.moment.z,
    ];
    var minors2 = 0.0;
    for (var i = 0; i < 6; i++) {
      for (var j = i + 1; j < 6; j++) {
        final m = a[i] * b[j] - a[j] * b[i];
        minors2 += m * m;
      }
    }
    return minors2 <= eps * eps * norm2 * other.norm2;
  }

  @override
  bool operator ==(Object other) =>
      other is Line3 && other.direction == direction && other.moment == moment;

  @override
  int get hashCode => Object.hash(direction, moment);

  @override
  String toString() => 'Line3($direction, $moment)';
}
