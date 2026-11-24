import '../commands/add_object_command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/free_point.dart';
import '../construction/objects/line_point_plane.dart';
import '../construction/objects/three_point_plane.dart';
import '../math/vec2.dart';
import 'point_resolution.dart';
import 'tool.dart';

/// The Plane tool (intent 004, milestone 2): a plane through three
/// points, or through a line and a point, whichever the taps name.
///
/// Taps collect points (existing ones, or new ones resolved by the shared
/// ladder) and at most one line. Three points commit a
/// [ThreePointPlane]; a line and a point, in either order, commit a
/// [LinePointPlane]. A line tapped after two points is ignored — the
/// two points already name a line, and the third tap is for the third
/// point. A tap on a plane, a circle or anything else is ignored.
class PlaneTool implements ToolInputPreview, ScopedTool {
  PlaneTool({required this.newId});

  final String Function() newId;

  @override
  ToolScope get scope => ToolScope.space;

  final List<ResolvedPoint> _points = [];
  GeoLine? _line;

  @override
  bool get hasPartialInput => _points.isNotEmpty || _line != null;

  @override
  List<Vec2> get previewPositions => [
    for (final point in _points)
      if (point.isNew) ?point.point.position,
  ];

  @override
  List<String> get previewObjectIds => [
    for (final point in _points)
      if (!point.isNew) point.point.id,
    ?_line?.id,
  ];

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    if (hit is GeoLine && hit is! GeoPoint) {
      // A line tapped where two of its points would do: only before a
      // second point, and only once.
      if (_line != null || _points.length > 1) {
        return const ToolIgnored();
      }
      _line = hit;
    } else if (hit == null || hit is GeoPoint) {
      final resolved = hit is GeoPoint
          ? (point: hit, isNew: false)
          : (
              point: FreePoint(
                id: newId(),
                position: input.position,
                plane: input.plane,
              ),
              isNew: true,
            );
      if (_points.any((p) => identical(p.point, resolved.point))) {
        return const ToolIgnored();
      }
      _points.add(resolved);
    } else {
      return const ToolIgnored();
    }

    final line = _line;
    final GeoPlane plane;
    if (line != null && _points.isNotEmpty) {
      plane = LinePointPlane(id: newId(), line: line, point: _points[0].point);
    } else if (line == null && _points.length == 3) {
      plane = ThreePointPlane(
        id: newId(),
        point1: _points[0].point,
        point2: _points[1].point,
        point3: _points[2].point,
      );
    } else {
      return const ToolAccepted();
    }
    final created = [
      for (final point in _points)
        if (point.isNew) AddObjectCommand(point.point),
    ];
    reset();
    return ToolCommitted(
      created.isEmpty
          ? AddObjectCommand(plane)
          : MacroCommand([...created, AddObjectCommand(plane)]),
    );
  }

  @override
  void reset() {
    _points.clear();
    _line = null;
  }
}
