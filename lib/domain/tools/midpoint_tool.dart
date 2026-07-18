import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/circle_center.dart';
import '../construction/objects/midpoint.dart';
import 'tool.dart';
import 'two_point_tool.dart';

/// GeoGebra's "Midpoint or Center": two point taps build a [Midpoint];
/// a tap whose topmost hit is a circle-valued object (circle, arc,
/// sector) instead emits its [CircleCenter] in one step.
///
/// The circle shortcut only fires while nothing is collected — after a
/// first point, a circle tap resolves through the normal point ladder
/// (gluing the second midpoint parent onto the curve), so the two-point
/// flow is unchanged. A point sitting on the circle still wins the tap:
/// only a circle-topmost hit is taken as "the circle itself".
class MidpointTool extends TwoPointTool {
  MidpointTool({required super.newId}) : super(build: _buildMidpoint);

  static GeoObject _buildMidpoint(String id, GeoPoint a, GeoPoint b) =>
      Midpoint(id: id, point1: a, point2: b);

  @override
  ToolResult onInput(ToolInput input) {
    final hit = input.hit;
    if (collectedVertices.isEmpty && hit is GeoCircle) {
      return ToolCommitted(
        AddObjectCommand(CircleCenter(id: newId(), circle: hit)),
      );
    }
    return super.onInput(input);
  }
}
