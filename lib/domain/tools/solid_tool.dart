import '../commands/add_object_command.dart';
import '../commands/macro_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/free_point.dart';
import '../construction/objects/prism.dart';
import '../construction/objects/pyramid.dart';
import '../construction/objects/raised_point.dart';
import '../construction/objects/segment.dart';
import '../construction/objects/translated_point.dart';
import '../construction/space_incidence.dart';
import '../math/vec2.dart';
import '../math/vec3.dart';
import '../projective/space/plane_frame.dart';
import 'point_resolution.dart';
import 'tool.dart';

/// A solid over a base polygon: tap the base's corners, tap the first
/// again to close it, then tap once more for the point the solid rises
/// to (intent 004, milestone 3). The shared shape of [PyramidTool] and
/// [PrismTool].
///
/// **The base lies in the active plane.** Each corner is a point on the
/// active plane's sheet, or one that lies in the plane by construction;
/// any other is refused with the reason, as a planar tool's tap is. The
/// corners themselves reach the solid as they are, not through adapters:
/// a solid is built from points of space.
///
/// **The last tap.** On an existing point, the solid rises to it — an
/// apex anywhere, or the far corner of an oblique prism. Anywhere else
/// it rises to a new point at a default height (the mean base side) on
/// the viewer's side of the plane, and that point is handed to the
/// selection ([takeSelection]) so that its lift handle is the next thing
/// under the finger: pulling the solid up is the lift gesture.
///
/// One command: the new points, every edge that is not already a
/// segment, and the solid.
abstract class SolidTool
    implements ToolInputPreview, ScopedTool, HandsOverSelection {
  SolidTool({required this.newId});

  final String Function() newId;

  @override
  ToolScope get scope => ToolScope.space;

  final List<ResolvedPoint> _base = [];
  bool _closed = false;
  String? _handOver;

  /// The point a new solid rises to when the last tap names none.
  /// [mean] is the mean of the base in [plane]'s coordinates, [height]
  /// the signed default height.
  GeoPoint newTop(
    List<GeoPoint> base,
    GeoPlane? plane,
    Vec2 mean,
    double height,
  );

  /// The solid, with whatever further corners it needs: the objects to
  /// add after the base and [top], in order, the solid last. [corners]
  /// receives every vertex in the solid's own order, for the edges.
  ({List<GeoObject> created, List<GeoPoint> corners, GeoSolid solid}) build(
    List<GeoPoint> base,
    GeoPoint top,
    GeoPlane? plane,
  );

  @override
  bool get hasPartialInput => _base.isNotEmpty;

  @override
  List<Vec2> get previewPositions => [
    for (final v in _base)
      if (v.isNew) ?v.point.position,
  ];

  @override
  List<String> get previewObjectIds => [
    for (final v in _base)
      if (!v.isNew) v.point.id,
  ];

  @override
  String? takeSelection() {
    final id = _handOver;
    _handOver = null;
    return id;
  }

  @override
  ToolResult onInput(ToolInput input) {
    if (!input.absolute.isEuclidean) {
      return const ToolIgnored();
    }
    return _closed ? _rise(input) : _collect(input);
  }

  ToolResult _collect(ToolInput input) {
    final hit = input.hit;
    // The first corner again closes the base.
    final first = _base.firstOrNull;
    if (first != null &&
        _base.length >= 3 &&
        (identical(hit, first.point) ||
            (first.isNew &&
                hit is! GeoPoint &&
                (first.point.position?.distanceTo(input.position) ??
                        double.infinity) <=
                    input.snapThreshold))) {
      _closed = true;
      return const ToolAccepted();
    }
    final resolved = resolvePoint(input, newId);
    if (_base.any((v) => identical(v.point, resolved.point))) {
      return const ToolIgnored();
    }
    if (!inPlaneOrSheet(resolved.point, input.plane)) {
      return const ToolRefused(ScopeRefusal.notInPlane);
    }
    _base.add(resolved);
    return const ToolAccepted();
  }

  ToolResult _rise(ToolInput input) {
    final base = [for (final v in _base) v.point];
    final hit = input.hit;
    if (hit is GeoPoint && base.any((p) => identical(p, hit))) {
      return const ToolIgnored();
    }
    final plane = input.plane;
    final GeoPoint top;
    final bool topIsNew;
    if (hit is GeoPoint) {
      top = hit;
      topIsNew = false;
    } else {
      final frame = plane == null ? PlaneFrame.base : plane.frame;
      final positions = [for (final p in base) p.spacePosition];
      if (frame == null || positions.any((p) => p == null)) {
        return const ToolIgnored();
      }
      final corners = positions.cast<Vec3>();
      var mean = Vec2.zero;
      var perimeter = 0.0;
      for (var i = 0; i < corners.length; i++) {
        mean += frame.pull(corners[i]);
        perimeter += corners[i].distanceTo(corners[(i + 1) % corners.length]);
      }
      top = newTop(
        base,
        plane,
        mean / corners.length.toDouble(),
        input.viewerSide * perimeter / corners.length,
      );
      topIsNew = true;
    }
    final built = build(base, top, plane);
    final existing = input.objects.toList();
    final edges = <Segment>[];
    for (final (i, j) in built.solid.edges) {
      final p = built.corners[i];
      final q = built.corners[j];
      if (!hasSegment([...existing, ...edges], p, q)) {
        edges.add(Segment(id: newId(), point1: p, point2: q));
      }
    }
    final command = MacroCommand([
      for (final v in _base)
        if (v.isNew) AddObjectCommand(v.point),
      if (topIsNew) AddObjectCommand(top),
      for (final object in built.created)
        if (!identical(object, built.solid)) AddObjectCommand(object),
      for (final edge in edges) AddObjectCommand(edge),
      AddObjectCommand(built.solid),
    ]);
    reset();
    _handOver = topIsNew ? top.id : null;
    return ToolCommitted(command);
  }

  @override
  void reset() {
    _base.clear();
    _closed = false;
    _handOver = null;
  }
}

/// Whether [objects] already holds the segment between [p] and [q], in
/// either order.
bool hasSegment(Iterable<GeoObject> objects, GeoPoint p, GeoPoint q) =>
    objects.any(
      (o) =>
          o is Segment &&
          ((identical(o.point1, p) && identical(o.point2, q)) ||
              (identical(o.point1, q) && identical(o.point2, p))),
    );

/// Pyramid: a base polygon and an apex. A new apex is a free point
/// lifted over the middle of the base — an apex is a corner in its own
/// right, and goes where it is dragged.
class PyramidTool extends SolidTool {
  PyramidTool({required super.newId});

  @override
  GeoPoint newTop(
    List<GeoPoint> base,
    GeoPlane? plane,
    Vec2 mean,
    double height,
  ) => FreePoint(id: newId(), position: mean, height: height, plane: plane);

  @override
  ({List<GeoObject> created, List<GeoPoint> corners, GeoSolid solid}) build(
    List<GeoPoint> base,
    GeoPoint top,
    GeoPlane? plane,
  ) {
    final solid = Pyramid(id: newId(), base: base, apex: top, plane: plane);
    return (created: [solid], corners: [...base, top], solid: solid);
  }
}

/// Prism: a base polygon and the point over its first corner. A new one
/// is a `RaisedPoint`, so the prism is right and stays right as its base
/// is dragged; an existing point gives the oblique prism to it. The
/// other corners of the far end are translations of the base.
class PrismTool extends SolidTool {
  PrismTool({required super.newId});

  @override
  GeoPoint newTop(
    List<GeoPoint> base,
    GeoPlane? plane,
    Vec2 mean,
    double height,
  ) => RaisedPoint(id: newId(), foot: base.first, height: height, plane: plane);

  @override
  ({List<GeoObject> created, List<GeoPoint> corners, GeoSolid solid}) build(
    List<GeoPoint> base,
    GeoPoint top,
    GeoPlane? plane,
  ) {
    final far = <GeoPoint>[
      top,
      for (final corner in base.skip(1))
        TranslatedPoint(
          id: newId(),
          point: corner,
          vectorFrom: base.first,
          vectorTo: top,
        ),
    ];
    final solid = Prism(id: newId(), base: base, top: top, plane: plane);
    return (
      created: [...far.skip(1), solid],
      corners: [...base, ...far],
      solid: solid,
    );
  }
}
