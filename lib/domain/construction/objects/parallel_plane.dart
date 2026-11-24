import '../../projective/absolute.dart';
import '../../projective/space/plane3.dart';
import '../../projective/space/plane_frame.dart';
import '../../projective/space/space_metric.dart';
import '../geo_object.dart';

/// The plane through a point, parallel to a plane.
///
/// The frame is the reference plane's frame moved to [through], so the
/// two planes' coordinates correspond by the translation between them.
/// Undefined only when a parent is.
class ParallelPlane extends GeoPlane {
  ParallelPlane({
    required super.id,
    required this.through,
    required this.reference,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint through;
  final GeoPlane reference;

  Plane3? _plane;
  PlaneFrame? _frame;

  @override
  Plane3? get spacePlane => _plane;

  @override
  PlaneFrame? get frame => _frame;

  @override
  List<GeoObject> get parents => [through, reference];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final p = through.spacePoint;
    final ref = reference.spacePlane;
    if (p == null || ref == null) {
      _plane = null;
      _frame = null;
      return;
    }
    final plane = parallelPlaneThrough(p, ref);
    _plane = plane.isZero ? null : plane;
    final at = through.spacePosition;
    final frame = reference.frame;
    _frame = _plane == null || at == null || frame == null
        ? null
        : PlaneFrame(at, frame.u, frame.v);
  }
}
