import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../math/vec2.dart';
import 'tool.dart';

/// Builds the derived object from two collected lines, in tap order.
typedef TwoLineBuilder = GeoObject Function(
  String id,
  GeoLine first,
  GeoLine second,
);

/// Collects two distinct lines, then builds one object on them (the
/// angle between two lines; segments and rays count through their
/// carriers).
///
/// Unlike `MultiPointTool`, nothing is created on other taps: both inputs
/// must be existing lines, so empty-canvas, point and circle taps are
/// ignored. The first collected line shows a preview marker at the tap's
/// projection onto its live carrier, matching `PointAndLineTool`.
class TwoLineTool implements ToolInputPreview {
  TwoLineTool({required this.newId, required this.build});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  final TwoLineBuilder build;

  GeoLine? _first;
  Vec2? _firstTap;

  @override
  List<Vec2> get previewPositions =>
      [if (_firstTap case final tap?) ?_first?.line?.project(tap)];

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    if (hit is! GeoLine) {
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
    return ToolCommitted(AddObjectCommand(build(newId(), first, hit)));
  }

  @override
  void reset() {
    _first = null;
    _firstTap = null;
  }
}
