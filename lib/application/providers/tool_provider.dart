import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/tools/tool.dart';
import 'command_stack_provider.dart';

part 'tool_provider.g.dart';

/// Snapshot handle for the active tool, mirroring `ConstructionState`'s
/// pattern: tools mutate in place as they collect inputs, so [revision]
/// gives watchers a value that *does* change when the tool's in-progress
/// state does (repaint input previews).
///
/// [tool] is null when no construction tool is active — the canvas is in
/// move/select mode (the default; Phase 7 builds selection on it).
class ActiveToolState {
  const ActiveToolState(this.tool, this.revision);

  final Tool? tool;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is ActiveToolState &&
      identical(other.tool, tool) &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(identityHashCode(tool), revision);
}

/// The active construction tool and the funnel for canvas input.
///
/// The canvas delivers every hit-tested tap to [handleInput]; a command
/// committed by the tool is executed on the command stack here, so the
/// presentation layer never handles commands itself.
@Riverpod(keepAlive: true, name: 'toolProvider')
class ToolNotifier extends _$ToolNotifier {
  @override
  ActiveToolState build() => const ActiveToolState(null, 0);

  /// Makes [tool] the active tool (null returns to move/select). The
  /// outgoing tool's partially-collected input is discarded.
  void activate(Tool? tool) {
    state.tool?.reset();
    state = ActiveToolState(tool, 0);
  }

  /// Esc: back to move/select.
  void deactivate() => activate(null);

  /// Routes one canvas input to the active tool and returns its verdict.
  ///
  /// [ToolCommitted] commands are executed on the command stack. Any
  /// result that changed the tool's state ([ToolAccepted], or
  /// [ToolCommitted]'s self-reset) bumps [ActiveToolState.revision] so
  /// preview watchers repaint. With no active tool the input is
  /// [ToolIgnored] — a tap in move/select mode is selection's business
  /// (Phase 7), not ours.
  ToolResult handleInput(ToolInput input) {
    final tool = state.tool;
    if (tool == null) {
      return const ToolIgnored();
    }
    final result = tool.onInput(input);
    switch (result) {
      case ToolCommitted(:final command):
        ref.read(commandStackProvider.notifier).execute(command);
        state = ActiveToolState(tool, state.revision + 1);
      case ToolAccepted():
        state = ActiveToolState(tool, state.revision + 1);
      case ToolIgnored():
        break;
    }
    return result;
  }
}
