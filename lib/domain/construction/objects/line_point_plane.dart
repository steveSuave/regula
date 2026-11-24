import '../../projective/absolute.dart';
import '../../projective/space/plane3.dart';
import '../../projective/space/plane_frame.dart';
import '../geo_object.dart';

/// The plane through a line and a point.
///
/// The frame has its origin at the foot of [point] on [line], `u` along
/// the line and `v` toward the point, so the line is the frame's x-axis
/// and the point sits on its positive y-axis. Undefined exactly when the
/// point lies on the line.
class LinePointPlane extends GeoPlane {
  LinePointPlane({
    required super.id,
    required this.line,
    required this.point,
    super.attributes,
  }) {
    recompute();
  }

  final GeoLine line;
  final GeoPoint point;

  Plane3? _plane;
  PlaneFrame? _frame;

  @override
  Plane3? get spacePlane => _plane;

  @override
  PlaneFrame? get frame => _frame;

  @override
  List<GeoObject> get parents => [line, point];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final l = line.spaceLine;
    final p = point.spacePoint;
    if (l == null || p == null) {
      _plane = null;
      _frame = null;
      return;
    }
    final plane = l.joinPoint(p);
    _plane = plane.isZero ? null : plane;
    final on = l.anchor;
    final along = l.direction.normalizedOrNull;
    final at = point.spacePosition;
    if (_plane == null || on == null || along == null || at == null) {
      _frame = null;
      return;
    }
    final foot = on + along * (at - on).dot(along);
    _frame = PlaneFrame.withAxis(foot, along.cross(at - foot), along);
  }
}
