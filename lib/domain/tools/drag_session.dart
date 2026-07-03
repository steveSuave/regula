import '../commands/command.dart';
import '../commands/move_free_point_command.dart';
import '../commands/translate_objects_command.dart';
import '../construction/construction.dart';
import '../construction/free_point_ancestors.dart';
import '../construction/geo_object.dart';
import '../construction/objects/free_point.dart';
import '../math/vec2.dart';

/// One in-progress drag gesture in move/select mode.
///
/// [update] previews each frame by mutating the construction directly —
/// the one sanctioned mutation outside a command (see CLAUDE.md). The
/// gesture must finish with [end], which rolls the preview back and
/// returns the single command capturing start → end (commands apply
/// against the pre-drag state, so the preview cannot be left in place),
/// or with [cancel], which only rolls back. A session is dead after
/// either; drop it.
///
/// What drags:
/// - a [FreePoint] moves itself → [MoveFreePointCommand];
/// - a *derived* point does not drag ([start] returns null): its position
///   is its constraint's business — an intersection lives where its
///   parents cross. Sliding a `PointOnObject` along its curve is future
///   Phase 7 work;
/// - any other object drags as a rigid translation of its free-point
///   ancestors → [TranslateObjectsCommand]: grab a circle's rim and the
///   whole circle moves because its defining points do.
class DragSession {
  DragSession._(
    this._construction,
    this._isFreePoint,
    this._grabStart,
    List<FreePoint> points,
  )   : _pointIds = [for (final point in points) point.id],
        _startPositions = {
          for (final point in points) point.id: point.position,
        };

  /// Starts dragging [target], grabbed at [grabStart] (world coordinates).
  /// Null when the target cannot drag (a derived point, or nothing free
  /// upstream).
  static DragSession? start(
    Construction construction,
    GeoObject target,
    Vec2 grabStart,
  ) {
    if (target is GeoPoint && target is! FreePoint) {
      return null;
    }
    final points = freePointAncestors(target);
    if (points.isEmpty) {
      return null;
    }
    return DragSession._(
      construction,
      target is FreePoint,
      grabStart,
      [...points],
    );
  }

  final Construction _construction;
  final bool _isFreePoint;
  final Vec2 _grabStart;
  final List<String> _pointIds;
  final Map<String, Vec2> _startPositions;

  Vec2 _delta = Vec2.zero;

  /// Previews the gesture at [pointer] (world): every dragged point sits
  /// at its start position plus the pointer's total delta, so a rigid
  /// shape stays rigid regardless of frame timing.
  void update(Vec2 pointer) {
    _delta = pointer - _grabStart;
    for (final id in _pointIds) {
      _construction.moveFreePoint(id, _startPositions[id]! + _delta);
    }
  }

  /// Rolls the preview back and returns the gesture's one command, or
  /// null when the pointer never moved (nothing to undo).
  Command? end() {
    final delta = _delta;
    _rollback();
    if (delta == Vec2.zero) {
      return null;
    }
    if (_isFreePoint) {
      final id = _pointIds.single;
      final from = _startPositions[id]!;
      return MoveFreePointCommand(pointId: id, from: from, to: from + delta);
    }
    return TranslateObjectsCommand(pointIds: _pointIds, delta: delta);
  }

  /// Rolls the preview back (Esc, tool switch, undo mid-drag).
  void cancel() => _rollback();

  /// Restores every dragged point's start position verbatim (float-exact,
  /// like the commands). Points that vanished under the session — an
  /// undo mid-drag can remove them — are skipped rather than thrown on.
  void _rollback() {
    for (final id in _pointIds) {
      if (_construction.contains(id)) {
        _construction.moveFreePoint(id, _startPositions[id]!);
      }
    }
  }
}
