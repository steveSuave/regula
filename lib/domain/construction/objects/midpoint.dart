import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../../projective/metric.dart';
import '../../projective/proj_point.dart';
import '../../projective/space/point3.dart';
import '../../projective/space/space_metric.dart';
import '../geo_object.dart';

/// The midpoint of two points.
///
/// Defined whenever both parents are defined — coincident parents just
/// give the shared position.
///
/// Migrated (Phase 107): [midpointOf] on the parents' projective views.
/// A parent at infinity yields that point at infinity (the affine limit),
/// marked as such: [projPoint] real, [position] null.
class Midpoint extends GeoPoint {
  Midpoint({
    required super.id,
    required this.point1,
    required this.point2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;

  ProjPoint? _point;

  @override
  ProjPoint? get projPoint => _point;

  @override
  Vec2? get position => _point?.toVec2();

  bool get _offSheet =>
      !sheet.exists || point1.projPoint == null || point2.projPoint == null;

  /// A midpoint needs no plane (intent 004): when the two points have
  /// no common value in the sheet, it is their midpoint in space.
  @override
  Point3? get spacePoint {
    if (!_offSheet) {
      return super.spacePoint;
    }
    final p1 = point1.spacePoint;
    final p2 = point2.spacePoint;
    if (p1 == null || p2 == null) {
      return null;
    }
    final m = midpoint3(p1, p2);
    return m.isZero ? null : m;
  }

  @override
  Vec3? get spacePosition =>
      _offSheet ? spacePoint?.toVec3() : super.spacePosition;

  @override
  List<GeoObject> get parents => [point1, point2];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final p1 = point1.projPoint;
    final p2 = point2.projPoint;
    if (p1 == null || p2 == null || !sheet.exists) {
      _point = null;
      return;
    }
    final m = midpointOf(p1, p2, absolute);
    _point = m.isZero ? null : m.wPositive;
  }
}
