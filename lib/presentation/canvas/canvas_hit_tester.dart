import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/ray.dart';
import '../../domain/construction/objects/segment.dart';
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

  /// Distance from [point] to the object's visible geometry. Only called
  /// on defined objects, so the force-unwraps are safe.
  double _distanceTo(GeoObject object, Vec2 point) => switch (object) {
        GeoPoint() => object.position!.distanceTo(point),
        GeoCircle() => object.circle!.distanceTo(point),
        // Segments and rays measure to their extent, not the infinite
        // carrier: t clamps to [0, 1] and [0, ∞) respectively.
        Segment() => _clampedDistance(object.start!, object.end!, point, 1),
        Ray() => _clampedDistance(
            object.start!, object.throughPosition!, point, double.infinity),
        GeoLine() => object.line!.distanceTo(point),
      };

  double _clampedDistance(Vec2 a, Vec2 b, Vec2 p, double tMax) {
    final ab = b - a;
    if (ab.normSquared == 0) {
      return p.distanceTo(a);
    }
    final t = ((p - a).dot(ab) / ab.normSquared).clamp(0.0, tMax);
    return p.distanceTo(a.lerp(b, t));
  }
}
