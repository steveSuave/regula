import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/point_on_object.dart';
import 'tool.dart';

/// Places a `PointOnObject` on the tapped curve, at the tap's projection.
///
/// Stateless, like `PointTool`: a tap on a line or circle immediately
/// commits; anything else — empty canvas, an existing point (points
/// outrank curves in the hit tester, so a tap near one lands here) — is
/// ignored.
class PointOnObjectTool implements Tool {
  PointOnObjectTool({required this.newId});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    if (hit == null || (hit is! GeoLine && hit is! GeoCircle)) {
      return const ToolIgnored();
    }
    // The hit tester only reports defined objects, so the projection in
    // `near` always has geometry to work with.
    return ToolCommitted(
      AddObjectCommand(
        PointOnObject.near(
          id: newId(),
          curve: hit,
          position: input.position,
        ),
      ),
    );
  }

  @override
  void reset() {
    // Stateless — nothing collected between inputs.
  }
}
