import 'dart:math' as math;
import 'dart:ui';

import '../../domain/construction/geo_object.dart';
import '../../domain/construction/line_clip.dart';
import '../../domain/construction/objects/arc.dart';
import '../../domain/construction/objects/ray.dart';
import '../../domain/construction/objects/sector.dart';
import '../../domain/construction/objects/segment.dart';
import '../../domain/math/vec2.dart';
import '../../domain/math/vec3.dart';
import '../../domain/projective/conic_shape.dart';
import 'canvas_viewport.dart';
import 'label_anchor.dart';

/// Sampling flatness (screen px) of a conic's chord chain. Coarser than
/// the painter's: a label obstacle and a hit target need the ink's
/// *shape*, not its antialiasing — the same reason a circle here is a
/// 12–48-gon.
const double _conicFlatness = 3;

/// Whether a defined [object] is drawn from its space value: it has no
/// value in its sheet (a lifted point, a segment to one), so the planar
/// painter, hit tester and label anchor have nothing to read.
bool drawnInSpace(GeoObject object) => switch (object) {
  GeoPoint() => object.position == null,
  GeoLine() => object.line == null,
  _ => false,
};

/// Where a space-drawn [object] hangs its label, or null when it is not
/// one (see [drawnInSpace]).
Vec3? spaceLabelAnchor(GeoObject object) => switch (object) {
  GeoPoint() => object.spacePosition,
  Segment(:final spaceStart?, :final spaceEnd?) =>
    (spaceStart + spaceEnd) * 0.5,
  Ray() => object.spaceStart,
  GeoLine() => object.spaceLine?.anchor,
  _ => null,
};

/// One object's ink on the screen, as the painter draws it
/// (`GeometryPainter._drawObject`): a [dot] for a point, [segments] for
/// everything stroked (curves as chord runs), a [fill] outline for a
/// region whose interior belongs to the object, and an [anchor] for an
/// object that is only text.
///
/// This is the one place a kind is turned into screen geometry outside
/// the painter. The label declutter builds its obstacles from it and the
/// space view's hit test measures against it (intent 004, milestone 2),
/// so neither has its own idea of where an object is. Later categories —
/// sampled curves and surfaces — arrive as the same primitives.
class ScreenInk {
  Offset? dot;
  final List<(Offset, Offset)> segments = [];
  List<Offset>? fill;
  Offset? anchor;

  /// For a space-drawn object, the camera depth at each end of each of
  /// [segments] and at [dot] (see `CanvasViewport.depthOf`). Null for an
  /// object on a sheet, whose depth under a pointer is the sheet's.
  List<(double, double)>? segmentDepths;
  double? dotDepth;

  /// The nearest ink to [p]: its distance in pixels (infinite when
  /// there is no ink) and the camera depth there, larger for nearer.
  /// [sheetDepth] is the depth of the object's sheet under [p], which is
  /// the answer for any object drawn on it.
  ({double distance, double depth}) nearest(Offset p, double sheetDepth) {
    final region = fill;
    if (region != null && _inside(region, p)) {
      return (distance: 0, depth: sheetDepth);
    }
    var best = double.infinity;
    var depth = sheetDepth;
    final d = dot ?? anchor;
    if (d != null) {
      best = (p - d).distance;
      depth = dotDepth ?? sheetDepth;
    }
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      final t = _nearestParameter(a, b, p);
      final distance = (p - (a + (b - a) * t)).distance;
      if (distance < best) {
        best = distance;
        final ends = segmentDepths?[i];
        depth = ends == null ? sheetDepth : ends.$1 + (ends.$2 - ends.$1) * t;
      }
    }
    return (distance: best, depth: depth);
  }

  /// The distance in pixels from [p] to the nearest ink.
  double distanceTo(Offset p) => nearest(p, 0).distance;

  static double _nearestParameter(Offset a, Offset b, Offset p) {
    final ab = b - a;
    final length2 = ab.distanceSquared;
    if (length2 == 0) {
      return 0;
    }
    return (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length2).clamp(
      0.0,
      1.0,
    );
  }

  static bool _inside(List<Offset> polygon, Offset p) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }
}

/// The screen ink of a visible, defined [object] under [viewport].
/// [objects] is the whole construction, for line clipping.
///
/// A planar object is laid out in the planar frame (`viewport.flat`)
/// exactly as the label declutter always did, and each point is then
/// carried to the screen by the sheet map — so a circle under tilt is
/// the polygon of the ellipse it is drawn as, and with no tilt every
/// number is the one it was. A space-drawn object goes through
/// `spaceToScreen`.
ScreenInk screenInkOf(
  Iterable<GeoObject> objects,
  CanvasViewport viewport,
  Size canvasSize,
  GeoObject object,
) {
  final ink = ScreenInk();
  if (drawnInSpace(object)) {
    _spaceInk(ink, viewport, canvasSize, object);
    return ink;
  }
  final flat = viewport.flat;
  Offset map(Offset p) => viewport.sheetToScreen(p);
  void capsule(Offset a, Offset b) => ink.segments.add((map(a), map(b)));
  void chords(List<Offset> points) {
    for (var i = 0; i + 1 < points.length; i++) {
      capsule(points[i], points[i + 1]);
    }
  }

  switch (object) {
    case GeoPoint():
      ink.dot = map(flat.worldToScreen(object.position!));
    case Segment():
      capsule(
        flat.worldToScreen(object.start!),
        flat.worldToScreen(object.end!),
      );
    case Ray():
      final span = _clipSpan(objects, flat, object);
      if (span != null) {
        capsule(span.$1, span.$2);
      } else {
        // The painter's reach: far enough to cross the whole canvas.
        final start = flat.worldToScreen(object.start!);
        final along = flat.worldToScreen(object.throughPosition!) - start;
        if (along.distance > 0) {
          final direction = along / along.distance;
          final reach =
              (start.distance + canvasSize.width + canvasSize.height) *
              _reachGain(viewport);
          capsule(start, start + direction * reach);
        }
      }
    case GeoLine():
      final span = _clipSpan(objects, flat, object);
      if (span != null) {
        capsule(span.$1, span.$2);
      } else {
        final line = object.line!;
        final anchor = flat.worldToScreen(line.pointOnLine);
        final along =
            flat.worldToScreen(line.pointOnLine + line.direction) - anchor;
        if (along.distance > 0) {
          final direction = along / along.distance;
          final reach =
              (anchor.distance + canvasSize.width + canvasSize.height) *
              _reachGain(viewport);
          capsule(anchor - direction * reach, anchor + direction * reach);
        }
      }
    case Arc():
      chords(_branchPoints(flat, object, object.startAngle!, object.sweep!));
    case Sector():
      final points = _branchPoints(
        flat,
        object,
        object.startAngle!,
        object.sweep!,
      );
      chords(points);
      final center = flat.worldToScreen(object.circle!.center);
      capsule(center, points.first);
      capsule(center, points.last);
    case GeoCircle():
      final circle = object.circle;
      if (circle == null) {
        // A conic with no centre and radius: its own visible arcs, at
        // the sampling density the box asks for — a hyperbola's two arms
        // give two chains, not one.
        final box = viewport.visibleWorldBox(canvasSize);
        final strokes = ConicShape.of(object.conic!).polylines(
          min: box.min,
          max: box.max,
          flatness: viewport.screenToWorldLength(_conicFlatness),
        );
        for (final stroke in strokes) {
          chords([
            for (final point in stroke.points) flat.worldToScreen(point),
            if (stroke.closed && stroke.points.isNotEmpty)
              flat.worldToScreen(stroke.points.first),
          ]);
        }
        break;
      }
      final center = flat.worldToScreen(circle.center);
      final radius = flat.worldToScreenLength(circle.radius);
      final n = (2 * math.pi * radius / 12).ceil().clamp(12, 48);
      chords([
        for (var i = 0; i <= n; i++)
          center +
              Offset(
                radius * math.cos(2 * math.pi * i / n),
                radius * math.sin(2 * math.pi * i / n),
              ),
      ]);
    case GeoAngle():
      _addAngleMarker(flat, object, chords);
    case GeoPolygon():
      final points = [
        for (final vertex in object.polygonVertices!)
          flat.worldToScreen(vertex),
      ];
      chords([...points, points.first]);
      ink.fill = [for (final p in points) map(p)];
    case GeoMeasurement() || GeoText():
      // Pure text: no ink but the label.
      ink.anchor = map(flat.worldToScreen(labelAnchor(object)));
    case GeoLocus():
      _addLocusRuns(flat, object, chords);
  }
  return ink;
}

/// How much farther an unbounded line must reach in the planar frame to
/// still cross the canvas once the sheet map has foreshortened it. 1
/// with no tilt.
double _reachGain(CanvasViewport viewport) => viewport.isTilted
    ? 1 /
          math.max(
            math.cos(viewport.state.tilt).abs(),
            CanvasViewport.pickFloor,
          )
    : 1;

/// The ink of an object with no value in its sheet, from its space
/// value, with the camera depth at each end so a pointer can tell the
/// nearer of two that cross on screen.
void _spaceInk(
  ScreenInk ink,
  CanvasViewport viewport,
  Size canvasSize,
  GeoObject object,
) {
  final depths = ink.segmentDepths = [];
  void stroke(Vec3 from, Vec3 to) {
    ink.segments.add((
      viewport.spaceToScreen(from),
      viewport.spaceToScreen(to),
    ));
    depths.add((viewport.depthOf(from), viewport.depthOf(to)));
  }

  // How far, in world units, a line must run to cross the canvas from
  // anywhere on it, whatever its foreshortening.
  double reachFrom(Vec3 on, Vec3 unit) {
    final a = viewport.spaceToScreen(on);
    final perUnit = (viewport.spaceToScreen(on + unit) - a).distance;
    if (perUnit <= 0) {
      return 0;
    }
    return (a.distance + canvasSize.width + canvasSize.height) / perUnit;
  }

  switch (object) {
    case GeoPoint():
      final p = object.spacePosition;
      if (p != null) {
        ink.dot = viewport.spaceToScreen(p);
        ink.dotDepth = viewport.depthOf(p);
      }
    case Segment(:final spaceStart?, :final spaceEnd?):
      stroke(spaceStart, spaceEnd);
    case Ray(:final spaceStart?, :final spaceThrough?):
      final unit = (spaceThrough - spaceStart).normalizedOrNull;
      if (unit != null) {
        final reach = reachFrom(spaceStart, unit);
        if (reach > 0) {
          stroke(spaceStart, spaceStart + unit * reach);
        }
      }
    case GeoLine():
      final line = object.spaceLine;
      final on = line?.anchor;
      final unit = line?.direction.normalizedOrNull;
      if (on != null && unit != null) {
        final reach = reachFrom(on, unit);
        if (reach > 0) {
          stroke(on - unit * reach, on + unit * reach);
        }
      }
    default:
      break;
  }
}

/// A clipped line/ray's drawn stretch as screen endpoints, or null for
/// the full carrier (mirrors `GeometryPainter._clipSpan`).
(Offset, Offset)? _clipSpan(
  Iterable<GeoObject> objects,
  CanvasViewport viewport,
  GeoLine object,
) {
  if (object.attributes.lineClip == 0) {
    return null;
  }
  final span = lineClipSpan(objects, object);
  if (span == null) {
    return null;
  }
  return (viewport.worldToScreen(span.start), viewport.worldToScreen(span.end));
}

/// Screen points along a circle branch from [startAngle] through
/// [sweep], chord-sampled like the painted arc (world angles negate on
/// screen — here via the explicit y flip).
List<Offset> _branchPoints(
  CanvasViewport viewport,
  GeoCircle object,
  double startAngle,
  double sweep,
) {
  final circle = object.circle!;
  final center = viewport.worldToScreen(circle.center);
  final radius = viewport.worldToScreenLength(circle.radius);
  final n = (radius * sweep.abs() / 12).ceil().clamp(4, 48);
  return [
    for (var i = 0; i <= n; i++)
      center +
          Offset(
            radius * math.cos(startAngle + sweep * i / n),
            -radius * math.sin(startAngle + sweep * i / n),
          ),
  ];
}

/// The angle marker as capsules: the right-angle square's four edges, or
/// the wedge as spokes at ≤ 30° steps plus rim chords between the tips.
/// Spokes cover the wedge interior cheaply, and outside the sweep there
/// is no obstacle — so the reflex side of the vertex stays available,
/// exactly where an angle value reads best. Geometry mirrors
/// `GeometryPainter._drawAngleMarker` / `_rightAngleSquarePath`.
void _addAngleMarker(
  CanvasViewport viewport,
  GeoAngle object,
  void Function(List<Offset>) chords,
) {
  final angle = object.angle!;
  final vertex = viewport.worldToScreen(angle.vertex);
  final radius = object.attributes.angleMarkerRadius;
  if ((angle.sweep - math.pi / 2).abs() <= defaultEpsilon) {
    final side = 0.7 * radius;
    final d1 = angle.startDirection;
    final d2 = d1.rotated(angle.sweep);
    // World directions are y-up; the screen flips y.
    Offset corner(Vec2 d) => vertex + Offset(d.x, -d.y) * side;
    chords([vertex, corner(d1), corner(d1 + d2), corner(d2), vertex]);
    return;
  }
  final start = angle.startDirection.angle;
  final steps = math.max(2, (angle.sweep / (math.pi / 6)).ceil());
  final tips = [
    for (var i = 0; i <= steps; i++)
      vertex +
          Offset(
            radius * math.cos(start + angle.sweep * i / steps),
            -radius * math.sin(start + angle.sweep * i / steps),
          ),
  ];
  for (final tip in tips) {
    chords([vertex, tip]);
  }
  chords(tips);
}

/// A locus's non-null sample runs as chord polylines, decimated so a
/// long trace stays a few dozen capsules.
void _addLocusRuns(
  CanvasViewport viewport,
  GeoLocus object,
  void Function(List<Offset>) chords,
) {
  final run = <Offset>[];
  void endRun() {
    if (run.length > 1) {
      final stride = math.max(1, run.length ~/ 64);
      chords([
        for (var i = 0; i < run.length; i += stride) run[i],
        if ((run.length - 1) % stride != 0) run.last,
      ]);
    }
    run.clear();
  }

  for (final sample in object.samples!) {
    if (sample == null) {
      endRun();
    } else {
      run.add(viewport.worldToScreen(sample));
    }
  }
  endRun();
}
