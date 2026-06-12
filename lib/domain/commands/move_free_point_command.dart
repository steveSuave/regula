import '../construction/construction.dart';
import '../math/vec2.dart';
import 'command.dart';

/// Moves a free point from one position to another.
///
/// One drag gesture emits exactly one of these, capturing the gesture's
/// start ([from]) and end ([to]) — never one per frame (per-frame motion
/// is the drag-preview carve-out; see CLAUDE.md). Both endpoints are
/// stored so the command can replay in either direction.
class MoveFreePointCommand implements Command {
  MoveFreePointCommand({
    required this.pointId,
    required this.from,
    required this.to,
  });

  final String pointId;
  final Vec2 from;
  final Vec2 to;

  @override
  void apply(Construction construction) =>
      construction.moveFreePoint(pointId, to);

  @override
  void undo(Construction construction) =>
      construction.moveFreePoint(pointId, from);
}
