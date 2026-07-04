import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/intersection_point.dart';
import '../math/vec2.dart';
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
/// Like `TwoLineTool`, nothing is created on other taps: both inputs must
/// be existing curves, so empty-canvas, point and angle taps are ignored.
/// The first collected curve shows a preview marker at the tap's
/// projection onto its live carrier.
class IntersectionTool implements ToolInputPreview {
  IntersectionTool({required this.newId});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  /// A [GeoLine] or [GeoCircle] (enforced in [onInput]).
  GeoObject? _first;
  Vec2? _firstTap;

  @override
  List<Vec2> get previewPositions => [
    if (_firstTap case final tap?) ?_projectedOnCarrier(_first, tap),
  ];

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
      _firstTap = input.position;
      return const ToolAccepted();
    }
    if (identical(first, hit)) {
      return const ToolIgnored();
    }
    _first = null;
    _firstTap = null;
    return ToolCommitted(
      AddObjectCommand(
        IntersectionPoint(
          curve1: first,
          curve2: hit,
          branchIndex:
              nearestIntersectionBranch(first, hit, input.position)?.index ??
                  0,
          id: newId(),
        ),
      ),
    );
  }

  @override
  void reset() {
    _first = null;
    _firstTap = null;
  }
}

/// [tap] projected onto [curve]'s live carrier (orthogonally for lines,
/// radially for circles); null while the curve is undefined.
Vec2? _projectedOnCarrier(GeoObject? curve, Vec2 tap) => switch (curve) {
  GeoLine(:final line?) => line.project(tap),
  GeoCircle(:final circle?) => circle.pointAt(circle.angleAt(tap)),
  _ => null,
};
