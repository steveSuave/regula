import '../construction/geo_object.dart';
import '../construction/objects/rotated_point.dart';
import '../construction/objects/vertex_angle.dart';
import 'multi_point_tool.dart';

/// Collects the arm point, then the vertex, and emits the arm turned
/// about the vertex by the fixed [angle] as a `RotatedPoint`, plus a
/// `VertexAngle` marking the angle between the two arms — GeoGebra's
/// "angle with given size" convention. The size is chosen in a dialog
/// before the tool activates, like the rotation tool's angle.
///
/// A dedicated class for the same reason as `RotatedPointTool`: the
/// toolbar's Angles highlight keys on tool identity, which a closure
/// capturing the angle would defeat.
class AngleBySizeTool extends MultiPointTool {
  AngleBySizeTool({required super.newId, required this.angle});

  /// Angle size in radians; positive lays the new arm counter-clockwise
  /// from the tapped arm, negative clockwise.
  final double angle;

  @override
  int get pointCount => 2;

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) {
    final arm = points[0];
    final vertex = points[1];
    final rotated = RotatedPoint(
      id: newId(),
      point: arm,
      center: vertex,
      angle: angle,
    );
    // VertexAngle sweeps CCW from arm1 to arm2, so a clockwise rotation
    // swaps the arm order — the marker then measures |angle| on the side
    // the new arm landed instead of the 2π complement.
    return [
      rotated,
      if (angle >= 0)
        VertexAngle(id: newId(), arm1: arm, vertex: vertex, arm2: rotated)
      else
        VertexAngle(id: newId(), arm1: rotated, vertex: vertex, arm2: arm),
    ];
  }
}
