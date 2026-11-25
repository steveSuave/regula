import '../construction/construction.dart';
import 'command.dart';

/// Lifts a free point off its sheet, or sets it back: one lift gesture
/// is one of these (intent 004, milestone 2).
///
/// The height is along the sheet's normal; exactly 0 is in the sheet.
/// The point's coordinates in the sheet do not change, so the lift
/// composes with `MoveFreePointCommand` in either order.
class SetPointHeightCommand implements Command {
  SetPointHeightCommand({
    required this.pointId,
    required this.from,
    required this.to,
  });

  final String pointId;
  final double from;
  final double to;

  @override
  void apply(Construction construction) =>
      construction.setPointHeight(pointId, to);

  @override
  void undo(Construction construction) =>
      construction.setPointHeight(pointId, from);
}
