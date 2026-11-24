import 'dart:math' as math;

import '../../math/vec3.dart';
import '../tolerances.dart';
import 'line3.dart';

/// A point of real projective 3-space, in homogeneous coordinates
/// `[x : y : z : w]`.
///
/// The space kernel is real (intent 004): complex values belong to the
/// planar kernel, which runs inside each plane's own coordinates
/// (`PlaneFrame`). Conventions follow `ProjPoint`: quadruples differing
/// by a nonzero scalar are the same point, `w = 0` is a point at infinity
/// (a direction), and the zero quadruple is not a point — operations
/// stay total and hand it on rather than throwing.
class Point3 {
  const Point3(this.x, this.y, this.z, [this.w = 1]);

  /// The finite point [p], as `[p.x, p.y, p.z, 1]`.
  Point3.lift(Vec3 p) : this(p.x, p.y, p.z);

  /// The point at infinity in direction [d].
  Point3.direction(Vec3 d) : this(d.x, d.y, d.z, 0);

  final double x;
  final double y;
  final double z;
  final double w;

  /// The first three coordinates.
  Vec3 get xyz => Vec3(x, y, z);

  double get norm2 => x * x + y * y + z * z + w * w;

  bool get isZero => x == 0 && y == 0 && z == 0 && w == 0;

  /// Whether the point is finite: `w` is not negligible against the
  /// quadruple's norm. False for the zero quadruple.
  bool isFinite([double eps = projectiveEpsilon]) =>
      !isZero && w.abs() > eps * math.sqrt(norm2);

  /// The total projection to the affine chart: null for a point at
  /// infinity, the zero quadruple, or a non-finite coordinate.
  Vec3? toVec3([double eps = projectiveEpsilon]) {
    if (!isFinite(eps)) {
      return null;
    }
    final v = Vec3(x / w, y / w, z / w);
    return v.x.isFinite && v.y.isFinite && v.z.isFinite ? v : null;
  }

  /// The line through this point and [other]. The zero line exactly when
  /// the two coincide (or either is the zero quadruple).
  Line3 join(Point3 other) => Line3(
    Vec3(
      w * other.x - other.w * x,
      w * other.y - other.w * y,
      w * other.z - other.w * z,
    ),
    xyz.cross(other.xyz),
  );

  /// Projective equality at a relative tolerance: the quadruples are
  /// parallel. False if either is zero.
  bool closeTo(Point3 other, [double eps = projectiveEpsilon]) {
    if (isZero || other.isZero) {
      return false;
    }
    final a = [x, y, z, w];
    final b = [other.x, other.y, other.z, other.w];
    var minors2 = 0.0;
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        final m = a[i] * b[j] - a[j] * b[i];
        minors2 += m * m;
      }
    }
    return minors2 <= eps * eps * norm2 * other.norm2;
  }

  @override
  bool operator ==(Object other) =>
      other is Point3 &&
      other.x == x &&
      other.y == y &&
      other.z == z &&
      other.w == w;

  @override
  int get hashCode => Object.hash(x, y, z, w);

  @override
  String toString() => 'Point3($x, $y, $z, $w)';
}
