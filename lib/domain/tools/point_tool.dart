import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/free_point.dart';
import 'tool.dart';

/// Places a [FreePoint] wherever the user taps.
///
/// Stateless: every usable input immediately commits an
/// [AddObjectCommand]. Taps that hit an existing point are ignored —
/// stacking a coincident free point on top of one is never what the user
/// meant. Taps on lines/circles still place an unconstrained free point;
/// snapping those to a `PointOnObject` is Phase 6.
class PointTool implements Tool {
  PointTool({required this.newId});

  /// Produces a fresh unique object id per call. Injected because the
  /// domain layer has no id source of its own — the application layer
  /// passes a UUID generator, tests pass a counter.
  final String Function() newId;

  @override
  ToolResult onInput(ToolInput input) {
    if (input.hit is GeoPoint) {
      return const ToolIgnored();
    }
    return ToolCommitted(
      AddObjectCommand(FreePoint(id: newId(), position: input.position)),
    );
  }

  @override
  void reset() {
    // Stateless — nothing collected between inputs.
  }
}
