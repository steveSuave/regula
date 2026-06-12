import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/commands/command.dart';
import '../command_stack.dart';
import 'construction_provider.dart';

part 'command_stack_provider.g.dart';

/// What the UI needs to render undo/redo affordances. A record, so
/// executing a second command while undo is already enabled does not
/// notify watchers (structural equality — the flags didn't change).
typedef UndoRedoState = ({bool canUndo, bool canRedo});

/// Riverpod wrapper around [CommandStack]: all user actions funnel through
/// [execute], and the UI watches the state for undo/redo button enablement.
///
/// Depends on the construction *instance* (not its revision), so the stack
/// survives every mutation but is rebuilt — history dropped — when
/// `constructionProvider.replace` swaps in a new construction. Undoing
/// commands against a construction they never touched would corrupt it.
@Riverpod(keepAlive: true, name: 'commandStackProvider')
class CommandStackNotifier extends _$CommandStackNotifier {
  late CommandStack _stack;

  @override
  UndoRedoState build() {
    final construction = ref.watch(
      constructionProvider.select((ConstructionState s) => s.construction),
    );
    _stack = CommandStack(construction);
    return (canUndo: false, canRedo: false);
  }

  /// Applies [command] and records it for undo. A command that throws in
  /// `apply` validated before mutating, so the construction and the state
  /// here are both unchanged on failure.
  void execute(Command command) {
    _stack.execute(command);
    _refresh();
  }

  /// Throws [StateError] when there is nothing to undo — gate on
  /// `state.canUndo`.
  void undo() {
    _stack.undo();
    _refresh();
  }

  /// Throws [StateError] when there is nothing to redo — gate on
  /// `state.canRedo`.
  void redo() {
    _stack.redo();
    _refresh();
  }

  /// Forgets all history; the construction is untouched.
  void clear() {
    _stack.clear();
    _refresh();
  }

  void _refresh() {
    state = (canUndo: _stack.canUndo, canRedo: _stack.canRedo);
  }
}
