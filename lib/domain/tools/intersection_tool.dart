import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/incidence.dart';
import '../construction/objects/intersection_point.dart';
import '../math/vec2.dart';
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
/// A visible existing point [structurallyIncident] on *both* curves at
/// the chosen branch already is their intersection — the crossing point
/// of two segments when one curve is their angle bisector, a shared
/// endpoint, the same pair intersected twice — so the tap is refused
/// instead of stacking a duplicate on it, like the transform tool's
/// duplicate image (Phase 40); the collected curve stays armed. A
/// two-branch pair dedups per branch: an existing point on the other
/// branch doesn't block this one. A point occupying the crossing by
/// *theorem* rather than by incident parents (a centroid at the third
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
  List<Vec2> get previewPositions => const [];

  @override
  List<String> get previewObjectIds => [?_first?.id];

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    // The null check is load-bearing: flow analysis won't promote
    // `GeoObject?` through the union of negative type tests alone.
    if (hit == null || (hit is! GeoLine && hit is! GeoCircle)) {
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
    final index =
        nearestIntersectionBranch(first, hit, input.position)?.index ?? 0;
    if (_existingIntersection(input.objects, first, hit, index)) {
      return const ToolIgnored();
    }
    final candidate = IntersectionPoint(
      curve1: first,
      curve2: hit,
      branchIndex: index,
      id: newId(),
    );
    // The structural check above misses points that sit on the crossing
    // by *theorem* rather than by incident parents — a centroid built as
    // two medians' intersection occupies the third median's crossings
    // too. The numeric identity probe catches those; same refusal.
    if (coincidentExistingPoint(input.objects, candidate) != null) {
      return const ToolIgnored();
    }
    _first = null;
    return ToolCommitted(AddObjectCommand(candidate));
  }

  /// Whether a visible, defined point in [objects] already occupies
  /// branch [index] of `curve1 ∩ curve2` (see the class doc). Incidence
  /// on both curves proves the point sits on *a* crossing; which branch
  /// is classified by proximity, the same probe the tap itself uses —
  /// exact-position comparison would be an epsilon test against the same
  /// value computed along a different construction route.
  bool _existingIntersection(
    Iterable<GeoObject> objects,
    GeoObject curve1,
    GeoObject curve2,
    int index,
  ) {
    for (final object in objects) {
      if (object is GeoPoint &&
          object.attributes.visible &&
          object.position != null &&
          structurallyIncident(curve1, object) &&
          structurallyIncident(curve2, object) &&
          nearestIntersectionBranch(curve1, curve2, object.position!)?.index ==
              index) {
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
