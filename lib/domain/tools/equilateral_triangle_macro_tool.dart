import 'dart:math' as math;

import '../construction/geo_object.dart';
import '../construction/objects/rotated_point.dart';
import '../construction/objects/segment.dart';
import 'multi_point_tool.dart';

/// Two taps make an equilateral triangle: the tapped corners A, B are one
/// side, and the apex C is B rotated about A by +60° — a plain
/// `RotatedPoint`, so there is no hidden scaffolding and no intersection
/// branch to pick. The triangle lies to the *left* of A→B (tap order
/// picks the side) and follows drags continuously.
class EquilateralTriangleMacroTool extends MultiPointTool {
  EquilateralTriangleMacroTool({required super.newId});

  @override
  int get pointCount => 2;

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) {
    final a = points[0];
    final b = points[1];
    final apex = RotatedPoint(
      id: newId(),
      point: b,
      center: a,
      angle: math.pi / 3,
    );
    return [
      apex,
      Segment(id: newId(), point1: a, point2: b),
      Segment(id: newId(), point1: b, point2: apex),
      Segment(id: newId(), point1: apex, point2: a),
    ];
  }
}
