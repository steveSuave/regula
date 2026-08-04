import '../construction/geo_object.dart';
import '../construction/objects/harmonic_conjugate_point.dart';
import 'multi_point_tool.dart';

/// Collects the base pair A, B and then C, and emits the fourth harmonic
/// point — the conjugate of C with respect to A and B. Input handling
/// (existing points vs new free points, single undo unit, preview
/// markers) is [MultiPointTool]'s.
///
/// A conjugate over the same parents refuses the completing tap instead
/// of stacking a duplicate — the `TriangleCenterTool` convention, but
/// checked *structurally* (identical parent instances, either base-pair
/// order — the conjugate is symmetric in A and B): the numeric
/// [dedupedDerivedPoint] probe can never confirm this object, because
/// perturbed parents stop being collinear and the candidate goes
/// undefined.
class HarmonicConjugateTool extends MultiPointTool {
  HarmonicConjugateTool({required super.newId});

  @override
  int get pointCount => 3;

  @override
  List<GeoObject> buildObjects(List<GeoPoint> points) {
    final alreadyExists = constructionObjects.any(
      (object) =>
          object is HarmonicConjugatePoint &&
          identical(object.point3, points[2]) &&
          ((identical(object.point1, points[0]) &&
                  identical(object.point2, points[1])) ||
              (identical(object.point1, points[1]) &&
                  identical(object.point2, points[0]))),
    );
    return [
      if (!alreadyExists)
        HarmonicConjugatePoint(
          id: newId(),
          point1: points[0],
          point2: points[1],
          point3: points[2],
        ),
    ];
  }
}
