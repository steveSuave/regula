/// The Euclidean constructions of space: perpendiculars and parallels.
///
/// Join and meet (`Point3.join`, `Line3.joinPoint`, `Plane3.meet`,
/// `Line3.meetPlane`) are projective and need no metric. These four do:
/// they read a plane's normal or a line's direction as a direction of
/// Euclidean space, which is why space objects need a Euclidean document.
library;

import 'line3.dart';
import 'plane3.dart';
import 'point3.dart';

/// The line through [p] perpendicular to [plane]. The zero line when
/// [plane] has no normal (the plane at infinity) or [p] is itself the
/// normal's point at infinity.
Line3 perpendicularLineToPlane(Point3 p, Plane3 plane) =>
    p.join(Point3.direction(plane.normal));

/// The line through [p] parallel to [line]. The zero line when [p] is
/// the line's own point at infinity.
Line3 parallelLineThrough(Point3 p, Line3 line) => p.join(line.directionPoint);

/// The midpoint of two points: the affine midpoint of two finite points,
/// and the point at infinity itself when one of them is at infinity (the
/// affine limit, as the planar `midpointOf` answers).
Point3 midpoint3(Point3 a, Point3 b) {
  final sum = a.xyz * b.w + b.xyz * a.w;
  return Point3(sum.x, sum.y, sum.z, 2 * a.w * b.w);
}

/// The plane through [p] perpendicular to [line]. The zero plane when
/// [line] has no direction and [p] is at infinity.
Plane3 perpendicularPlaneToLine(Point3 p, Line3 line) {
  final n = line.direction * p.w;
  return Plane3(n.x, n.y, n.z, -line.direction.dot(p.xyz));
}

/// The plane through [p] parallel to [plane].
Plane3 parallelPlaneThrough(Point3 p, Plane3 plane) {
  final n = plane.normal * p.w;
  return Plane3(n.x, n.y, n.z, -plane.normal.dot(p.xyz));
}
