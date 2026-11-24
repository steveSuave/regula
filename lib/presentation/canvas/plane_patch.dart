import 'dart:math' as math;

import '../../domain/construction/geo_object.dart';
import '../../domain/math/vec2.dart';
import '../../domain/math/vec3.dart';

/// How much of a plane is drawn (intent 004, milestone 2).
///
/// A plane is unbounded and a picture of one is not, so a plane is shown
/// as a **patch**: a rectangle in the plane's own frame around every
/// point that is on it — the points that define it and whatever has been
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
    final p = frame.pull(at);
    minX = math.min(minX ?? p.x, p.x);
    minY = math.min(minY ?? p.y, p.y);
    maxX = math.max(maxX ?? p.x, p.x);
    maxY = math.max(maxY ?? p.y, p.y);
  }
  final centre = minX == null
      ? Vec2.zero
      : Vec2((minX + maxX!) / 2, (minY! + maxY!) / 2);
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
  return [
    frame.lift(centre + Vec2(-halfX, -halfY)),
    frame.lift(centre + Vec2(halfX, -halfY)),
    frame.lift(centre + Vec2(halfX, halfY)),
    frame.lift(centre + Vec2(-halfX, halfY)),
  ];
}

/// The padding around the patch's content, as a fraction of its longer
/// side.
const double patchPadding = 0.2;

/// The least half-extent of a patch on screen, in pixels: a plane through
/// one point still shows.
const double patchMinHalfExtentPx = 56;

/// The opacity of a patch's fill when the plane has no fill of its own.
const double patchFillAlpha = 0.12;

/// A point counts as on a plane, for the patch, within this fraction of
/// its distance from the frame's origin.
const double _onPlane = 1e-9;
