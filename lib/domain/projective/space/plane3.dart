import 'dart:math' as math;

import '../../math/vec3.dart';
import '../tolerances.dart';
import 'line3.dart';
import 'point3.dart';

/// A plane of real projective 3-space: the dual of a [Point3], the
/// quadruple `[a : b : c : d]` of `a·x + b·y + c·z + d·w = 0`.
///
/// `(a, b, c)` is the plane's normal. The plane with a zero normal and
/// `d ≠ 0` is the plane at infinity, which is a value like the line at
/// infinity in the planar kernel. The zero quadruple is not a plane.
class Plane3 {
  const Plane3(this.a, this.b, this.c, this.d);

  /// The plane with normal [normal] through the finite point [point].
  Plane3.normalAt(Vec3 normal, Vec3 point)
    : this(normal.x, normal.y, normal.z, -normal.dot(point));

  /// The plane through three points. The zero plane exactly when the
  /// three are collinear (or one is the zero quadruple).
  factory Plane3.through(Point3 p, Point3 q, Point3 r) =>
      p.join(q).joinPoint(r);

  /// The base plane, `z = 0`.
  static const Plane3 base = Plane3(0, 0, 1, 0);

  final double a;
  final double b;
  final double c;
  final double d;

  Vec3 get normal => Vec3(a, b, c);

  double get norm2 => a * a + b * b + c * c + d * d;

  bool get isZero => a == 0 && b == 0 && c == 0 && d == 0;

  /// Whether this is a finite plane: its normal is not negligible. False
  /// for the plane at infinity and the zero quadruple.
  bool isFinite([double eps = projectiveEpsilon]) =>
      !isZero && normal.norm > eps * math.sqrt(norm2);

  /// The bilinear pairing with a point; zero exactly on incidence.
  double incidence(Point3 p) => a * p.x + b * p.y + c * p.z + d * p.w;

  /// Incidence at a relative tolerance.
  bool contains(Point3 p, [double eps = projectiveEpsilon]) =>
      !isZero &&
      !p.isZero &&
      incidence(p).abs() <= eps * math.sqrt(norm2 * p.norm2);

  /// The line this plane shares with [other]. The zero line exactly when
  /// the two planes coincide; parallel planes meet in a line at infinity.
  Line3 meet(Plane3 other) =>
      Line3(normal.cross(other.normal), other.normal * d - normal * other.d);

  /// The signed distance of the finite point [p] from the plane, positive
  /// on the normal's side. Null when the plane is not finite.
  double? signedDistance(Vec3 p) {
    final n = normal.norm;
    return n == 0 ? null : (normal.dot(p) + d) / n;
  }

  @override
  bool operator ==(Object other) =>
      other is Plane3 &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d;

  @override
  int get hashCode => Object.hash(a, b, c, d);

  @override
  String toString() => 'Plane3($a, $b, $c, $d)';
}
