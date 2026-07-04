import '../construction/geo_object.dart';
import '../construction/object_attributes.dart';
import '../construction/objects/midpoint.dart';
import '../construction/objects/perpendicular_line.dart';
import '../construction/objects/point_on_object.dart';
import '../construction/objects/segment.dart';
import '../math/vec2.dart';
import 'multi_point_tool.dart';
import 'tool.dart';

/// Three taps make an isosceles triangle: the first two are the base
/// corners A, B; the third is *position-only* and places the apex C as
/// the tap projected onto the hidden perpendicular bisector of AB
/// (hidden `Midpoint` + hidden `PerpendicularLine` referencing the
/// visible base), so |CA| ≡ |CB| by construction under any drag.
///
/// Like the rectangle's height tap, the third input projects an existing
/// point's location but never consumes the object — C must stay
/// constrained to the bisector. C is a `PointOnObject` and inherits its
/// analytic-parameter caveat (see that class).
///
/// While A and B coincide the bisector has no geometry to project onto —
/// C falls back to parameter 0 and recovers when the corners separate.
class IsoscelesTriangleMacroTool extends MultiPointTool {
  IsoscelesTriangleMacroTool({required super.newId});

  /// The tapped base corners; the position-only third input is not a
  /// collected vertex.
  @override
  int get pointCount => 2;

  /// The third tap, alive only inside the commit turn.
  Vec2? _apexTarget;

  @override
  ToolResult onInput(ToolInput input) {
    if (collectedVertices.length < pointCount) {
      return collectVertex(input) == null
          ? const ToolIgnored()
          : const ToolAccepted();
    }
    _apexTarget = input.position;
    final result = commitCollected();
    _apexTarget = null;
    return result;
  }

  @override
  void reset() {
    _apexTarget = null;
    super.reset();
  }

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) {
    final a = points[0];
    final b = points[1];
    const hidden = ObjectAttributes(visible: false);

    final base = Segment(id: newId(), point1: a, point2: b);
    final mid = Midpoint(id: newId(), point1: a, point2: b, attributes: hidden);
    final bisector = PerpendicularLine(
      id: newId(),
      through: mid,
      reference: base,
      attributes: hidden,
    );
    final apex = bisector.line == null
        ? PointOnObject(id: newId(), curve: bisector, parameter: 0)
        : PointOnObject.near(
            id: newId(),
            curve: bisector,
            position: _apexTarget!,
          );

    return [
      base,
      mid,
      bisector,
      apex,
      Segment(id: newId(), point1: a, point2: apex),
      Segment(id: newId(), point1: b, point2: apex),
    ];
  }
}
