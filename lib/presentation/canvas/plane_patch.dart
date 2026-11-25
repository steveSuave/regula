import 'dart:math' as math;

import '../../domain/construction/geo_object.dart';
import '../../domain/math/vec3.dart';

/// How much of a plane is drawn (intent 004, milestone 2).
///
/// A plane is unbounded and a picture of one is not, so a plane is shown
/// as a **patch**: a rectangle in the plane, with one pair of sides
/// level, around every point that is on it — the points that define it and whatever has been
/// built in it — padded by a fifth, and never smaller than
/// [minHalfExtent] from its centre on each axis. The patch therefore
/// grows with the figure, the way a textbook draws a plane just large
/// enough to hold what happens in it.
///
/// "On it" is measured here, numerically, which nothing else about a
/// plane is: the patch is where ink goes, not a claim about the figure,
/// and a point that merely happens to lie in the plane stretching the
/// patch to reach it is the honest picture.
///
/// The four corners in space, in order around the patch; null while the
/// plane is undefined.
List<Vec3>? planePatch(
  GeoPlane plane,
  Iterable<GeoObject> objects, {
  required double minHalfExtent,
}) {
  final frame = plane.frame;
  if (frame == null) {
    return null;
  }
  // The patch's own axes: level and up the slope, for any plane that
  // is not itself level. The frame's axes belong to how the plane was
  // defined (a face's run along one of its edges), and a box in them
  // around a triangle is far larger than the triangle. A plane drawn
  // with one pair of sides level is also how a textbook draws it.
  final normal = frame.normal;
  final level = Vec3.unitZ.cross(normal);
  final across = level.norm >= _levelFloor ? level / level.norm : frame.u;
  final up = normal.cross(across);
  double? minX, minY, maxX, maxY;
  for (final object in objects) {
    if (object is! GeoPoint) {
      continue;
    }
    final at = object.spacePosition;
    if (at == null) {
      continue;
    }
    final reach = 1 + at.distanceTo(frame.origin);
    if (frame.heightOf(at).abs() > _onPlane * reach) {
      continue;
    }
    final r = at - frame.origin;
    final x = r.dot(across);
    final y = r.dot(up);
    minX = math.min(minX ?? x, x);
    minY = math.min(minY ?? y, y);
    maxX = math.max(maxX ?? x, x);
    maxY = math.max(maxY ?? y, y);
  }
  // And what has been built in it: a circle or a polygon on the plane's
  // own sheet reaches as far as it reaches, not only as far as its
  // defining points (intent 004, milestone 3). A circle is its extreme
  // points along the patch's two axes; lines are unbounded and frame
  // nothing.
  final reached = <Vec3>[];
  for (final object in objects) {
    if (!identical(object.sheet.plane, plane) || object.isInternal) {
      continue;
    }
    switch (object) {
      case GeoCircle(:final circle?):
        final centre = frame.lift(circle.center);
        reached
          ..add(centre + across * circle.radius)
          ..add(centre - across * circle.radius)
          ..add(centre + up * circle.radius)
          ..add(centre - up * circle.radius);
      case GeoPolygon(:final polygonVertices?):
        for (final vertex in polygonVertices) {
          reached.add(frame.lift(vertex));
        }
      default:
        break;
    }
  }
  for (final at in reached) {
    final r = at - frame.origin;
    final x = r.dot(across);
    final y = r.dot(up);
    minX = math.min(minX ?? x, x);
    minY = math.min(minY ?? y, y);
    maxX = math.max(maxX ?? x, x);
    maxY = math.max(maxY ?? y, y);
  }
  final centreX = minX == null ? 0.0 : (minX + maxX!) / 2;
  final centreY = minY == null ? 0.0 : (minY + maxY!) / 2;
  final pad = minX == null
      ? 0.0
      : patchPadding * math.max(maxX! - minX, maxY! - minY!);
  final halfX = math.max(
    minHalfExtent,
    minX == null ? 0.0 : (maxX! - minX) / 2 + pad,
  );
  final halfY = math.max(
    minHalfExtent,
    minY == null ? 0.0 : (maxY! - minY) / 2 + pad,
  );
  Vec3 corner(double sx, double sy) =>
      frame.origin +
      across * (centreX + sx * halfX) +
      up * (centreY + sy * halfY);
  return [corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, 1)];
}

/// The padding around the patch's content, as a fraction of its longer
/// side.
const double patchPadding = 0.2;

/// The least half-extent of a patch on screen, in pixels: a plane through
/// one point still shows.
const double patchMinHalfExtentPx = 56;

/// The opacity of each face of a solid that has no fill of its own.
/// Two faces lie along every view ray through a convex solid, so the
/// solid reads at about twice this.
const double solidFaceAlpha = 0.1;

/// The opacity of a patch's fill when the plane has no fill of its own.
const double patchFillAlpha = 0.12;

/// A point counts as on a plane, for the patch, within this fraction of
/// its distance from the frame's origin.
const double _onPlane = 1e-9;

/// Below this sine of its tilt a plane counts as level and its patch
/// takes the frame's own axes: a level plane has no level direction to
/// prefer.
const double _levelFloor = 0.05;
