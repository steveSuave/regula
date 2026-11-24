import '../../math/line_eq.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_line.dart';
import '../../projective/space/line3.dart';
import '../geo_object.dart';

/// The infinite line through two points.
///
/// Migrated (Phase 107): the carrier is the projective join of the
/// parents' homogeneous points. A parent at infinity now yields the real
/// line through the finite parent in that direction (V1: undefined).
/// Undefined while the parents projectively coincide (within
/// `projectiveEpsilon`, the [carrierThrough] convention) or a parent is
/// undefined; comes back when they separate.
class LineThroughTwoPoints extends GeoLine {
  LineThroughTwoPoints({
    required super.id,
    required this.point1,
    required this.point2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;

  ProjLine? _carrier;
  LineEq? _line;

  @override
  ProjLine? get projLine => _carrier;

  @override
  LineEq? get line => _line;

  /// Whether the two points have no common value in the sheet, so the
  /// planar carrier does not exist and the space one stands in. A
  /// planar degeneracy (coincident points) is not this: it stays
  /// undefined, as it always was.
  bool get _offSheet =>
      !sheet.exists || point1.projPoint == null || point2.projPoint == null;

  /// A line through two points needs no plane (intent 004): when the
  /// two have no common value in the sheet, the carrier is their join in
  /// space. With a planar carrier this is its lift, as for any line.
  @override
  Line3? get spaceLine =>
      _offSheet ? spaceCarrierThrough(point1, point2) : super.spaceLine;

  @override
  bool get hasSpaceExtent => _offSheet && (spaceLine?.isFinite() ?? false);

  @override
  List<GeoObject> get parents => [point1, point2];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    _carrier = sheet.exists ? carrierThrough(point1, point2) : null;
    // The join of w-positive representatives runs p1 → p2 by itself
    // (Phase 137): the chart direction of `p1 × p2` is `w₁w₂·(p2 − p1)`.
    _line = _carrier?.toOrientedLineEq();
  }
}

/// Projective carrier through two point objects — the join of their
/// homogeneous points — or null when either parent is undefined or the
/// points projectively coincide (within `projectiveEpsilon`).
///
/// Shared by [LineThroughTwoPoints], `Segment` and `Ray` so all three
/// agree on what "degenerate" means.
/// The space line through two points' space values: the carrier of a
/// two-point line whose points do not both have a value in one sheet
/// (one is lifted off it). Null when either has no real space value or
/// the two coincide — the space sibling of [carrierThrough], with the
/// same coincidence test.
Line3? spaceCarrierThrough(GeoPoint point1, GeoPoint point2) {
  final p1 = point1.spacePoint;
  final p2 = point2.spacePoint;
  if (p1 == null || p2 == null || p1.closeTo(p2)) {
    return null;
  }
  return p1.join(p2);
}

ProjLine? carrierThrough(GeoPoint point1, GeoPoint point2) {
  final p1 = point1.projPoint;
  final p2 = point2.projPoint;
  if (p1 == null || p2 == null || p1.closeTo(p2)) {
    return null;
  }
  return p1.join(p2);
}
