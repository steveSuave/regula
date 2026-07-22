import '../commands/add_object_command.dart';
import 'point_resolution.dart';
import 'tool.dart';

/// Places a point wherever the user taps, resolved through the shared
/// [resolvePoint] ladder: a tap near the crossing of two curves snaps to
/// an `IntersectionPoint`, a tap near one curve glues a `PointOnObject`
/// to it, anywhere else drops a `FreePoint`. Taps that hit an existing
/// point are ignored — stacking a coincident point on top of one is never
/// what the user meant.
///
/// Stateless: every usable input immediately commits an
/// [AddObjectCommand].
class PointTool implements Tool {
  PointTool({required this.newId});

  /// Produces a fresh unique object id per call. Injected because the
  /// domain layer has no id source of its own — the application layer
  /// passes a UUID generator, tests pass a counter.
  final String Function() newId;

  @override
  bool get hasPartialInput => false;

  @override
  ToolResult onInput(ToolInput input) {
    final resolved = resolvePoint(input, newId);
    if (!resolved.isNew) {
      return const ToolIgnored();
    }
    return ToolCommitted(AddObjectCommand(resolved.point));
  }

  @override
  void reset() {
    // Stateless — nothing collected between inputs.
  }
}
