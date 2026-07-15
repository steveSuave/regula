import 'package:glados/glados.dart';
import 'package:regula/domain/construction/objects/fixed_radius_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/intersection_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/math/vec2.dart';

import '../../math/generators.dart';

void main() {
  group('FixedRadiusCircle', () {
    test('circle around the center at the given radius', () {
      final center = FreePoint(id: 'c', position: const Vec2(2, -1));
      final circle = FixedRadiusCircle(id: 'k', center: center, radius: 3.5);
      expect(circle.circle!.center, const Vec2(2, -1));
      expect(circle.circle!.radius, 3.5);
      expect(circle.parents, [center]);
    });

    test('rejects a non-positive or non-finite radius', () {
      final center = FreePoint(id: 'c', position: Vec2.zero);
      FixedRadiusCircle make(double radius) =>
          FixedRadiusCircle(id: 'k', center: center, radius: radius);
      expect(() => make(0), throwsArgumentError);
      expect(() => make(-1), throwsArgumentError);
      expect(() => make(double.nan), throwsArgumentError);
      expect(() => make(double.infinity), throwsArgumentError);
    });

    test('undefined while the center is, recovers with the radius intact', () {
      final o = FreePoint(id: 'o', position: Vec2.zero);
      final x = FreePoint(id: 'x', position: const Vec2(4, 0));
      final p = FreePoint(id: 'p', position: const Vec2(0, 1));
      final q = FreePoint(id: 'q', position: const Vec2(4, 1));
      final xAxis = LineThroughTwoPoints(id: 'h', point1: o, point2: x);
      final other = LineThroughTwoPoints(id: 'l', point1: p, point2: q);
      final crossing = IntersectionPoint(
        id: 'int',
        curve1: xAxis,
        curve2: other,
        branchIndex: 0,
      );
      final circle = FixedRadiusCircle(id: 'k', center: crossing, radius: 2);
      expect(crossing.position, isNull, reason: 'parallel lines — no crossing');
      expect(circle.circle, isNull);
      expect(circle.isDefined, isFalse);

      // Tilt the second line: the crossing appears and the circle with it.
      q.position = const Vec2(4, -1);
      other.recompute();
      crossing.recompute();
      circle.recompute();
      expect(circle.circle, isNotNull);
      expect(circle.circle!.center, crossing.position);
      expect(circle.circle!.radius, 2);

      q.position = const Vec2(4, 1);
      other.recompute();
      crossing.recompute();
      circle.recompute();
      expect(circle.circle, isNull, reason: 'parallel again — undefined');
    });

    Glados(any.vec2).test('the radius is constant under center drags', (p) {
      final center = FreePoint(id: 'c', position: Vec2.zero);
      final circle = FixedRadiusCircle(id: 'k', center: center, radius: 1.75);
      center.position = p;
      circle.recompute();
      expect(circle.circle!.center, p);
      expect(circle.circle!.radius, 1.75);
    });
  });
}
