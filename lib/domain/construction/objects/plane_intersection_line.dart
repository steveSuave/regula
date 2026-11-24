import '../../math/line_eq.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_line.dart';
import '../../projective/space/line3.dart';
import '../../projective/space/plane_frame.dart';
import '../geo_object.dart';

/// The line two planes share.
///
/// A line of space with no sheet. The meet is total: parallel planes
/// share a line at infinity, which is a value and draws nothing; one
/// plane taken twice shares everything, which is the zero sextuple and no
/// line at all.
class PlaneIntersectionLine extends GeoLine {
  PlaneIntersectionLine({
    required super.id,
    required this.plane1,
    required this.plane2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPlane plane1;
  final GeoPlane plane2;

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
  List<GeoObject> get parents => [plane1, plane2];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final a = plane1.spacePlane;
    final b = plane2.spacePlane;
    if (a == null || b == null) {
      _line = null;
      return;
    }
    final l = a.meet(b);
    _line = l.isZero ? null : l;
  }
}
