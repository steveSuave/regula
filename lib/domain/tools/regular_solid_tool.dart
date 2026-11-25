import 'dart:math' as math;

import '../construction/geo_object.dart';
import '../construction/object_attributes.dart';
import '../construction/objects/centroid.dart';
import '../construction/objects/prism.dart';
import '../construction/objects/proportional_raised_point.dart';
import '../construction/objects/pyramid.dart';
import '../construction/objects/rotated_point.dart';
import '../construction/objects/segment.dart';
import '../construction/objects/translated_point.dart';
import '../projective/absolute.dart';
import 'multi_point_tool.dart';
import 'solid_tool.dart';
import 'tool.dart';

/// A solid fixed by one edge of its base: two taps, in the active plane
/// (intent 004, milestone 3). The shared shape of [CubeTool] and
/// [RegularTetrahedronTool].
///
/// Everything past the two points is derived, so the solid stays what it
/// is under every drag: the base by rotations in the plane, the height
/// as a multiple of the edge (`ProportionalRaisedPoint`). It rises on
/// the viewer's side of the plane.
///
/// A planar tool: its two points are on the active plane's sheet, or
/// reach it through adapters when they lie in the plane by construction.
abstract class RegularSolidTool extends MultiPointTool {
  RegularSolidTool({required super.newId});

  GeoPlane? _plane;
  double _side = 1;

  /// The active plane the solid stands on; null is the base plane.
  GeoPlane? get plane => _plane;

  /// +1 or −1: the side of the plane the solid rises on.
  double get side => _side;

  @override
  int get pointCount => 2;

  @override
  bool availableUnder(Absolute absolute) => absolute.isEuclidean;

  @override
  ToolResult onInput(ToolInput input) {
    _plane = input.plane;
    _side = input.viewerSide;
    return super.onInput(input);
  }

  /// One segment per edge of [solid] over [corners], skipping those the
  /// construction already has.
  List<Segment> edgesOf(GeoSolid solid, List<GeoPoint> corners) {
    final edges = <Segment>[];
    for (final (i, j) in solid.edges) {
      if (!hasSegment(
        [...constructionObjects, ...edges],
        corners[i],
        corners[j],
      )) {
        edges.add(Segment(id: newId(), point1: corners[i], point2: corners[j]));
      }
    }
    return edges;
  }
}

/// Cube: two adjacent corners of its base.
class CubeTool extends RegularSolidTool {
  CubeTool({required super.newId});

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) {
    final a = points[0];
    final b = points[1];
    // Each of the other two base corners is a quarter turn of one given
    // corner about the other, so neither waits on the other and they
    // are added, and named, in order around the square.
    final c = RotatedPoint(
      id: newId(),
      point: a,
      center: b,
      angle: -math.pi / 2,
    );
    final d = RotatedPoint(
      id: newId(),
      point: b,
      center: a,
      angle: math.pi / 2,
    );
    final base = <GeoPoint>[a, b, c, d];
    final top = ProportionalRaisedPoint(
      id: newId(),
      foot: a,
      from: a,
      to: b,
      factor: side,
      plane: plane,
    );
    final far = <GeoPoint>[
      top,
      for (final corner in base.skip(1))
        TranslatedPoint(
          id: newId(),
          point: corner,
          vectorFrom: a,
          vectorTo: top,
        ),
    ];
    final solid = Prism(id: newId(), base: base, top: top, plane: plane);
    return [
      c,
      d,
      ...far,
      ...edgesOf(solid, [...base, ...far]),
      solid,
    ];
  }
}

/// Regular tetrahedron: two corners of its base.
class RegularTetrahedronTool extends RegularSolidTool {
  RegularTetrahedronTool({required super.newId});

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) {
    final a = points[0];
    final b = points[1];
    final c = RotatedPoint(
      id: newId(),
      point: b,
      center: a,
      angle: math.pi / 3,
    );
    final centre = Centroid(
      id: newId(),
      vertex1: a,
      vertex2: b,
      vertex3: c,
      attributes: const ObjectAttributes(visible: false),
    );
    final apex = ProportionalRaisedPoint(
      id: newId(),
      foot: centre,
      from: a,
      to: b,
      factor: side * math.sqrt(2 / 3),
      plane: plane,
    );
    final solid = Pyramid(id: newId(), base: [a, b, c], apex: apex);
    return [
      c,
      centre,
      apex,
      ...edgesOf(solid, [a, b, c, apex]),
      solid,
    ];
  }
}
