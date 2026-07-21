import '../construction/geo_object.dart';
import '../construction/object_attributes.dart';
import '../construction/objects/midpoint.dart';
import '../construction/objects/perpendicular_line.dart';
import '../construction/objects/segment.dart';
import 'mirror_point_scaffolding.dart';
import 'multi_point_tool.dart';

/// Three taps make an isosceles trapezium (a.k.a. equilateral
/// trapezium): the tapped points are the base corners A, B and the top
/// corner C adjacent to B. The last corner D is C *mirrored across the
/// perpendicular bisector of AB* (hidden midpoint + axis +
/// [mirrorPointAcross] scaffolding), which yields |AD| = |BC| and
/// DC ∥ AB in one stroke — the shape stays an isosceles trapezium under
/// every drag, and C crossing the axis just swaps which base is longer.
///
/// Coincident A, B leave the axis undefined and D with it; both recover
/// when the corners separate. A C tapped on A's side of the axis mirrors
/// D onto B's side and the quad folds over itself — tap order, like the
/// other macros'.
class IsoscelesTrapeziumMacroTool extends MultiPointTool {
  IsoscelesTrapeziumMacroTool({required super.newId});

  @override
  int get pointCount => 3;

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) {
    final a = points[0];
    final b = points[1];
    final c = points[2];
    const hidden = ObjectAttributes(visible: false);

    final sideAB = Segment(id: newId(), point1: a, point2: b);
    final sideBC = Segment(id: newId(), point1: b, point2: c);
    final baseMidpoint = Midpoint(
      id: newId(),
      point1: a,
      point2: b,
      attributes: hidden,
    );
    final axis = PerpendicularLine(
      id: newId(),
      through: baseMidpoint,
      reference: sideAB,
      attributes: hidden,
    );
    final (:scaffolding, mirrored: cornerD) = mirrorPointAcross(
      point: c,
      axis: axis,
      newId: newId,
    );
    final corner = dedupedDerivedPoint(cornerD);

    return [
      sideAB,
      sideBC,
      if (identical(corner, cornerD)) ...[
        baseMidpoint,
        axis,
        ...scaffolding,
        cornerD,
      ],
      Segment(id: newId(), point1: c, point2: corner),
      Segment(id: newId(), point1: corner, point2: a),
    ];
  }
}
