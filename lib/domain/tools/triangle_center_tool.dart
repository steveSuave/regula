import '../construction/geo_object.dart';
import '../construction/objects/triangle_center_point.dart';
import 'multi_point_tool.dart';

/// Signature shared by the four triangle-center constructors — pass a
/// tear-off (`Centroid.new`, `Orthocenter.new`, `Incenter.new`,
/// `Circumcenter.new`) to [TriangleCenterTool].
typedef TriangleCenterBuilder = TriangleCenterPoint Function({
  required String id,
  required GeoPoint vertex1,
  required GeoPoint vertex2,
  required GeoPoint vertex3,
});

/// Collects three vertices, then emits one triangle center. Input
/// handling (existing points vs new free points, single undo unit,
/// preview markers) is [MultiPointTool]'s.
class TriangleCenterTool extends MultiPointTool {
  TriangleCenterTool({required super.newId, required this.buildCenter});

  /// Builds the concrete center from the three collected vertices.
  final TriangleCenterBuilder buildCenter;

  @override
  int get pointCount => 3;

  @override
  GeoObject buildObject(List<GeoPoint> points) => buildCenter(
        id: newId(),
        vertex1: points[0],
        vertex2: points[1],
        vertex3: points[2],
      );
}
