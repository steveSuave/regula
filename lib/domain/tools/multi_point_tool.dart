import '../commands/add_object_command.dart';
import '../commands/command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../math/vec2.dart';
import 'point_resolution.dart';
import 'tool.dart';

/// Base for tools that collect a fixed number of *distinct* point inputs,
/// then build one or more objects on them.
///
/// Each tap resolves through the shared `resolvePoint` ladder, exactly
/// like `PointTool`: an existing point is consumed as the next input (the
/// same point twice is ignored — coincident *positions* from separate
/// taps are legal, degeneracy is the built object's business), a tap near
/// a curve crossing collects a new `IntersectionPoint`, a tap near one
/// curve a new glued `PointOnObject`, anywhere else a new `FreePoint`.
///
/// New points are held privately until the last input lands, then
/// committed together with the built objects as one `MacroCommand`, so the
/// whole construction step is a single undo unit (a bare
/// `AddObjectCommand` when every input was an existing point and the tool
/// builds a single object). Constrained vertices' parents are always
/// pre-existing curves, so vertex-before-built-object commit order stays
/// dependency-correct.
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

  /// New points (free, glued, intersection) aren't in the construction
  /// yet, so they keep the dot+ring marker; reused existing points are
  /// haloed via [previewObjectIds] instead.
  @override
  List<Vec2> get previewPositions =>
      [for (final v in _collected) if (v.isNew) ?v.point.position];

  @override
  List<String> get previewObjectIds =>
      [for (final v in _collected) if (!v.isNew) v.point.id];

  @override
  ToolResult onInput(ToolInput input) {
    if (collectVertex(input) == null) {
      return const ToolIgnored();
    }
    if (_collected.length < pointCount) {
      return const ToolAccepted();
    }
    return commitCollected();
  }

  /// Turns [input] into the next collected vertex via [resolvePoint] —
  /// the tapped existing point, or a new private point (free, glued, or
  /// intersection) — and records it. Returns null (recording nothing)
  /// when the input is unusable: an already-collected point.
  ///
  /// Subclass hook: [onInput] is collect + commit-when-full; a tool
  /// whose collection ends with a non-point input (the trapezium's
  /// position-only fourth tap) overrides [onInput] and calls this and
  /// [commitCollected] itself.
  GeoPoint? collectVertex(ToolInput input) {
    final vertex = resolvePoint(input, newId);
    if (!vertex.isNew &&
        _collected.any((v) => identical(v.point, vertex.point))) {
      return null;
    }
    _collected.add(vertex);
    return vertex.point;
  }

  /// Commits everything collected — new free points first, then
  /// [buildObjects] — as one undo unit, and resets the collection.
  ToolCommitted commitCollected() {
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
