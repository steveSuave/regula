import 'dart:math' as math;
import 'dart:ui';

/// Screen radius (px) above which circle and arc carriers are drawn as
/// sampled polyline paths instead of `drawCircle` / `drawArc`.
///
/// Mobile GPU backends (Impeller in particular, and fp16 shader paths on
/// some Android GPUs) silently drop circle/oval primitives once the
/// radius grows to thousands of pixels, so a big circle vanishes at high
/// zoom even while its rim crosses the screen. Straight segments with
/// far-away endpoints render fine (the infinite-line strategy relies on
/// that), so the fallback keeps every vertex near the viewport and lets
/// the canvas clip do the rest. At this threshold the polyline's sagitta
/// error stays under [maxSagitta], far below a pixel.
const double largeRadiusThreshold = 2048.0;

/// Largest allowed deviation (px) between a sampled chord and the true
/// arc — chooses the chord length in [addSampledArc].
const double maxSagitta = 0.05;

/// Upper bound on segments per sampled arc, so a full turn of an
/// extremely large circle can't build an absurd path. Only reachable
/// when most of the rim is on screen, where the resulting coarser
/// sagitta is still invisible relative to the radius.
const int maxArcSegments = 4096;

/// The angular window (screen angles, y-down) of the circle around
/// [center] with [radius] whose rim can intersect the canvas [size]
/// padded by [margin] px, or null when the rim misses the canvas
/// entirely (the circle wholly off screen — or the viewport strictly
/// inside the disc, where a stroke draws nothing).
///
/// `halfWidth == pi` means the full circle: the canvas surrounds or
/// straddles the center, so no direction can be ruled out. Otherwise the
/// window is the cone from the center tangent to the canvas's bounding
/// circle — every canvas point, rim or interior, lies within it.
({double center, double halfWidth})? visibleAngularWindow({
  required Offset center,
  required double radius,
  required Size size,
  required double margin,
}) {
  final viewCenter = size.center(Offset.zero);
  final toView = viewCenter - center;
  final dist = toView.distance;
  // Half-diagonal of the canvas, padded: the canvas's bounding circle.
  final reach = viewCenter.distance + margin;
  if ((dist - radius).abs() > reach) {
    return null;
  }
  if (dist <= reach) {
    return (center: 0, halfWidth: math.pi);
  }
  return (
    center: math.atan2(toView.dy, toView.dx),
    halfWidth: math.asin(reach / dist),
  );
}

/// The pieces of the arc from [start] through a signed [sweep] (screen
/// angles) that fall inside [window], as increasing `(start, end)`
/// subintervals of the arc's own angle range, ascending and disjoint.
/// Empty when the arc never enters the window. Handles the ±2π
/// wraparound between the atan2-based window and an arbitrarily-phased
/// arc by intersecting against the window's shifted copies.
List<({double start, double end})> arcWindowOverlap({
  required double start,
  required double sweep,
  required ({double center, double halfWidth}) window,
}) {
  final a = sweep >= 0 ? start : start + sweep;
  final b = a + sweep.abs();
  final pieces = <({double start, double end})>[];
  for (var k = -2; k <= 2; k++) {
    final shift = k * 2 * math.pi;
    final lo = window.center - window.halfWidth + shift;
    final hi = window.center + window.halfWidth + shift;
    final s = math.max(a, lo);
    final e = math.min(b, hi);
    if (e - s > 1e-9) {
      pieces.add((start: s, end: e));
    }
  }
  return pieces;
}

/// Appends the arc of the circle around [center] with [radius] from
/// screen angle [start] to [end] (increasing, y-down convention) as a
/// polyline whose sagitta stays below [maxSagitta], capped at
/// [maxArcSegments] segments. Starts a new contour unless
/// [startWithMove] is false, which continues the current one with a
/// straight chord to the arc's first point.
void addSampledArc(
  Path path,
  Offset center,
  double radius,
  double start,
  double end, {
  bool startWithMove = true,
}) {
  final span = end - start;
  final chord = math.sqrt(8 * radius * maxSagitta);
  final segments = (span * radius / chord).ceil().clamp(2, maxArcSegments);
  for (var i = 0; i <= segments; i++) {
    final angle = start + span * i / segments;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    if (i == 0 && startWithMove) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
}
