import '../commands/command.dart';
import '../commands/set_point_height_command.dart';
import '../construction/construction.dart';
import '../construction/liftable.dart';

/// One lift gesture on a free point: the height sibling of `DragSession`
/// (intent 004, milestone 2).
///
/// Preview frames set the height directly — the sanctioned drag-preview
/// exception — and [end] rolls the preview back and returns the
/// gesture's one command, so undo, redo and the dependent recompute all
/// go through the command stack like any other edit. [cancel] rolls back
/// and returns nothing.
class LiftSession {
  LiftSession(this._construction, Liftable point)
    : pointId = point.id,
      startHeight = point.height,
      _height = point.height;

  final Construction _construction;
  final String pointId;
  final double startHeight;
  double _height;

  /// The previewed height.
  double get height => _height;

  /// Previews the point at [height] above its sheet.
  void update(double height) {
    if (height == _height || !_alive) {
      return;
    }
    _height = height;
    _construction.setPointHeight(pointId, height);
  }

  /// Rolls the preview back and returns the gesture's command, or null
  /// when it ended at the height it started from.
  Command? end() {
    final to = _height;
    cancel();
    if (to == startHeight) {
      return null;
    }
    return SetPointHeightCommand(pointId: pointId, from: startHeight, to: to);
  }

  /// Rolls the preview back. Safe when the point has since left the
  /// construction (an undo mid-gesture).
  void cancel() {
    if (_height != startHeight && _alive) {
      _construction.setPointHeight(pointId, startHeight);
    }
    _height = startHeight;
  }

  bool get _alive => _construction.byId(pointId) is Liftable;
}
