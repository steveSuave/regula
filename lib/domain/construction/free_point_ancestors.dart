import 'geo_object.dart';
import 'objects/free_point.dart';

/// The [FreePoint] roots that [object] transitively derives from — the
/// set a rigid drag of the object must translate. A free point is its own
/// singleton ancestor set; shared ancestors (a diamond in the DAG) appear
/// once.
Set<FreePoint> freePointAncestors(GeoObject object) {
  final result = <FreePoint>{};
  final seen = <String>{};
  void visit(GeoObject current) {
    if (!seen.add(current.id)) {
      return;
    }
    if (current is FreePoint) {
      result.add(current);
    } else {
      current.parents.forEach(visit);
    }
  }

  visit(object);
  return result;
}
