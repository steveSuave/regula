import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_point.dart';
import '../../projective/space/plane_frame.dart';
import '../../projective/space/point3.dart';
import '../geo_object.dart';

/// The point where a line meets a plane.
///
/// A point of space with no sheet. The meet is total: a line parallel to
/// the plane meets it at a point at infinity, which is a value and has no
/// position; a line lying in the plane meets it everywhere, which is the
/// zero quadruple and no point at all.
class LinePlaneIntersectionPoint extends GeoPoint {
  LinePlaneIntersectionPoint({
    required super.id,
    required this.line,
    required this.plane,
    super.attributes,
  }) {
    recompute();
  }

  final GeoLine line;
  final GeoPlane plane;

  Point3? _point;

  @override
  ProjPoint? get projPoint => null;

  @override
  Vec2? get position => null;

  @override
  PlaneFrame? get sheetFrame => null;

  @override
  Point3? get spacePoint => _point;

  @override
  Vec3? get spacePosition => _point?.toVec3();

  @override
  List<GeoObject> get parents => [line, plane];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final l = line.spaceLine;
    final pi = plane.spacePlane;
    if (l == null || pi == null) {
      _point = null;
      return;
    }
    final p = l.meetPlane(pi);
    _point = p.isZero ? null : p;
  }
}
