import '../../math/angle_geometry.dart';
import '../../math/intersections.dart';
import '../geo_object.dart';

/// The angle between two lines, marked at their intersection.
///
/// Lines have no orientation, so this is always the acute (or right)
/// angle, in (0, π/2]. Undefined while the carriers are parallel — there
/// is no vertex to mark and the measure would be 0 — or a parent is
/// undefined. Segments and rays work as parents through their carriers,
/// so the marked vertex can sit outside their drawn extent, matching
/// `IntersectionPoint`'s deferred-clipping caveat.
class LineAngle extends GeoAngle {
  LineAngle({
    required super.id,
    required this.line1,
    required this.line2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoLine line1;
  final GeoLine line2;

  AngleGeometry? _angle;

  @override
  AngleGeometry? get angle => _angle;

  @override
  List<GeoObject> get parents => [line1, line2];

  @override
  void recompute() {
    final l1 = line1.line;
    final l2 = line2.line;
    if (l1 == null || l2 == null) {
      _angle = null;
      return;
    }
    final crossing = intersectLineLine(l1, l2);
    _angle = crossing.isEmpty
        ? null
        : AngleGeometry.betweenLines(
            crossing.single,
            l1.direction,
            l2.direction,
          );
  }
}
