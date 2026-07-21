import '../construction/construction.dart';
import '../math/vec2.dart';
import 'command.dart';

/// Moves a text's world anchor from one position to another.
///
/// The text sibling of `MoveFreePointCommand`: one drag gesture emits
/// exactly one of these, capturing the gesture's start ([from]) and end
/// ([to]) — never one per frame (per-frame motion is the drag-preview
/// carve-out; see CLAUDE.md). Both endpoints are stored so the command
/// can replay in either direction.
class MoveTextAnchorCommand implements Command {
  MoveTextAnchorCommand({
    required this.textId,
    required this.from,
    required this.to,
  });

  final String textId;
  final Vec2 from;
  final Vec2 to;

  @override
  void apply(Construction construction) =>
      construction.moveTextAnchor(textId, to);

  @override
  void undo(Construction construction) =>
      construction.moveTextAnchor(textId, from);
}
