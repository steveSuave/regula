import '../../math/angle_geometry.dart';
import '../../math/circle_eq.dart';
import '../../math/triangle_centers.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';

/// The circular arc from [start] to [end] passing through [via].
///
/// A [GeoCircle] via its carrier [circle] (the three points' circumcircle),
/// so arcs participate in intersections like full circles do — clipping
/// intersection points to the arc's extent is deferred, matching `Segment`
/// and `Ray`. Undefined while the points are collinear (including any two
/// coincident); recovers when a drag breaks the degeneracy.
///
/// The drawn extent is [startAngle] plus the signed [sweep]: whichever
/// branch of the carrier contains [via]. Painter and hit tester must use
/// those — the carrier alone is the full circle.
class Arc extends GeoCircle {
  Arc({
    required super.id,
    required this.start,
    required this.via,
    required this.end,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint start;
  final GeoPoint via;
  final GeoPoint end;

  CircleEq? _circle;
  double? _startAngle;
  double? _sweep;

  @override
  CircleEq? get circle => _circle;

  /// Carrier angle of [start]; null while undefined.
  double? get startAngle => _startAngle;

  /// Signed sweep from [startAngle] to [end]'s carrier angle, positive
  /// counter-clockwise — the branch containing [via]. Null while undefined.
  double? get sweep => _sweep;

  /// The arc's endpoints; null while the parent point is undefined.
  Vec2? get startPosition => start.position;
  Vec2? get endPosition => end.position;

  /// The drawn branch as a counter-clockwise span: a negative [sweep]
  /// walks back from [startAngle], so the span starts at the far endpoint.
  @override
  (double, double)? get angularExtent {
    final startAngle = _startAngle;
    final sweep = _sweep;
    if (startAngle == null || sweep == null) {
      return null;
    }
    return sweep >= 0 ? (startAngle, sweep) : (startAngle + sweep, -sweep);
  }

  /// Whether the carrier point at [angle] lies on the arc (endpoints
  /// included). False while undefined.
  bool containsAngle(double angle) {
    final startAngle = _startAngle;
    final sweep = _sweep;
    if (startAngle == null || sweep == null) {
      return false;
    }
    return sweep >= 0
        ? ccwSweep(startAngle, angle) <= sweep
        : ccwSweep(angle, startAngle) <= -sweep;
  }

  @override
  List<GeoObject> get parents => [start, via, end];

  @override
  void recompute() {
    final s = start.position;
    final v = via.position;
    final e = end.position;
    final center =
        (s == null || v == null || e == null) ? null : circumcenter(s, v, e);
    if (s == null || v == null || e == null || center == null) {
      _circle = null;
      _startAngle = null;
      _sweep = null;
      return;
    }
    final circle = CircleEq.centerAndPoint(center, s);
    _circle = circle;
    final startAngle = circle.angleAt(s);
    _startAngle = startAngle;
    _sweep = sweepThrough(startAngle, circle.angleAt(v), circle.angleAt(e));
  }
}
