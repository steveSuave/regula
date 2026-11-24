import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/incidence.dart';
import '../construction/objects/intersection_point.dart';
import '../construction/objects/line_plane_intersection_point.dart';
import '../construction/objects/plane_intersection_line.dart';
import '../math/vec2.dart';
import '../projective/absolute.dart';
import 'point_coincidence.dart';
import 'point_resolution.dart';
import 'tool.dart';

/// Collects two distinct curves (lines and/or circles; segments, rays,
/// arcs and sectors count through their carriers), then creates the
/// [IntersectionPoint] branch nearest the second tap.
///
/// Branch picking rides the shared [nearestIntersectionBranch] helper.
/// Curves that don't currently intersect still commit (branch 0): the
/// point starts undefined and appears when the curves are dragged
/// together, like every other derived object.
///
/// A visible existing point on *both* curves at the chosen branch
/// already is their intersection — the crossing point of two segments
/// when one curve is their angle bisector, a shared endpoint, the same
/// pair intersected twice — so the tap is refused instead of stacking a
/// duplicate on it, like the transform tool's duplicate image (Phase
/// 40); the collected curve stays armed. "Already on this branch" is an
/// [IntersectionPoint] on the same pair whose branch is this one —
/// whichever way round either was tapped, since the pair is stored
/// canonically — or any point [structurallyIncident] on both curves whose
/// position classifies to it. A multi-branch pair dedups per branch: an existing point on
/// another branch doesn't block this one. A point occupying the crossing
/// by *theorem* rather than by incident parents (a centroid at the third
/// median's crossing) is caught by the numeric identity probe
/// ([coincidentExistingPoint]) and refused the same way.
///
/// Like `AngleTool`'s two-line mode, nothing is created on other taps:
/// both inputs must
/// be existing curves, so empty-canvas, point and angle taps are ignored.
/// The first collected curve is haloed via [previewObjectIds].
class IntersectionTool implements ToolInputPreview {
  IntersectionTool({required this.newId});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  /// A [GeoLine] or [GeoCircle] (enforced in [onInput]).
  GeoObject? _first;

  @override
  bool get hasPartialInput => _first != null;

  @override
  List<Vec2> get previewPositions => const [];

  @override
  List<String> get previewObjectIds => [?_first?.id];

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    // The null check is load-bearing: flow analysis won't promote
    // `GeoObject?` through the union of negative type tests alone.
    if (hit == null ||
        (hit is! GeoLine && hit is! GeoCircle && hit is! GeoPlane)) {
      return const ToolIgnored();
    }
    final first = _first;
    if (first == null) {
      _first = hit;
      return const ToolAccepted();
    }
    if (identical(first, hit)) {
      return const ToolIgnored();
    }
    // A plane meets a line in a point and a plane in a line (intent 004,
    // milestone 2). Those are single-valued, so there is no branch to
    // pick; the only refusal is an intersection that already exists.
    if (first is GeoPlane || hit is GeoPlane) {
      final meet = switch ((first, hit)) {
        (final GeoPlane a, final GeoPlane b) => PlaneIntersectionLine(
          id: newId(),
          plane1: a,
          plane2: b,
        ),
        (final GeoLine l, final GeoPlane p) ||
        (
          final GeoPlane p,
          final GeoLine l,
        ) => LinePlaneIntersectionPoint(id: newId(), line: l, plane: p),
        // A circle and a plane: the circle's own plane meets the other
        // in a line, and that line meets the circle. Not offered yet.
        _ => null,
      };
      if (meet == null || _existingMeet(input.objects, meet)) {
        return const ToolIgnored();
      }
      _first = null;
      return ToolCommitted(AddObjectCommand(meet));
    }
    // Two lines of which one has no value in the sheet: they meet, if at
    // all, in a plane that holds both, and that is found through the
    // plane (stage C). There are no planar candidates to pick from.
    if ((first is GeoLine && first.projLine == null) ||
        (hit is GeoLine && hit.projLine == null)) {
      return const ToolIgnored();
    }
    final index =
        nearestIntersectionBranch(
          first,
          hit,
          input.position,
          absolute: input.absolute,
        )?.index ??
        0;
    // Built before the duplicate check, not after: the constructor puts
    // the pair in canonical order and renumbers the branch onto it, so
    // the candidate's own address is the one to compare against — the tap
    // order it came from is not comparable to anything.
    final candidate = IntersectionPoint(
      curve1: first,
      curve2: hit,
      branchIndex: index,
      id: newId(),
      absolute: input.absolute,
    );
    if (_existingIntersection(input.objects, candidate, input.absolute)) {
      return const ToolIgnored();
    }
    // The structural check above misses points that sit on the crossing
    // by *theorem* rather than by incident parents — a centroid built as
    // two medians' intersection occupies the third median's crossings
    // too. The numeric identity probe catches those; same refusal.
    if (coincidentExistingPoint(
          input.objects,
          candidate,
          absolute: input.absolute,
        ) !=
        null) {
      return const ToolIgnored();
    }
    _first = null;
    return ToolCommitted(AddObjectCommand(candidate));
  }

  /// Whether a visible point in [objects] already occupies [candidate]'s
  /// branch of its curve pair (see the class doc).
  ///
  /// Two tests, because they cover different points. The **structural**
  /// one recognizes an [IntersectionPoint] already built on this pair at
  /// this branch: that *is* the same object by construction, so it dedups
  /// whether or not it currently has a position. The
  /// **positional** one classifies any other incident point by
  /// proximity, the same probe the tap itself uses — exact-position
  /// comparison would be an epsilon test against the same value computed
  /// along a different construction route.
  ///
  /// The structural test is what stops accumulation across a degeneracy
  /// (Phase 120c). Proximity can only speak for a point that has a
  /// position, so while the crossings are complex — mid-drag, or with
  /// the curves pulled apart — every tap on the pair looked unoccupied
  /// and stacked another point. The reported file had six on one conic
  /// pair, two *exact* duplicates among them (same parents, same branch —
  /// the same intersection object twice, which no later fix can separate
  /// because they are by construction the same point).
  ///
  /// It also spans **parent order**, for free: [candidate] holds its pair
  /// in canonical order whichever way round the two curves were tapped
  /// (Phase 120c), so a point built the other way round compares equal
  /// here. It did not always: the two orders number the same crossings
  /// differently, proximity papered over that while the crossing was
  /// real, and with it complex the reversed-order tap built a fresh
  /// duplicate — which is how the reported file came to hold points on
  /// *both* orderings of one conic pair.
  /// Whether [objects] already holds the meet of the same two parents,
  /// in either order.
  bool _existingMeet(Iterable<GeoObject> objects, GeoObject meet) {
    final wanted = meet.parents;
    for (final object in objects) {
      if (object.runtimeType != meet.runtimeType) {
        continue;
      }
      final parents = object.parents;
      if (wanted.every((w) => parents.any((p) => identical(p, w)))) {
        return true;
      }
    }
    return false;
  }

  bool _existingIntersection(
    Iterable<GeoObject> objects,
    IntersectionPoint candidate,
    Absolute absolute,
  ) {
    final curve1 = candidate.curve1;
    final curve2 = candidate.curve2;
    for (final object in objects) {
      if (object is! GeoPoint || !object.attributes.visible) {
        continue;
      }
      if (object is IntersectionPoint &&
          identical(object.curve1, curve1) &&
          identical(object.curve2, curve2) &&
          object.branchIndex == candidate.branchIndex) {
        return true;
      }
      if (object.position != null &&
          structurallyIncident(curve1, object) &&
          structurallyIncident(curve2, object) &&
          nearestIntersectionBranch(
                curve1,
                curve2,
                object.position!,
                absolute: absolute,
              )?.index ==
              candidate.branchIndex) {
        return true;
      }
    }
    return false;
  }

  @override
  void reset() {
    _first = null;
  }
}
