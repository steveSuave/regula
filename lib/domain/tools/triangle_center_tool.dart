import '../commands/add_object_command.dart';
import '../commands/command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/free_point.dart';
import '../construction/objects/triangle_center_point.dart';
import 'tool.dart';

/// Signature shared by the four triangle-center constructors — pass a
/// tear-off (`Centroid.new`, `Orthocenter.new`, `Incenter.new`,
/// `Circumcenter.new`) to [TriangleCenterTool].
typedef TriangleCenterBuilder = TriangleCenterPoint Function({
  required String id,
  required GeoPoint vertex1,
  required GeoPoint vertex2,
  required GeoPoint vertex3,
});

/// Collects three vertices, then emits one triangle center.
///
/// A tap on an existing point consumes it as the next vertex; the same
/// point twice is ignored — a center needs three *distinct* parent points
/// (coincident *positions* are legal, the center is merely undefined
/// until dragged apart). A tap anywhere else — empty canvas or a
/// line/circle — creates a new unconstrained free point at the tap
/// position, exactly like `PointTool`.
///
/// New free points are held privately until the third vertex lands, then
/// committed together with the center as one `MacroCommand`, so the whole
/// construction step is a single undo unit. [collectedVertices] exposes
/// the in-progress vertices for input-preview rendering.
class TriangleCenterTool implements Tool {
  TriangleCenterTool({required this.newId, required this.buildCenter});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  /// Builds the concrete center from the three collected vertices.
  final TriangleCenterBuilder buildCenter;

  final List<({GeoPoint point, bool isNew})> _collected = [];

  /// The vertices collected so far (0–2 entries). Existing points track
  /// their live positions; new free points are not yet in the
  /// construction and sit where they were tapped.
  List<GeoPoint> get collectedVertices =>
      List.unmodifiable([for (final v in _collected) v.point]);

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    final ({GeoPoint point, bool isNew}) vertex;
    if (hit is GeoPoint) {
      if (_collected.any((v) => identical(v.point, hit))) {
        return const ToolIgnored();
      }
      vertex = (point: hit, isNew: false);
    } else {
      vertex = (
        point: FreePoint(id: newId(), position: input.position),
        isNew: true,
      );
    }

    _collected.add(vertex);
    if (_collected.length < 3) {
      return const ToolAccepted();
    }

    final vertices = List.of(_collected);
    _collected.clear();
    final commands = <Command>[
      for (final v in vertices)
        if (v.isNew) AddObjectCommand(v.point),
      AddObjectCommand(
        buildCenter(
          id: newId(),
          vertex1: vertices[0].point,
          vertex2: vertices[1].point,
          vertex3: vertices[2].point,
        ),
      ),
    ];
    return ToolCommitted(
      commands.length == 1 ? commands.single : MacroCommand(commands),
    );
  }

  @override
  void reset() => _collected.clear();
}
