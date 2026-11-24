import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_point.dart';
import '../../projective/space/point3.dart';
import '../geo_object.dart';

/// A user-placed point — the only directly mutable object in the graph.
///
/// Everything else derives from free points; dragging one and recomputing
/// its transitive dependents is the app's core interaction.
///
/// Migrated (Phase 107): stores a [ProjPoint]. Ordinary mutation stores
/// real finite lifts (`[x, y, 1]` with `w` exactly one), so
/// [chartPosition] reads the chart coordinates back exactly — total at
/// any magnitude — and a free point is always defined. The one exception
/// is a tracing pass's complex detour (Phase 115, [tracedPosition]),
/// which holds a complex position strictly *inside* one
/// `recomputeAlongPath` call: every pass ends back on a real parameter
/// (bitwise-real coordinates), so nothing outside the pass ever observes
/// a complex free point.
///
/// **A free point can be lifted off its sheet** (intent 004): it has a
/// [height] along the sheet's normal, 0 by default. While the height is
/// not exactly 0 the point has no value in its sheet — [projPoint] and
/// [position] are null, so every plane-bound construction on it is
/// undefined rather than drawn at its foot — and it has a
/// [spacePosition]. This is the fourth sanctioned exception on
/// `GeoObject`: the test is exact, so only a height of exactly 0 is in
/// the plane, and it is the lift gesture's snap that returns a point
/// there.
class FreePoint extends GeoPoint {
  FreePoint({
    required super.id,
    required Vec2 position,
    this.height = 0,
    super.attributes,
  }) : _projPoint = ProjPoint.lift(position);

  ProjPoint _projPoint;

  /// The stored coordinates in the sheet: where the point is when
  /// [height] is 0, and its foot on the sheet otherwise. What a drag
  /// sets and the save format stores.
  Vec2 get chartPosition => Vec2(_projPoint.x.re, _projPoint.y.re);

  /// Mutated only by `Construction.moveFreePoint` (via commands) so every
  /// move goes through dependent recomputation.
  set chartPosition(Vec2 value) => _projPoint = ProjPoint.lift(value);

  /// The height above the sheet along its normal. Mutated only by
  /// `Construction.setFreePointHeight`.
  double height;

  /// Whether the point is off its sheet. Exact.
  bool get isLifted => height != 0;

  @override
  ProjPoint? get projPoint => isLifted ? null : _projPoint;

  @override
  Vec2? get position => isLifted ? null : chartPosition;

  @override
  Point3? get spacePoint {
    if (!isLifted) {
      return super.spacePoint;
    }
    final p = spacePosition;
    return p == null ? null : Point3.lift(p);
  }

  @override
  Vec3? get spacePosition {
    // A complex detour leaves the chart; there is no real position then.
    if (_projPoint.x.im != 0 || _projPoint.y.im != 0) {
      return null;
    }
    return sheetFrame?.lift(chartPosition, height);
  }

  /// The complex-detour mutation (Phase 115): stores a generally complex
  /// homogeneous position while a tracing pass walks the drag parameter
  /// off the real axis. Only `Construction.recomputeAlongPath` may call
  /// this, with `DragPath.evaluate`'s shape (`w` exactly one, so
  /// [chartPosition]'s real-part read stays chart-consistent), and it
  /// must leave the point real before the pass returns or throws.
  set tracedPosition(ProjPoint value) => _projPoint = value;

  /// The stored homogeneous value whatever the height: what a tracing
  /// pass saves and restores.
  ProjPoint get storedPoint => _projPoint;

  @override
  List<GeoObject> get parents => const [];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    // Free points are roots: nothing to derive.
  }
}
