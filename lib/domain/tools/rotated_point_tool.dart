import '../construction/geo_object.dart';
import '../construction/objects/rotated_point.dart';
import 'multi_point_tool.dart';

/// Collects the point to rotate, then the center, and emits one
/// `RotatedPoint` turned by the fixed [angle] (chosen in a dialog before
/// the tool activates, like the segment-ratio tool's ratio).
///
/// A dedicated class rather than a `TwoPointTool` closure: the closure
/// would capture the angle and could never be a canonicalized tear-off,
/// so the toolbar's Transform highlight (which keys on builder identity)
/// would misfile it under the Points catch-all.
class RotatedPointTool extends MultiPointTool {
  RotatedPointTool({required super.newId, required this.angle});

  /// Rotation angle in radians, counter-clockwise.
  final double angle;

  @override
  int get pointCount => 2;

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) => [
        RotatedPoint(
          id: newId(),
          point: points[0],
          center: points[1],
          angle: angle,
        ),
      ];
}
