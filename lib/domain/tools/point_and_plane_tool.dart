import '../commands/add_object_command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/free_point.dart';
import '../construction/objects/parallel_plane.dart';
import '../construction/objects/perpendicular_plane.dart';
import '../construction/objects/perpendicular_to_plane_line.dart';
import '../math/vec2.dart';
import 'tool.dart';

/// Builds the object a point-and-plane tool commits.
typedef PointAndPlaneBuilder = GeoObject Function({
  required String id,
  required GeoPoint through,
  required GeoPlane plane,
});

/// A tool that takes a point and a plane, in either order (intent 004,
/// milestone 2): the plane sibling of `PointAndLineTool`, behind
/// "Perpendicular to plane" and "Parallel plane".
///
/// A tap on a point takes it; a tap on empty canvas places a new free
/// point; a tap on a plane takes the plane. A plane's patch is hit only
/// where nothing else is in reach, so a point lying in the plane is still
/// picked as the point.
class PointAndPlaneTool implements ToolInputPreview {
  PointAndPlaneTool({required this.newId, required this.build});

  final String Function() newId;
  final PointAndPlaneBuilder build;

  GeoPoint? _point;
  bool _pointIsNew = false;
  GeoPlane? _plane;

  @override
  bool get hasPartialInput => _point != null || _plane != null;

  @override
  List<Vec2> get previewPositions => [if (_pointIsNew) ?_point?.position];

  @override
  List<String> get previewObjectIds => [
    if (!_pointIsNew) ?_point?.id,
    ?_plane?.id,
  ];

  @override
  ToolResult onInput(ToolInput input) {
    switch (input.hit) {
      case final GeoPoint hit:
        if (_point != null) return const ToolIgnored();
        _point = hit;
        _pointIsNew = false;
      case final GeoPlane hit:
        if (_plane != null) return const ToolIgnored();
        _plane = hit;
      case null:
        if (_point != null) return const ToolIgnored();
        _point = FreePoint(id: newId(), position: input.position);
        _pointIsNew = true;
      case GeoLine() ||
          GeoCircle() ||
          GeoAngle() ||
          GeoPolygon() ||
          GeoMeasurement() ||
          GeoLocus() ||
          GeoText():
        return const ToolIgnored();
    }

    final point = _point;
    final plane = _plane;
    if (point == null || plane == null) {
      return const ToolAccepted();
    }
    final pointIsNew = _pointIsNew;
    reset();
    final derived = build(id: newId(), through: point, plane: plane);
    return ToolCommitted(
      pointIsNew
          ? MacroCommand([AddObjectCommand(point), AddObjectCommand(derived)])
          : AddObjectCommand(derived),
    );
  }

  @override
  void reset() {
    _point = null;
    _pointIsNew = false;
    _plane = null;
  }
}

/// The line through [through] perpendicular to [plane].
GeoObject buildPerpendicularToPlane({
  required String id,
  required GeoPoint through,
  required GeoPlane plane,
}) => PerpendicularToPlaneLine(id: id, through: through, plane: plane);

/// The plane through [through] parallel to [plane].
GeoObject buildParallelPlane({
  required String id,
  required GeoPoint through,
  required GeoPlane plane,
}) => ParallelPlane(id: id, through: through, reference: plane);

/// The plane through [through] perpendicular to the line [reference]:
/// a `PointAndLineBuilder`, so the existing point-and-line tool collects
/// it.
GeoObject buildPerpendicularPlane({
  required String id,
  required GeoPoint through,
  required GeoLine reference,
}) => PerpendicularPlane(id: id, through: through, line: reference);
