import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../complex.dart';
import '../proj_line.dart';
import '../proj_point.dart';
import '../tolerances.dart';
import 'line3.dart';
import 'plane3.dart';
import 'point3.dart';

/// A plane of space with coordinates on it: an [origin] and an
/// orthonormal pair ([u], [v]), with [normal] `u × v`.
///
/// This is the sense in which the planar kernel is the space kernel's
/// chart (DECISIONS §"Sheets: a plane is a chart of one space"): a planar
/// object's `projPoint` / `projLine` are coordinates in some frame, and
/// [lift] / [pull] carry values between the frame and space. Because the
/// pair is orthonormal, the frame's Euclidean geometry is the space
/// geometry restricted to the plane.
class PlaneFrame {
  const PlaneFrame(this.origin, this.u, this.v);

  /// The base plane `z = 0` with the world axes: [lift] of `(x, y)` is
  /// `(x, y, 0)`.
  static const PlaneFrame base = PlaneFrame(Vec3.zero, Vec3.unitX, Vec3.unitY);

  /// The frame of the plane through three finite points: origin [a],
  /// `u` along `ab`, the normal along `ab × ac`. Null exactly when the
  /// three are collinear.
  static PlaneFrame? throughPoints(Vec3 a, Vec3 b, Vec3 c) {
    final u = (b - a).normalizedOrNull;
    final n = (b - a).cross(c - a).normalizedOrNull;
    if (u == null || n == null) {
      return null;
    }
    return PlaneFrame(a, u, n.cross(u));
  }

  /// The frame at [origin] with the given [normal] and `u` along
  /// [along] made perpendicular to the normal. Null when [normal] is
  /// zero or [along] is parallel to it.
  static PlaneFrame? withAxis(Vec3 origin, Vec3 normal, Vec3 along) {
    final n = normal.normalizedOrNull;
    if (n == null) {
      return null;
    }
    final u = (along - n * along.dot(n)).normalizedOrNull;
    if (u == null) {
      return null;
    }
    return PlaneFrame(origin, u, n.cross(u));
  }

  /// The frame at [origin] with the given [normal] and a horizontal `u`
  /// (`ẑ × n`), so that for a vertical plane `u` runs level and `v`
  /// points up. A horizontal plane takes `u = x̂`, which makes an upward
  /// horizontal plane's frame the base plane's axes. Null when [normal]
  /// is zero.
  ///
  /// The choice is singular at horizontal: a plane tilting through it
  /// sees `u` turn quickly. That is a property of naming a direction in
  /// a plane from its normal alone, not of the plane.
  static PlaneFrame? horizontal(Vec3 origin, Vec3 normal) {
    final n = normal.normalizedOrNull;
    if (n == null) {
      return null;
    }
    final u = Vec3.unitZ.cross(n).normalizedOrNull ?? Vec3.unitX;
    return PlaneFrame(origin, u, n.cross(u));
  }

  final Vec3 origin;
  final Vec3 u;
  final Vec3 v;

  Vec3 get normal => u.cross(v);

  /// The plane the frame lies in.
  Plane3 get plane => Plane3.normalAt(normal, origin);

  /// The space point at frame coordinates [p], [height] above the plane
  /// along [normal].
  Vec3 lift(Vec2 p, [double height = 0]) => height == 0
      ? origin + u * p.x + v * p.y
      : origin + u * p.x + v * p.y + normal * height;

  /// The frame coordinates of the foot of [p] on the plane.
  Vec2 pull(Vec3 p) {
    final r = p - origin;
    return Vec2(r.dot(u), r.dot(v));
  }

  /// The height of [p] above the plane along [normal].
  double heightOf(Vec3 p) => (p - origin).dot(normal);

  /// The space point of a planar homogeneous point, or null when it is
  /// not real: space is real, so a complex planar value has no image.
  Point3? liftPoint(ProjPoint p, [double eps = projectiveEpsilon]) {
    final real = _realTriple(p.x, p.y, p.w, () => p.isReal(eps), () {
      final n = p.normalized;
      return (n.x, n.y, n.w);
    });
    if (real == null) {
      return null;
    }
    final (x, y, w) = real;
    final s = origin * w + u * x + v * y;
    return Point3(s.x, s.y, s.z, w);
  }

  /// The orthogonal projection of a space point onto the plane, in frame
  /// coordinates. Total: a point at infinity along the normal pulls to
  /// the zero triple.
  ProjPoint pullPoint(Point3 p) {
    final r = p.xyz - origin * p.w;
    return ProjPoint.real(r.dot(u), r.dot(v), p.w);
  }

  /// The space line of a planar homogeneous line, or null when it is not
  /// real. The planar line at infinity lifts to the plane's line at
  /// infinity.
  Line3? liftLine(ProjLine l, [double eps = projectiveEpsilon]) {
    final real = _realTriple(l.a, l.b, l.c, () => l.isReal(eps), () {
      final n = l.normalized;
      return (n.a, n.b, n.c);
    });
    if (real == null) {
      return null;
    }
    final (a, b, c) = real;
    // The plane through the chart line and the normal direction, met
    // with the frame's own plane.
    final across = u * a + v * b;
    final wall = Plane3(across.x, across.y, across.z, c - across.dot(origin));
    return wall.meet(plane);
  }

  /// The orthogonal projection of a space line onto the plane, in frame
  /// coordinates. Total: a line perpendicular to the plane pulls to the
  /// zero triple.
  ProjLine pullLine(Line3 l) {
    final n = normal;
    final wallNormal = n.cross(l.direction);
    final wallOffset = n.dot(l.moment);
    return ProjLine.real(
      wallNormal.dot(u),
      wallNormal.dot(v),
      wallNormal.dot(origin) + wallOffset,
    );
  }

  static (double, double, double)? _realTriple(
    Complex a,
    Complex b,
    Complex c,
    bool Function() isReal,
    (Complex, Complex, Complex) Function() normalized,
  ) {
    if (a.im == 0 && b.im == 0 && c.im == 0) {
      return (a.re, b.re, c.re);
    }
    if (!isReal()) {
      return null;
    }
    final (x, y, z) = normalized();
    return (x.re, y.re, z.re);
  }

  @override
  bool operator ==(Object other) =>
      other is PlaneFrame &&
      other.origin == origin &&
      other.u == u &&
      other.v == v;

  @override
  int get hashCode => Object.hash(origin, u, v);

  @override
  String toString() => 'PlaneFrame($origin, $u, $v)';
}
