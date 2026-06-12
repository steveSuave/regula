import '../construction/construction.dart';

/// A reversible user action on the construction.
///
/// Every mutation of the construction goes through a command (the sole
/// carve-out is drag *previews*, which mutate per-frame and must end by
/// emitting exactly one command — see CLAUDE.md). The `CommandStack` in the
/// application layer applies commands and replays [undo]/[apply] for
/// undo/redo.
///
/// Contract:
/// - [undo] is only called on a construction where this command was the
///   most recent mutation (the stack is LIFO, so this holds by design).
/// - [apply] after [undo] must restore the same state (redo), so a command
///   must be replayable from the data it holds.
abstract interface class Command {
  void apply(Construction construction);

  void undo(Construction construction);
}
