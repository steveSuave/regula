import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_point.dart';
import '../../projective/space/plane_frame.dart';
import '../../projective/space/point3.dart';
import '../geo_object.dart';
import '../liftable.dart';

/// The point at a stored [height] over [foot], along the normal of
/// [plane] — the top of a prism pulled up from its base (intent 004,
/// milestone 3).
///
/// It stays over its foot wherever the foot is dragged, which is what
/// keeps a right prism right. Its [height] is a stored real, changed by
/// the lift handle through `Construction.setPointHeight`: with a free
/// point's coordinates and a glued point's parameter, the third number
/// of a construction a gesture sets directly ([Liftable]).
///
/// [plane] is the plane the height is measured over, null for the base
/// plane, as `FreePoint.plane` is. The foot need not be on that plane's
/// sheet: it is any point of space, and the tool that builds this takes
/// one that lies in the plane by construction.
///
/// A point of space: no sheet and no planar value, at any height. At
/// height 0 it coincides with its foot and is still not in the plane's
/// sheet, because being raised is what it is.
class RaisedPoint extends Liftable {
  RaisedPoint({
    required super.id,
    required this.foot,
    required this.height,
    this.plane,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint foot;
  final GeoPlane? plane;

  /// Mutated only by `Construction.setPointHeight`.
  @override
  double height;

  Vec3? _position;

  @override
  PlaneFrame? get liftFrame => switch (plane) {
    null => PlaneFrame.base,
    final plane => plane.frame,
  };

  @override
  Sheet get sheet => Sheet.none;

  @override
  ProjPoint? get projPoint => null;

  @override
  Vec2? get position => null;

  @override
  Vec3? get spacePosition => _position;

  @override
  Point3? get spacePoint => switch (_position) {
    null => null,
    final at => Point3.lift(at),
  };

  @override
  List<GeoObject> get parents => [foot, ?plane];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    _position = raisedOver(foot, liftFrame, height);
  }
}

/// [foot]'s space position moved [height] along [frame]'s normal; null
/// while either is undefined. Shared by the two raised kinds.
Vec3? raisedOver(GeoPoint foot, PlaneFrame? frame, double height) {
  final at = foot.spacePosition;
  if (at == null || frame == null || !height.isFinite) {
    return null;
  }
  return height == 0 ? at : at + frame.normal * height;
}
