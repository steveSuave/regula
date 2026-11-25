import '../commands/add_object_command.dart';
import '../commands/command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/chart_line.dart';
import '../construction/objects/chart_point.dart';
import '../construction/space_incidence.dart';
import 'tool.dart';

/// Why the active plane's scope turned a tap away.
enum ScopeRefusal {
  /// The tapped object is not in the active plane by construction.
  notInPlane,
}

/// What the scope made of one input: the input the tool should see, or
/// the reason the tap goes no further.
typedef ScopedInput = ({ToolInput? input, ScopeRefusal? refusal});

/// The active plane's say over what a tool is handed (intent 004,
/// milestone 2).
///
/// Every tool that predates space builds with the planar kernel, in one
/// plane's coordinates: its parents must all be on the same sheet. So
/// between the canvas and a [ToolScope.plane] tool sits this. For each
/// object under the tap it decides:
///
/// - on the active plane's sheet: the tool sees it as it is;
/// - elsewhere, but lying in the active plane by construction
///   (`liesIn`): the tool sees an adapter (`ChartPoint` / `ChartLine`)
///   that reads it in the plane's coordinates — an existing one for that
///   object and plane if there is one, else a new one, created here and
///   added to the construction by the same command that adds what the
///   tool builds;
/// - otherwise: refused. If it was the object the user tapped, the whole
///   tap is refused, with the reason, rather than quietly landing on the
///   plane behind it. A plane itself is never the object tapped: it is
///   the ground the tap falls on, and is passed over.
///
/// No tool is changed for this, and none can build across sheets by
/// accident. A [ToolScope.space] tool is handed everything untouched.
///
/// The scope holds the adapters a tool's collected inputs depend on
/// until the tool commits or resets, so it has the tool's lifetime: the
/// tool notifier keeps one beside the active tool.
class PlaneScope {
  final List<GeoObject> _pending = [];

  /// The input [tool] should be given for [input], or a refusal.
  ScopedInput adapt(ToolInput input, Tool tool, String Function() newId) {
    if (tool is ScopedTool && tool.scope == ToolScope.space) {
      return (input: input, refusal: null);
    }
    final takesSpaceLines =
        tool is ScopedTool && tool.scope == ToolScope.planeAndSpaceLines;
    final plane = input.plane;
    final target = plane == null ? Sheet.base : Sheet.of(plane);
    final created = <GeoObject>[];
    final seen = <GeoObject>[];
    var first = true;
    for (final hit in input.hits) {
      // A plane under the tap is where the tap lands, not what it is
      // on: a tool that builds in a plane does not take planes, and a
      // tap inside the active plane's own patch must not be refused for
      // having hit it.
      if (hit is GeoPlane) {
        continue;
      }
      // So is a face over points of space: a region with no value in
      // any sheet, which no planar tool can build on and which is seen
      // through. The tap lands on the active plane behind it.
      if (hit is GeoPolygon && hit.polygonVertices == null) {
        continue;
      }
      // A line with no planar value is its own host for a glued point.
      if (takesSpaceLines && _drawnInSpace(hit)) {
        seen.add(hit);
        first = false;
        continue;
      }
      // On the active sheet is not enough: a point lifted off it, or an
      // edge to one, is on the sheet by structure and has no value in
      // it, and a planar tool can build nothing on that (intent 004,
      // milestone 3).
      final adapted = hit.sheet == target && _hasValueInSheet(hit)
          ? hit
          : _adapt(hit, plane, input.objects, created, newId);
      if (adapted != null) {
        seen.add(adapted);
      } else if (first) {
        return (input: null, refusal: ScopeRefusal.notInPlane);
      }
      first = false;
    }
    _pending.addAll(created);
    return (input: input.withHits(seen), refusal: null);
  }

  GeoObject? _adapt(
    GeoObject hit,
    GeoPlane? plane,
    Iterable<GeoObject> objects,
    List<GeoObject> created,
    String Function() newId,
  ) {
    if (plane == null || !liesIn(hit, plane)) {
      return null;
    }
    final existing = adapterOf(hit, plane, [
      ...objects,
      ..._pending,
      ...created,
    ]);
    if (existing != null) {
      return existing;
    }
    final adapter = switch (hit) {
      GeoPoint() => ChartPoint(id: newId(), source: hit, plane: plane),
      GeoLine() => ChartLine(id: newId(), source: hit, plane: plane),
      _ => null,
    };
    if (adapter != null) {
      created.add(adapter);
    }
    return adapter;
  }

  /// [command] with the adapters it depends on added first, in one
  /// macro: what the tool committed, made whole. Clears the scope.
  static bool _hasValueInSheet(GeoObject object) => switch (object) {
    GeoPoint() => object.projPoint != null,
    GeoLine() => object.projLine != null,
    _ => true,
  };

  static bool _drawnInSpace(GeoObject object) =>
      object is GeoLine && object.line == null && object.hasSpaceExtent;

  Command commit(Command command) {
    final needed = <GeoObject>{};
    void need(GeoObject object) {
      for (final parent in object.parents) {
        if (_pending.any((a) => identical(a, parent))) {
          needed.add(parent);
        }
        need(parent);
      }
    }

    void walk(Command c) {
      switch (c) {
        case AddObjectCommand(:final object):
          need(object);
        case MacroCommand(:final commands):
          commands.forEach(walk);
        default:
          break;
      }
    }

    walk(command);
    final adapters = [
      for (final adapter in _pending)
        if (needed.contains(adapter)) AddObjectCommand(adapter),
    ];
    _pending.clear();
    return adapters.isEmpty ? command : MacroCommand([...adapters, command]);
  }

  /// Forgets the adapters held for a tool that reset or went away.
  void reset() => _pending.clear();

  /// The id to highlight for a tool's collected input [id]: the source's
  /// when the tool is holding an adapter not yet in the construction.
  String sourceIdOf(String id) {
    for (final adapter in _pending) {
      if (adapter.id == id) {
        return switch (adapter) {
          ChartPoint(:final source) => source.id,
          ChartLine(:final source) => source.id,
          _ => id,
        };
      }
    }
    return id;
  }
}

/// The adapter that already reads [source] in [plane] among [objects],
/// or null. One adapter per object and plane is enough for any number of
/// constructions, and it is what lets two tools agree that they were
/// handed the same point.
GeoObject? adapterOf(
  GeoObject source,
  GeoPlane plane,
  Iterable<GeoObject> objects,
) {
  for (final object in objects) {
    final matches = switch (object) {
      ChartPoint(source: final s, plane: final p) =>
        identical(s, source) && identical(p, plane),
      ChartLine(source: final s, plane: final p) =>
        identical(s, source) && identical(p, plane),
      _ => false,
    };
    if (matches) {
      return object;
    }
  }
  return null;
}
