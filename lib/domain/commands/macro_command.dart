import '../construction/construction.dart';
import 'command.dart';

/// Groups a sequence of commands into one undoable step.
///
/// Macro tools (square, parallelogram, trapezium) emit one of these so
/// the whole shape appears and disappears as a unit. Children apply in
/// order and undo in reverse — the same LIFO discipline the command
/// stack guarantees between top-level commands, so children may build
/// on each other's objects.
class MacroCommand implements Command {
  MacroCommand(this.commands);

  final List<Command> commands;

  @override
  void apply(Construction construction) {
    for (final command in commands) {
      command.apply(construction);
    }
  }

  @override
  void undo(Construction construction) {
    for (final command in commands.reversed) {
      command.undo(construction);
    }
  }
}
