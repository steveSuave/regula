import '../construction/geo_object.dart';
import '../construction/object_attributes.dart';
import '../construction/objects/intersection_point.dart';
import '../construction/objects/perpendicular_line.dart';
import '../construction/objects/segment_ratio_point.dart';

/// [mirrorPointAcross]'s result: the hidden helper objects and the
/// visible mirror image, all pairwise distinct. Append `scaffolding`
/// then `mirrored` to a macro's build list — the list is already in
/// dependency order.
typedef MirroredPoint = ({List<GeoObject> scaffolding, GeoPoint mirrored});

/// Reflects [point] across [axis] using only existing object kinds: the
/// hidden perpendicular through [point], its (single-branch, line∩line)
/// foot on the axis, and a `SegmentRatioPoint` at ratio 2 — the exact
/// mirror image `2·foot − point`.
///
/// Deliberately *not* built from circle intersections: a circle branch
/// index is fixed at creation, and the two candidates swap sides when
/// the mirrored point is dragged across the axis — this construction is
/// single-valued and continuous under every drag. While the axis is
/// undefined (degenerate parents) the whole chain is undefined and
/// recovers with it; a point *on* the axis mirrors onto itself.
MirroredPoint mirrorPointAcross({
  required GeoPoint point,
  required GeoLine axis,
  required String Function() newId,
}) {
  const hidden = ObjectAttributes(visible: false);
  final perpendicular = PerpendicularLine(
    id: newId(),
    through: point,
    reference: axis,
    attributes: hidden,
  );
  final foot = IntersectionPoint(
    id: newId(),
    curve1: perpendicular,
    curve2: axis,
    branchIndex: 0,
    attributes: hidden,
  );
  final mirrored = SegmentRatioPoint(
    id: newId(),
    point1: point,
    point2: foot,
    ratio: 2,
  );
  return (scaffolding: [perpendicular, foot], mirrored: mirrored);
}
