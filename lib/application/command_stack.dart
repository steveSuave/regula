import '../domain/commands/command.dart';
import '../domain/construction/construction.dart';

/// Undo/redo history for one [Construction].
///
/// All user actions funnel through [execute], which applies the command
/// and pushes it on the undo stack; executing anything new clears the
/// redo stack (history is linear, not a tree). Pure Dart — Phase 4 wraps
/// this in a `@riverpod` Notifier (`commandStackProvider`) so the UI can
/// watch [canUndo]/[canRedo].
class CommandStack {
  CommandStack(this.construction);

  final Construction construction;

  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  /// Applies [command] to the construction and records it for undo.
  ///
  /// If apply throws, the command is not recorded — commands validate
  /// before mutating, so a failed apply leaves the construction intact.
  void execute(Command command) {
    command.apply(construction);
    _undoStack.add(command);
    _redoStack.clear();
  }

  /// Undoes the most recent command. Throws [StateError] when there is
  /// nothing to undo — gate calls on [canUndo].
  void undo() {
    if (!canUndo) {
      throw StateError('Nothing to undo');
    }
    final command = _undoStack.removeLast();
    command.undo(construction);
    _redoStack.add(command);
  }

  /// Re-applies the most recently undone command. Throws [StateError]
  /// when there is nothing to redo — gate calls on [canRedo].
  void redo() {
    if (!canRedo) {
      throw StateError('Nothing to redo');
    }
    final command = _redoStack.removeLast();
    command.apply(construction);
    _undoStack.add(command);
  }

  /// Forgets all history (new / open construction). The construction
  /// itself is untouched.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
