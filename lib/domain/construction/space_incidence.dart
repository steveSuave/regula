import 'geo_object.dart';
import 'objects/chart_line.dart';
import 'objects/chart_point.dart';
import 'objects/intersection_point.dart';
import 'objects/line_plane_intersection_point.dart';
import 'objects/line_point_plane.dart';
import 'objects/line_through_two_points.dart';
import 'objects/midpoint.dart';
import 'objects/parallel_line.dart';
import 'objects/parallel_plane.dart';
import 'objects/perpendicular_plane.dart';
import 'objects/plane_intersection_line.dart';
import 'objects/point_on_object.dart';
import 'objects/ray.dart';
import 'objects/segment.dart';
import 'objects/three_point_plane.dart';

/// Whether [object] lies in [plane] **by construction** — the space
/// sibling of `structurallyIncident` (intent 004, milestone 2).
///
/// Parent ties and construction theorems only, never a test on current
/// positions: a point that merely happens to be in the plane is not in
/// it, because it need not stay. This is what lets a planar tool working
/// in a plane take an object from elsewhere (through a `ChartPoint` or
/// `ChartLine` adapter) without the figure ever lying: what it takes can
/// never leave.
///
/// The one input that is state and not structure is whether an object on
/// the plane's own sheet currently has a value there — a free point
/// placed in the plane and then lifted off it is not in it. That test is
/// exact (`height != 0`), like every degeneracy, and it is why an adapter
/// asks this again at each recompute.
///
/// Sound and incomplete. A point in the plane by a theorem this list
/// does not know is refused, which is the safe side; the list grows from
/// real cases.
///
/// Points:
/// - on the plane's sheet, with a value there;
/// - a defining point of the plane (always in it, wherever it is moved or
///   lifted, since the plane follows);
/// - where a line meets the plane;
/// - the midpoint of two points in it; a point glued to, or an
///   intersection on, a line in it;
/// - an adapter of a point in it.
///
/// Lines:
/// - on the plane's sheet, with a value there;
/// - a defining line of the plane; the line it shares with another plane;
/// - through two points in it; the parallel through a point in it to a
///   line in it;
/// - an adapter of a line in it.
bool liesIn(GeoObject object, GeoPlane plane) =>
    _liesIn(object, plane, Set<GeoObject>.identity());

bool _liesIn(GeoObject object, GeoPlane plane, Set<GeoObject> visiting) {
  // The DAG has no cycles, but shared ancestors are common; a branch
  // already being asked about cannot prove itself.
  if (!visiting.add(object)) {
    return false;
  }
  try {
    final sheet = object.sheet;
    if (identical(sheet.plane, plane)) {
      return switch (object) {
        GeoPoint() => object.projPoint != null,
        GeoLine() => object.projLine != null,
        _ => false,
      };
    }
    bool within(GeoObject other) => _liesIn(other, plane, visiting);
    return switch (object) {
      GeoPoint() =>
        _definesAsPoint(plane, object) ||
            switch (object) {
              LinePlaneIntersectionPoint(plane: final host) => identical(
                host,
                plane,
              ),
              Midpoint(:final point1, :final point2) =>
                within(point1) && within(point2),
              PointOnObject(:final curve) => curve is GeoLine && within(curve),
              IntersectionPoint(:final curve1, :final curve2) =>
                (curve1 is GeoLine && within(curve1)) ||
                    (curve2 is GeoLine && within(curve2)),
              ChartPoint(:final source) => within(source),
              _ => false,
            },
      GeoLine() =>
        _definesAsLine(plane, object) ||
            switch (object) {
              PlaneIntersectionLine(:final plane1, :final plane2) =>
                identical(plane1, plane) || identical(plane2, plane),
              Segment(:final point1, :final point2) =>
                within(point1) && within(point2),
              LineThroughTwoPoints(:final point1, :final point2) =>
                within(point1) && within(point2),
              Ray(:final origin, :final through) =>
                within(origin) && within(through),
              ParallelLine(:final through, :final reference) =>
                within(through) && within(reference),
              ChartLine(:final source) => within(source),
              _ => false,
            },
      _ => false,
    };
  } finally {
    visiting.remove(object);
  }
}

bool _definesAsPoint(GeoPlane plane, GeoPoint point) => switch (plane) {
  ThreePointPlane(:final point1, :final point2, :final point3) =>
    identical(point1, point) ||
        identical(point2, point) ||
        identical(point3, point),
  LinePointPlane(point: final through) => identical(through, point),
  PerpendicularPlane(:final through) => identical(through, point),
  ParallelPlane(:final through) => identical(through, point),
  _ => false,
};

bool _definesAsLine(GeoPlane plane, GeoLine line) => switch (plane) {
  LinePointPlane(line: final host) => identical(host, line),
  _ => false,
};

/// Whether [point] is in [plane] — null being the base plane — either
/// on its sheet with a value there, or by construction ([liesIn]). What
/// a solid asks of each vertex of a base that needs a plane (intent 004,
/// milestone 3): exact, and asked again at every recompute, because a
/// point placed in a plane and then lifted has left it.
bool inPlaneOrSheet(GeoPoint point, GeoPlane? plane) {
  final sheet = point.sheet;
  if (plane == null) {
    return sheet.isBase && point.projPoint != null;
  }
  return liesIn(point, plane);
}

/// The planes of [objects] in which every one of [things] lies by
/// construction, [preferred] first when it is among them.
List<GeoPlane> planesHolding(
  Iterable<GeoObject> objects,
  List<GeoObject> things, {
  GeoPlane? preferred,
}) {
  final holding = [
    for (final object in objects)
      if (object is GeoPlane && things.every((t) => liesIn(t, object))) object,
  ];
  if (preferred != null && holding.remove(preferred)) {
    holding.insert(0, preferred);
  }
  return holding;
}
