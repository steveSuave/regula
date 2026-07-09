import '../commands/delete_objects_command.dart';
import 'tool.dart';

/// The Phase 41 tap-driven delete tool, the destructive sibling of
/// `VisibilityTool`: while active, each tap on an object deletes it —
/// one `DeleteObjectsCommand` (cascading to dependents at apply time)
/// = one undo step. Empty-canvas taps do nothing.
///
/// The cascade-confirmation dialog is deliberately *not* this tool's
/// business: the canvas pre-gates the dispatch through the shared
/// `confirmCascadeDelete` before the command ever reaches the stack,
/// so the tool stays pure domain. Hidden objects aren't hit-testable
/// while it is active, so taps can only ever reach visible objects.
///
/// Activation is button-only (the app-bar delete button — no shortcut,
/// no toolbar entry, the `VisibilityTool` precedent); `Esc`/`V` or
/// pressing the button again deactivate. The tool is stateless — there
/// is nothing to collect, so [reset] is a no-op and no previews render.
class DeleteTool implements Tool {
  const DeleteTool();

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    if (hit == null) {
      return const ToolIgnored();
    }
    return ToolCommitted(DeleteObjectsCommand([hit.id]));
  }

  @override
  void reset() {
    // Stateless: every tap stands alone.
  }
}
