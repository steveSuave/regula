import '../../math/angle_geometry.dart';
import '../../math/circle_eq.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';

/// The circular sector (pie wedge) around [center]: [start] fixes the
/// radius and the start angle, [end] fixes only the end angle — its
/// distance from the center is irrelevant. The wedge opens
/// counter-clockwise from start to end.
///
/// A [GeoCircle] via its carrier [circle], like `Arc`. Undefined while
/// [start] or [end] coincides with [center] (no direction → no angle) or
/// a parent is undefined; recovers when the degeneracy passes.
///
/// Painter and hit tester must use [startAngle]/[sweep] and the two rim
/// points — the carrier alone is the full circle.
class Sector extends GeoCircle {
  Sector({
    required super.id,
    required this.center,
    required this.start,
    required this.end,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint center;
  final GeoPoint start;
  final GeoPoint end;

  CircleEq? _circle;
  double? _startAngle;
  double? _sweep;

  @override
  CircleEq? get circle => _circle;

  /// Carrier angle of [start]; null while undefined.
  double? get startAngle => _startAngle;

  /// Counter-clockwise sweep from [startAngle] to [end]'s carrier angle,
  /// in [0, 2π). Null while undefined.
  double? get sweep => _sweep;

  /// Where the wedge's first straight edge meets the carrier — [start]'s
  /// position. Null while undefined.
  Vec2? get startRim => isDefined ? start.position : null;

  /// Where the wedge's second straight edge meets the carrier — [end]
  /// projected radially onto the circle. Null while undefined.
  Vec2? get endRim {
    final circle = _circle;
    final startAngle = _startAngle;
    final sweep = _sweep;
    if (circle == null || startAngle == null || sweep == null) {
      return null;
    }
    return circle.pointAt(startAngle + sweep);
  }

  /// The wedge's arc as a counter-clockwise span from [startAngle].
  @override
  (double, double)? get angularExtent {
    final startAngle = _startAngle;
    final sweep = _sweep;
    return (startAngle == null || sweep == null) ? null : (startAngle, sweep);
  }

  /// Whether the carrier point at [angle] lies on the wedge's arc
  /// (endpoints included). False while undefined.
  bool containsAngle(double angle) {
    final startAngle = _startAngle;
    final sweep = _sweep;
    if (startAngle == null || sweep == null) {
      return false;
    }
    return ccwSweep(startAngle, angle) <= sweep;
  }

  @override
  List<GeoObject> get parents => [center, start, end];

  @override
  void recompute() {
    final c = center.position;
    final s = start.position;
    final e = end.position;
    if (c == null || s == null || e == null || s == c || e == c) {
      _circle = null;
      _startAngle = null;
      _sweep = null;
      return;
    }
    final circle = CircleEq.centerAndPoint(c, s);
    _circle = circle;
    final startAngle = circle.angleAt(s);
    _startAngle = startAngle;
    _sweep = ccwSweep(startAngle, circle.angleAt(e));
  }
}
