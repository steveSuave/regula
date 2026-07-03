import 'dart:math' as math;

import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/arc.dart';
import '../../domain/construction/objects/ray.dart';
import '../../domain/construction/objects/sector.dart';
import '../../domain/construction/objects/segment.dart';
import '../../domain/math/circle_eq.dart';
import '../../domain/math/vec2.dart';

/// Finds the object under a tap.
///
/// Works entirely in world coordinates: the caller converts the screen
/// threshold (8 px by convention) to world units via
/// `CanvasViewport.screenToWorldLength` — so the tester itself needs no
/// viewport and no Flutter types.
///
/// Selection order is (priority, distance), lexicographically: any point
/// within the threshold beats any circle, which beats any line — small,
/// precise targets must not be shadowed by the big shapes drawn through
/// them (PLAN: points > arcs/circles > segments/rays/lines > angles).
/// Ties go to the object added latest, i.e. the one drawn on top.
///
/// Undefined and invisible objects are never hit.
///
/// Named `CanvasHitTester` because `flutter_test` exports a `HitTester`
/// of its own, which every widget test would collide with.
class CanvasHitTester {
  const CanvasHitTester();

  /// The best object within [threshold] world units of [point], or null.
  ///
  /// [objects] must come in insertion (drawing) order — that is what makes
  /// "latest wins ties" mean "topmost wins".
  GeoObject? hitTest(
    Iterable<GeoObject> objects,
    Vec2 point,
    double threshold,
  ) {
    GeoObject? best;
    var bestPriority = 0;
    var bestDistance = double.infinity;

    for (final object in objects) {
      if (!object.attributes.visible || !object.isDefined) {
        continue;
      }
      final distance = _distanceTo(object, point);
      if (distance > threshold) {
        continue;
      }
      final priority = switch (object) {
        GeoPoint() => 0,
        GeoCircle() => 1,
        GeoLine() => 2,
        GeoAngle() => 3,
      };
      final atLeastAsGood = best == null ||
          priority < bestPriority ||
          (priority == bestPriority && distance <= bestDistance);
      if (atLeastAsGood) {
        best = object;
        bestPriority = priority;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// The visible, defined objects wholly inside the axis-aligned world
  /// rect spanned by [corner1] and [corner2] — rubber-band selection.
  ///
  /// "Wholly inside" is the rule: a band that merely crosses an object
  /// does not take it. Infinite carriers (lines, rays) can never be
  /// contained; arcs and sectors are measured by their drawn branch, not
  /// the full carrier circle; an angle by its vertex (its marker is
  /// screen-sized, invisible to a world-space tester — cf. [hitTest]).
  List<GeoObject> objectsInRect(
    Iterable<GeoObject> objects,
    Vec2 corner1,
    Vec2 corner2,
  ) {
    final minX = math.min(corner1.x, corner2.x);
    final maxX = math.max(corner1.x, corner2.x);
    final minY = math.min(corner1.y, corner2.y);
    final maxY = math.max(corner1.y, corner2.y);
    bool within(Vec2 p) =>
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;

    return [
      for (final object in objects)
        if (object.attributes.visible &&
            object.isDefined &&
            _containedIn(object, within))
          object,
    ];
  }

  bool _containedIn(GeoObject object, bool Function(Vec2) within) =>
      switch (object) {
        GeoPoint() => within(object.position!),
        Segment() => within(object.start!) && within(object.end!),
        Arc() => _branchExtremes(
            object.circle!,
            object.containsAngle,
            [object.startPosition!, object.endPosition!],
          ).every(within),
        Sector() => _branchExtremes(
            object.circle!,
            object.containsAngle,
            [object.circle!.center, object.startRim!, object.endRim!],
          ).every(within),
        GeoCircle() =>
          _branchExtremes(object.circle!, (_) => true, const []).every(within),
        GeoLine() => false, // infinite (rays included): never contained
        GeoAngle() => within(object.angle!.vertex),
      };

  /// The points bounding a carrier-circle branch: the [seeds] (endpoints,
  /// and for a sector its center) plus each cardinal-direction extreme of
  /// the carrier that lies on the branch. Their combined bounding box is
  /// the branch's exact bounding box.
  Iterable<Vec2> _branchExtremes(
    CircleEq circle,
    bool Function(double) containsAngle,
    List<Vec2> seeds,
  ) sync* {
    yield* seeds;
    for (var k = 0; k < 4; k++) {
      final angle = k * math.pi / 2;
      if (containsAngle(angle)) {
        yield circle.center +
            Vec2(math.cos(angle), math.sin(angle)) * circle.radius;
      }
    }
  }

  /// Distance from [point] to the object's visible geometry. Only called
  /// on defined objects, so the force-unwraps are safe.
  double _distanceTo(GeoObject object, Vec2 point) => switch (object) {
        GeoPoint() => object.position!.distanceTo(point),
        // An arc measures to its branch of the carrier: on the far branch
        // the nearest visible geometry is an endpoint (cf. segment/ray).
        Arc() => _arcDistance(object, point),
        // A sector's visible geometry is its wedge outline: the arc branch
        // plus the two straight radius edges.
        Sector() => _sectorDistance(object, point),
        GeoCircle() => object.circle!.distanceTo(point),
        // Segments and rays measure to their extent, not the infinite
        // carrier: t clamps to [0, 1] and [0, ∞) respectively.
        Segment() => _clampedDistance(object.start!, object.end!, point, 1),
        Ray() => _clampedDistance(
            object.start!, object.throughPosition!, point, double.infinity),
        GeoLine() => object.line!.distanceTo(point),
        // An angle's marker is drawn at a fixed *screen* radius the tester
        // can't know (it has no viewport), so an angle is picked at its
        // vertex — lowest priority, so anything else there wins.
        GeoAngle() => object.angle!.vertex.distanceTo(point),
      };

  double _arcDistance(Arc arc, Vec2 p) {
    final circle = arc.circle!;
    if (arc.containsAngle(circle.angleAt(p))) {
      return circle.distanceTo(p);
    }
    final toStart = p.distanceTo(arc.startPosition!);
    final toEnd = p.distanceTo(arc.endPosition!);
    return toStart < toEnd ? toStart : toEnd;
  }

  double _sectorDistance(Sector sector, Vec2 p) {
    final circle = sector.circle!;
    final arc = sector.containsAngle(circle.angleAt(p))
        ? circle.distanceTo(p)
        : double.infinity;
    final edge1 = _clampedDistance(circle.center, sector.startRim!, p, 1);
    final edge2 = _clampedDistance(circle.center, sector.endRim!, p, 1);
    return math.min(arc, math.min(edge1, edge2));
  }

  double _clampedDistance(Vec2 a, Vec2 b, Vec2 p, double tMax) {
    final ab = b - a;
    if (ab.normSquared == 0) {
      return p.distanceTo(a);
    }
    final t = ((p - a).dot(ab) / ab.normSquared).clamp(0.0, tMax);
    return p.distanceTo(a.lerp(b, t));
  }
}
