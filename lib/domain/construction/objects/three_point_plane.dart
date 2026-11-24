import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../../projective/space/plane3.dart';
import '../../projective/space/plane_frame.dart';
import '../geo_object.dart';

/// The plane through three points.
///
/// The frame has its origin at [point1], `u` along `point1 → point2`
/// and its normal along `(point2 − point1) × (point3 − point1)`, so the
/// three points run counter-clockwise seen from the normal's side, and
/// the plane's coordinates move rigidly with the first two points.
/// Undefined exactly when the three are collinear.
class ThreePointPlane extends GeoPlane {
  ThreePointPlane({
    required super.id,
    required this.point1,
    required this.point2,
    required this.point3,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;
  final GeoPoint point3;

  Plane3? _plane;
  PlaneFrame? _frame;

  @override
  Plane3? get spacePlane => _plane;

  @override
  PlaneFrame? get frame => _frame;

  /// The centroid of the three points: inside the triangle they span,
  /// clear of each point's own label.
  @override
  Vec3? get labelAnchor {
    final a = point1.spacePosition;
    final b = point2.spacePosition;
    final c = point3.spacePosition;
    return a == null || b == null || c == null ? null : (a + b + c) / 3;
  }

  @override
  List<GeoObject> get parents => [point1, point2, point3];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final p = point1.spacePoint;
    final q = point2.spacePoint;
    final r = point3.spacePoint;
    if (p == null || q == null || r == null) {
      _plane = null;
      _frame = null;
      return;
    }
    final plane = Plane3.through(p, q, r);
    _plane = plane.isZero ? null : plane;
    final a = point1.spacePosition;
    final b = point2.spacePosition;
    final c = point3.spacePosition;
    _frame = _plane == null || a == null || b == null || c == null
        ? null
        : PlaneFrame.throughPoints(a, b, c);
  }
}
