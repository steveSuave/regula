import '../../math/line_eq.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_line.dart';
import '../../projective/space/line3.dart';
import '../../projective/space/plane_frame.dart';
import '../../projective/space/space_metric.dart';
import '../geo_object.dart';

/// The line through a point, perpendicular to a plane: the normal at a
/// foot, the height of a pyramid.
///
/// A line of space with no sheet: it has a [spaceLine] and no planar
/// value. Its direction is the plane's normal, so it is oriented from
/// the plane's negative side to its positive one. Undefined only when a
/// parent is.
class PerpendicularToPlaneLine extends GeoLine {
  PerpendicularToPlaneLine({
    required super.id,
    required this.through,
    required this.plane,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint through;
  final GeoPlane plane;

  Line3? _line;

  @override
  ProjLine? get projLine => null;

  @override
  LineEq? get line => null;

  @override
  PlaneFrame? get sheetFrame => null;

  @override
  Line3? get spaceLine => _line;

  @override
  bool get hasSpaceExtent => _line?.isFinite() ?? false;

  @override
  List<GeoObject> get parents => [through, plane];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final p = through.spacePoint;
    final pi = plane.spacePlane;
    if (p == null || pi == null) {
      _line = null;
      return;
    }
    final l = perpendicularLineToPlane(p, pi);
    _line = l.isZero ? null : l;
  }
}
