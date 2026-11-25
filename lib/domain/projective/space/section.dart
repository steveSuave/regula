import 'dart:math' as math;

import '../../math/vec3.dart';

/// The loops in which a plane cuts a polyhedron (intent 004, milestone
/// 3): [vertices] and [faces] are the solid — each face a loop of
/// indices, each edge shared by two faces — and the plane passes through
/// [origin] with [normal].
///
/// **No band around the plane.** Each vertex is classed above or below the plane by
/// the sign of its height, and an edge is cut exactly when its ends are
/// classed apart. A vertex *on* the plane has height zero and must be
/// classed one way or the other; whichever way, every loop comes out
/// closed, because the classing is of vertices and every face reads the
/// same one. So a plane through a corner or along an edge needs no
/// special case: the cut points of the edges at that corner coincide
/// and are merged. Coincide means to within rounding at the solid's size
/// ([sectionMergeEpsilon]): that is a statement about arithmetic, not
/// about the figure, like the coincidence test a line through two points
/// makes.
///
/// Zero counts as above first. That finds a face the plane contains
/// when the rest of the solid is below it, and nothing when the rest is
/// above — so when it finds nothing, zero is counted as below and the
/// question is asked again. A plane that only touches the solid, at a
/// corner or along an edge, gives fewer than three distinct points
/// either way, which is no polygon.
///
/// Each loop is returned in space, in order around the cut, turning
/// counter-clockwise as seen from the side [normal] points to. A convex
/// solid gives at most one; a solid that is not may give several.
List<List<Vec3>> sectionLoops(
  List<Vec3> vertices,
  List<List<int>> faces,
  Vec3 origin,
  Vec3 normal,
) {
  final heights = [for (final v in vertices) (v - origin).dot(normal)];
  final above = _loops(vertices, faces, heights, normal, zeroIsAbove: true);
  return above.isNotEmpty
      ? above
      : _loops(vertices, faces, heights, normal, zeroIsAbove: false);
}

List<List<Vec3>> _loops(
  List<Vec3> vertices,
  List<List<int>> faces,
  List<double> heights,
  Vec3 normal, {
  required bool zeroIsAbove,
}) {
  bool isAbove(int i) => zeroIsAbove ? heights[i] >= 0 : heights[i] > 0;

  // The cut of an edge, named by its two ends in index order so that
  // both faces at the edge compute the same point, to the bit.
  final cuts = <(int, int), Vec3>{};
  Vec3 cut((int, int) edge) => cuts.putIfAbsent(edge, () {
    final (i, j) = edge;
    final hi = heights[i];
    final hj = heights[j];
    if (hi == 0) {
      return vertices[i];
    }
    if (hj == 0) {
      return vertices[j];
    }
    return vertices[i] + (vertices[j] - vertices[i]) * (hi / (hi - hj));
  });

  // Each face contributes the stretches of the plane inside it: its cut
  // edges, in order along the line the two planes share, taken in pairs.
  final next = <(int, int), List<(int, int)>>{};
  void link((int, int) a, (int, int) b) {
    next.putIfAbsent(a, () => []).add(b);
    next.putIfAbsent(b, () => []).add(a);
  }

  for (final face in faces) {
    final crossed = <(int, int)>[];
    for (var k = 0; k < face.length; k++) {
      final i = face[k];
      final j = face[(k + 1) % face.length];
      if (isAbove(i) != isAbove(j)) {
        crossed.add(i < j ? (i, j) : (j, i));
      }
    }
    if (crossed.length < 2) {
      continue;
    }
    if (crossed.length > 2) {
      // A face that is not convex can be crossed more than once: order
      // the cuts along the line of the two planes.
      final faceNormal = _newell([for (final i in face) vertices[i]]);
      final along = normal.cross(faceNormal);
      crossed.sort((a, b) => cut(a).dot(along).compareTo(cut(b).dot(along)));
    }
    for (var k = 0; k + 1 < crossed.length; k += 2) {
      link(crossed[k], crossed[k + 1]);
    }
  }

  // Two cuts are one corner when they are closer than rounding can
  // tell apart at the solid's size. A plane *built* through a corner of
  // the solid — through a point glued there — is through it only to the
  // last bit, so the cuts of the edges at that corner land a few ulps
  // apart instead of on each other; without this the section would
  // count a side of length 1e-16.
  var extent = 0.0;
  for (final v in vertices) {
    extent = math.max(
      extent,
      math.max(v.x.abs(), math.max(v.y.abs(), v.z.abs())),
    );
  }
  final merge = sectionMergeEpsilon * (1 + extent);

  final loops = <List<Vec3>>[];
  final visited = <(int, int)>{};
  for (final start in next.keys) {
    if (!visited.add(start)) {
      continue;
    }
    final chain = [start];
    var previous = start;
    var current = next[start]!.first;
    var closed = false;
    while (true) {
      if (current == start) {
        closed = true;
        break;
      }
      if (!visited.add(current)) {
        break;
      }
      chain.add(current);
      final neighbours = next[current]!;
      final onward = neighbours.length < 2
          ? null
          : (neighbours[0] == previous ? neighbours[1] : neighbours[0]);
      if (onward == null) {
        break;
      }
      previous = current;
      current = onward;
    }
    // A closed surface gives closed chains. A chain left open is a mesh
    // that was not one; it bounds nothing and is no section.
    if (!closed) {
      continue;
    }
    final points = <Vec3>[];
    for (final edge in chain) {
      final p = cut(edge);
      if (points.isEmpty || points.last.distanceTo(p) > merge) {
        points.add(p);
      }
    }
    while (points.length > 1 && points.first.distanceTo(points.last) <= merge) {
      points.removeLast();
    }
    if (points.length < 3) {
      continue;
    }
    if (_newell(points).dot(normal) < 0) {
      loops.add(points.reversed.toList());
    } else {
      loops.add(points);
    }
  }
  return loops;
}

/// Newell's normal of a loop: twice its vector area. Zero for a loop
/// with no area.
Vec3 _newell(List<Vec3> loop) {
  var n = Vec3.zero;
  for (var i = 0; i < loop.length; i++) {
    n += loop[i].cross(loop[(i + 1) % loop.length]);
  }
  return n;
}

/// Two cut points closer than this, relative to the solid's size, are
/// one corner of the section.
const double sectionMergeEpsilon = 1e-12;
