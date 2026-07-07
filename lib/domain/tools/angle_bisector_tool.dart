import '../commands/add_object_command.dart';
import '../commands/command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/angle_bisector_line.dart';
import '../construction/objects/free_point.dart';
import '../construction/objects/two_line_bisector_line.dart';
import '../math/vec2.dart';
import 'tool.dart';

/// The angle bisector tool, two modes decided by the first tap (Phase
/// 29b).
///
/// A first tap on a line enters **two-line mode**: the second, distinct
/// line commits a [TwoLineBisectorLine] bisecting the tapped wedge — one
/// `AddObjectCommand`, no points created. A first tap on a point or on
/// empty canvas enters **point mode**, the classic arm–vertex–arm
/// [AngleBisectorLine] flow — except taps on curves are *ignored* rather
/// than run through the Phase 20 ladder: the glued `PointOnObject`
/// by-products outlive the gesture, which reads as fake points for an
/// angle tool. Modes never mix (a point tap in line mode and a line tap
/// in point mode are ignored), and circle and angle taps are always
/// ignored.
class AngleBisectorTool implements ToolInputPreview {
  AngleBisectorTool({required this.newId});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  GeoLine? _line1;
  Vec2? _tap1;

  final List<({GeoPoint point, bool isNew})> _points = [];

  @override
  List<Vec2> get previewPositions => [
        for (final p in _points)
          if (p.isNew) ?p.point.position,
      ];

  @override
  List<String> get previewObjectIds => [
        ?_line1?.id,
        for (final p in _points)
          if (!p.isNew) p.point.id,
      ];

  @override
  ToolResult onInput(ToolInput input) {
    if (_line1 != null) {
      return _collectSecondLine(input);
    }
    if (input.hit case final GeoLine hit when _points.isEmpty) {
      _line1 = hit;
      _tap1 = input.position;
      return const ToolAccepted();
    }
    return _collectPoint(input);
  }

  ToolResult _collectSecondLine(ToolInput input) {
    final hit = input.hit;
    if (hit is! GeoLine || identical(hit, _line1)) {
      return const ToolIgnored();
    }
    final line1 = _line1!;
    final tap1 = _tap1!;
    reset();
    return ToolCommitted(
      AddObjectCommand(
        TwoLineBisectorLine.near(
          id: newId(),
          line1: line1,
          line2: hit,
          tap1: tap1,
          tap2: input.position,
        ),
      ),
    );
  }

  ToolResult _collectPoint(ToolInput input) {
    switch (input.hit) {
      case final GeoPoint hit:
        if (_points.any((p) => identical(p.point, hit))) {
          return const ToolIgnored();
        }
        _points.add((point: hit, isNew: false));
      case null:
        _points.add((
          point: FreePoint(id: newId(), position: input.position),
          isNew: true,
        ));
      default:
        return const ToolIgnored();
    }
    if (_points.length < 3) {
      return const ToolAccepted();
    }
    return _commitPoints();
  }

  /// Point-mode commit, matching `MultiPointTool.commitCollected`: new
  /// free points first, then the bisector, one undo unit.
  ToolResult _commitPoints() {
    final points = List.of(_points);
    reset();
    final commands = <Command>[
      for (final p in points)
        if (p.isNew) AddObjectCommand(p.point),
      AddObjectCommand(
        AngleBisectorLine(
          id: newId(),
          arm1: points[0].point,
          vertex: points[1].point,
          arm2: points[2].point,
        ),
      ),
    ];
    return ToolCommitted(
      commands.length == 1 ? commands.single : MacroCommand(commands),
    );
  }

  @override
  void reset() {
    _line1 = null;
    _tap1 = null;
    _points.clear();
  }
}
