import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_point.dart';
import '../../projective/space/plane_frame.dart';
import '../../projective/space/point3.dart';
import '../geo_object.dart';
import 'raised_point.dart';

/// The point over [foot], along the normal of [plane], at a height that
/// is [factor] times the distance between [from] and [to] (intent 004,
/// milestone 3).
///
/// It is what makes a cube a cube under every drag — the top of a
/// corner stands one edge above it, factor ±1 — and a regular
/// tetrahedron regular: its apex stands √(2/3) of an edge above the
/// centroid of its base. The sign of [factor] says which side of the
/// plane.
///
/// Nothing here is stored but the factor: unlike a `RaisedPoint` it has
/// no height of its own to change, and no lift handle.
class ProportionalRaisedPoint extends GeoPoint {
  ProportionalRaisedPoint({
    required super.id,
    required this.foot,
    required this.from,
    required this.to,
    required this.factor,
    this.plane,
    super.attributes,
  }) {
    if (!factor.isFinite) {
      throw ArgumentError.value(factor, 'factor', 'must be finite');
    }
    recompute();
  }

  final GeoPoint foot;
  final GeoPoint from;
  final GeoPoint to;
  final double factor;
  final GeoPlane? plane;

  Vec3? _position;

  PlaneFrame? get _frame => switch (plane) {
    null => PlaneFrame.base,
    final plane => plane.frame,
  };

  /// The signed height over the plane; null while undefined.
  double? get height {
    final a = from.spacePosition;
    final b = to.spacePosition;
    return a == null || b == null ? null : factor * a.distanceTo(b);
  }

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
  List<GeoObject> get parents => [foot, from, to, ?plane];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final h = height;
    _position = h == null ? null : raisedOver(foot, _frame, h);
  }
}
