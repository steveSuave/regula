import '../../projective/absolute.dart';
import '../../projective/space/plane3.dart';
import '../../projective/space/plane_frame.dart';
import '../../projective/space/space_metric.dart';
import '../geo_object.dart';

/// The plane through a point, perpendicular to a line.
///
/// The frame has its origin at [through], its normal along the line and
/// a horizontal `u` (`PlaneFrame.horizontal`): a normal alone names no
/// direction in its plane, so the level one is taken. Undefined only
/// when a parent is.
class PerpendicularPlane extends GeoPlane {
  PerpendicularPlane({
    required super.id,
    required this.through,
    required this.line,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint through;
  final GeoLine line;

  Plane3? _plane;
  PlaneFrame? _frame;

  @override
  Plane3? get spacePlane => _plane;

  @override
  PlaneFrame? get frame => _frame;

  @override
  List<GeoObject> get parents => [through, line];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final p = through.spacePoint;
    final l = line.spaceLine;
    if (p == null || l == null) {
      _plane = null;
      _frame = null;
      return;
    }
    final plane = perpendicularPlaneToLine(p, l);
    _plane = plane.isZero ? null : plane;
    final at = through.spacePosition;
    _frame = _plane == null || at == null
        ? null
        : PlaneFrame.horizontal(at, l.direction);
  }
}
