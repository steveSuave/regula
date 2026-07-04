import '../construction/construction.dart';
import 'command.dart';

/// Slides a constrained point (`PointOnObject`) along its host curve by
/// re-setting its analytic parameter.
///
/// One slide-drag gesture emits exactly one of these, capturing the
/// gesture's start ([from]) and end ([to]) parameters — never one per
/// frame (per-frame motion is the drag-preview carve-out; see CLAUDE.md).
/// Both endpoints are stored so the command can replay in either
/// direction, float-exact.
class SetPointOnObjectParameterCommand implements Command {
  SetPointOnObjectParameterCommand({
    required this.pointId,
    required this.from,
    required this.to,
  });

  final String pointId;
  final double from;
  final double to;

  @override
  void apply(Construction construction) =>
      construction.setPointOnObjectParameter(pointId, to);

  @override
  void undo(Construction construction) =>
      construction.setPointOnObjectParameter(pointId, from);
}
