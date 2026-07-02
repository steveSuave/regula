import '../../math/triangle_centers.dart' as tc;
import '../../math/vec2.dart';
import 'triangle_center_point.dart';

/// The centroid (intersection of the medians) of three points.
///
/// Defined whenever all parents are — unlike the other triangle centers,
/// collinear or coincident vertices are not degenerate for the centroid.
class Centroid extends TriangleCenterPoint {
  Centroid({
    required super.id,
    required super.vertex1,
    required super.vertex2,
    required super.vertex3,
    super.attributes,
  });

  @override
  Vec2? computeCenter(Vec2 a, Vec2 b, Vec2 c) => tc.centroid(a, b, c);
}
