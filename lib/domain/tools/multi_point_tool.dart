import '../commands/add_object_command.dart';
import '../commands/command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/free_point.dart';
import '../math/vec2.dart';
import 'tool.dart';

/// Base for tools that collect a fixed number of *distinct* point inputs,
/// then build one or more objects on them.
///
/// A tap on an existing point consumes it as the next input; the same
/// point twice is ignored (coincident *positions* from separate taps are
/// legal — degeneracy is the built object's business). A tap anywhere
/// else — empty canvas or a curve — creates a new unconstrained free
/// point at the tap position, exactly like `PointTool`.
///
/// New free points are held privately until the last input lands, then
/// committed together with the built objects as one `MacroCommand`, so the
/// whole construction step is a single undo unit (a bare
/// `AddObjectCommand` when every input was an existing point and the tool
/// builds a single object).
/// In-progress input is exposed for marker rendering via
/// [ToolInputPreview] (and, typed, via [collectedVertices]).
abstract class MultiPointTool implements ToolInputPreview {
  MultiPointTool({required this.newId});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  /// How many point inputs [buildObjects] needs.
  int get pointCount;

  /// Builds the derived objects once [pointCount] points are collected,
  /// in tap order. Runs at commit time; use [newId] for the objects' ids.
  ///
  /// The returned list must be in dependency order (an object only after
  /// its parents) — each is added with its own `AddObjectCommand`, in
  /// order. Single-object tools return a one-element list; macro tools
  /// (square, …) return the whole shape, hidden scaffolding included.
  List<GeoObject> buildObjects(List<GeoPoint> points);

  final List<({GeoPoint point, bool isNew})> _collected = [];

  /// The points collected so far (up to `pointCount − 1` entries).
  /// Existing points track their live positions; new free points are not
  /// yet in the construction and sit where they were tapped.
  List<GeoPoint> get collectedVertices =>
      List.unmodifiable([for (final v in _collected) v.point]);

  @override
  List<Vec2> get previewPositions =>
      [for (final v in _collected) ?v.point.position];

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
    if (_collected.length < pointCount) {
      return const ToolAccepted();
    }

    final vertices = List.of(_collected);
    _collected.clear();
    final commands = <Command>[
      for (final v in vertices)
        if (v.isNew) AddObjectCommand(v.point),
      for (final object in buildObjects([for (final v in vertices) v.point]))
        AddObjectCommand(object),
    ];
    return ToolCommitted(
      commands.length == 1 ? commands.single : MacroCommand(commands),
    );
  }

  @override
  void reset() => _collected.clear();
}
