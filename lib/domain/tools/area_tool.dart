import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/area_measurement.dart';
import 'tool.dart';

/// One tap measures a region's area: the topmost in-threshold polygon or
/// circle (consulted from `hit`/`extraHits`, so a vertex point drawn over
/// the region can't shadow it) becomes an `AreaMeasurement` in one
/// `AddObjectCommand`. The tap never falls through to the point ladder —
/// this tool measures existing regions, it doesn't create points — and
/// any tap without a measurable region is ignored.
class AreaTool implements Tool {
  AreaTool({required this.newId});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  @override
  bool get hasPartialInput => false;

  @override
  ToolResult onInput(ToolInput input) {
    final subject = input.hits
        .where((object) => object is GeoPolygon || object is GeoCircle)
        .firstOrNull;
    if (subject == null) {
      return const ToolIgnored();
    }
    return ToolCommitted(
      AddObjectCommand(AreaMeasurement(id: newId(), subject: subject)),
    );
  }

  @override
  void reset() {
    // Stateless: every tap either commits or is ignored.
  }
}
