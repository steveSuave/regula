import '../math/vec2.dart';
import 'geo_object.dart';
import 'objects/angle_bisector_line.dart';
import 'objects/intersection_point.dart';
import 'objects/line_through_two_points.dart';
import 'objects/midpoint.dart';
import 'objects/perpendicular_bisector_line.dart';
import 'objects/point_on_object.dart';
import 'objects/ray.dart';
import 'objects/relative_line.dart';
import 'objects/segment.dart';
import 'objects/tangent_line.dart';
import 'objects/two_line_bisector_line.dart';

/// The world endpoints of [line]'s drawn stretch under its
/// `attributes.lineClip` mode, or null to draw the full carrier
/// (infinite line, or unclamped ray).
///
/// Clipping is *display and hit-test only*: the carrier stays infinite
/// for intersection math, perpendiculars and `PointOnObject` parameters.
///
/// Modes (`ObjectAttributes.lineClip`):
///
/// - 0 — infinite; always null.
/// - 1 — the segment between the two defining points. Only
///   [LineThroughTwoPoints] has two defining points on its carrier, so
///   every other kind falls back to null (drawn infinite).
/// - 2 — the span of the points *incident* to the line: its on-carrier
///   defining points, `PointOnObject`s hosted on it, and
///   `IntersectionPoint`s having it as a parent. Incidence is structural
///   (construction ties, not epsilon tests) and counts **visible**,
///   defined points only, so hidden macro scaffolding never stretches
///   the clip. Fewer than two incident points — or a degenerate span —
///   fall back to null. A [Ray] keeps its origin end fixed and clamps
///   the far end at the outermost incident point strictly ahead of the
///   origin (points behind are ignored; none ahead → null, unclamped).
///
/// [Segment] is untouched by every mode — it is already its own clip.
/// [objects] must be the construction's objects (any order works; the
/// scan is identity-based). Returns null while [line] is undefined.
({Vec2 start, Vec2 end})? lineClipSpan(
  Iterable<GeoObject> objects,
  GeoLine line,
) {
  final carrier = line.line;
  if (carrier == null || line is Segment) {
    return null;
  }
  switch (line.attributes.lineClip) {
    case 1:
      if (line is! LineThroughTwoPoints) {
        return null;
      }
      // Defined line ⇒ both defining positions exist. Mode 1 is the
      // defining pair regardless of visibility — hiding a defining point
      // does not un-clip the line it defines.
      return (start: line.point1.position!, end: line.point2.position!);
    case 2:
      final incident = _incidentPoints(objects, line);
      if (line is Ray) {
        return _rayClamp(line, incident);
      }
      if (incident.length < 2) {
        return null;
      }
      var min = double.infinity;
      var max = double.negativeInfinity;
      for (final p in incident) {
        final t = carrier.parameterAt(p);
        if (t < min) min = t;
        if (t > max) max = t;
      }
      if (max <= min) {
        return null; // all incident points coincide — no span to draw
      }
      return (start: carrier.pointAt(min), end: carrier.pointAt(max));
    default:
      return null;
  }
}

/// Positions of the visible, defined points structurally incident to
/// [line]: its on-carrier defining points, every `PointOnObject` hosted
/// on it, every `IntersectionPoint` parenting it, and the derived
/// incidences of [_derivedIncident]. The DAG is acyclic and the match
/// arms are disjoint, so no source can yield the same object twice.
List<Vec2> _incidentPoints(Iterable<GeoObject> objects, GeoLine line) {
  final points = <GeoPoint>[..._onCarrierDefiningPoints(line)];
  for (final object in objects) {
    switch (object) {
      case PointOnObject(:final curve) when identical(curve, line):
        points.add(object);
      case IntersectionPoint(:final curve1, :final curve2)
          when identical(curve1, line) || identical(curve2, line):
        points.add(object);
      case GeoPoint() when _derivedIncident(line, object):
        points.add(object);
      default:
        break;
    }
  }
  return [
    for (final p in points)
      if (p.attributes.visible && p.position != null) p.position!,
  ];
}

/// Derived structural incidences (Phase 44b): points provably on [line]
/// by a construction theorem over parent ties — still zero epsilon. A
/// point merely *coinciding* with the carrier in the current figure is
/// deliberately not incident (that would be the epsilon test this
/// design rejects).
///
/// - Every branch of a `TwoLineBisectorLine` passes through the crossing
///   of its two parent lines, so the `IntersectionPoint` of exactly
///   those lines (either parent order) is on it.
/// - A `PerpendicularBisectorLine` passes through the midpoint of its
///   two parent points, so the `Midpoint` of exactly those points
///   (either order) is on it.
bool _derivedIncident(GeoLine line, GeoPoint point) =>
    switch ((line, point)) {
      (final TwoLineBisectorLine b, final IntersectionPoint x) =>
        _samePair(x.curve1, x.curve2, b.line1, b.line2),
      (final PerpendicularBisectorLine b, final Midpoint m) =>
        _samePair(m.point1, m.point2, b.point1, b.point2),
      _ => false,
    };

/// Whether {[a1], [a2]} and {[b1], [b2]} are the same instance pair,
/// order-blind.
bool _samePair(GeoObject a1, GeoObject a2, GeoObject b1, GeoObject b2) =>
    (identical(a1, b1) && identical(a2, b2)) ||
    (identical(a1, b2) && identical(a2, b1));

/// The defining points of [line] that lie on its carrier by construction.
/// Kinds whose defining geometry is elsewhere (perpendicular bisector,
/// two-line bisector) — and unknown future kinds — contribute none;
/// their mode-2 clip is fed by hosted and intersection points alone.
List<GeoPoint> _onCarrierDefiningPoints(GeoLine line) => switch (line) {
      LineThroughTwoPoints() => [line.point1, line.point2],
      Ray() => [line.origin, line.through],
      // Perpendicular and parallel lines pass through their point.
      RelativeLine() => [line.through],
      AngleBisectorLine() => [line.vertex],
      // Both tangent branches pass through the external point.
      TangentLine() => [line.point],
      _ => const [],
    };

/// Ray mode 2: origin end fixed, far end at the outermost incident point
/// strictly ahead of the origin; null (unclamped) when no visible
/// incident point lies ahead.
({Vec2 start, Vec2 end})? _rayClamp(Ray ray, List<Vec2> incident) {
  final origin = ray.start!;
  final direction = ray.throughPosition! - origin;
  Vec2? far;
  var farAlong = 0.0;
  for (final p in incident) {
    final along = (p - origin).dot(direction);
    if (along > farAlong) {
      far = p;
      farAlong = along;
    }
  }
  if (far == null) {
    return null;
  }
  return (start: origin, end: far);
}
