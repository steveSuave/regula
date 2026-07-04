import '../construction/geo_object.dart';
import '../construction/object_attributes.dart';
import '../construction/objects/perpendicular_line.dart';
import '../construction/objects/point_on_object.dart';
import '../construction/objects/segment.dart';
import '../math/vec2.dart';
import 'multi_point_tool.dart';
import 'tool.dart';

/// Three taps make a right triangle: the first two are the base corners
/// A, B with the right angle at B; the third is *position-only* and
/// places C as the tap projected onto the hidden perpendicular to AB
/// through B — the rectangle's height-tap mechanics. Legs AB and BC,
/// hypotenuse CA; the right angle holds under any drag by construction.
///
/// The third input projects an existing point's location but never
/// consumes the object — C must stay constrained to the perpendicular.
/// C is a `PointOnObject` and inherits its analytic-parameter caveat
/// (see that class).
///
/// While A and B coincide the perpendicular has no geometry to project
/// onto — C falls back to parameter 0 and recovers when the corners
/// separate.
class RightTriangleMacroTool extends MultiPointTool {
  RightTriangleMacroTool({required super.newId});

  /// The tapped base corners; the position-only third input is not a
  /// collected vertex.
  @override
  int get pointCount => 2;

  /// The third tap, alive only inside the commit turn.
  Vec2? _cTarget;

  @override
  ToolResult onInput(ToolInput input) {
    if (collectedVertices.length < pointCount) {
      return collectVertex(input) == null
          ? const ToolIgnored()
          : const ToolAccepted();
    }
    _cTarget = input.position;
    final result = commitCollected();
    _cTarget = null;
    return result;
  }

  @override
  void reset() {
    _cTarget = null;
    super.reset();
  }

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) {
    final a = points[0];
    final b = points[1];
    const hidden = ObjectAttributes(visible: false);

    final base = Segment(id: newId(), point1: a, point2: b);
    final perpendicularB = PerpendicularLine(
      id: newId(),
      through: b,
      reference: base,
      attributes: hidden,
    );
    final cornerC = perpendicularB.line == null
        ? PointOnObject(id: newId(), curve: perpendicularB, parameter: 0)
        : PointOnObject.near(
            id: newId(),
            curve: perpendicularB,
            position: _cTarget!,
          );

    return [
      base,
      perpendicularB,
      cornerC,
      Segment(id: newId(), point1: b, point2: cornerC),
      Segment(id: newId(), point1: cornerC, point2: a),
    ];
  }
}
