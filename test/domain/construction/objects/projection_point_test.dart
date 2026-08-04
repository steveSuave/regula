import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/projection_point.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('ProjectionPoint', () {
    test('projects onto the line on construction', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(1, 3));
      final foot = ProjectionPoint(id: 'f', point: p, line: line);
      expect(foot.position!.closeTo(const Vec2(1, 0)), isTrue);
      expect(foot.parents, [p, line]);
    });

    test('a point on the line is its own projection', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(2, 2));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(5, 5));
      final foot = ProjectionPoint(id: 'f', point: p, line: line);
      expect(foot.position!.closeTo(const Vec2(5, 5)), isTrue);
    });

    test('the foot lies on the line and the drop is perpendicular', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, -2));
      final b = FreePoint(id: 'b', position: const Vec2(4, 5));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(-3, 6));
      final foot = ProjectionPoint(id: 'f', point: p, line: line);
      final f = foot.position!;
      expect(line.line!.contains(f, 1e-9), isTrue);
      final direction = b.position - a.position;
      expect(direction.dot(p.position - f), closeTo(0, 1e-9));
    });

    test('projecting the foot again is the identity', () {
      final a = FreePoint(id: 'a', position: const Vec2(-1, 2));
      final b = FreePoint(id: 'b', position: const Vec2(3, -4));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(7, 1.5));
      final once = ProjectionPoint(id: 'f1', point: p, line: line);
      final twice = ProjectionPoint(id: 'f2', point: once, line: line);
      expect(twice.position!.closeTo(once.position!, 1e-9), isTrue);
    });

    test('tracks moved parents after recompute', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(1, 3));
      final foot = ProjectionPoint(id: 'f', point: p, line: line);

      p.position = const Vec2(2, -5);
      foot.recompute();
      expect(foot.position!.closeTo(const Vec2(2, 0)), isTrue);

      // Rotate the line to the y-axis: the foot lands on x = 0.
      b.position = const Vec2(0, 4);
      line.recompute();
      foot.recompute();
      expect(foot.position!.closeTo(const Vec2(0, -5)), isTrue);
    });

    test('undefined while the line is, recovers after', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: Vec2.zero); // coincident
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(1, 3));
      final foot = ProjectionPoint(id: 'f', point: p, line: line);
      expect(foot.isDefined, isFalse);

      b.position = const Vec2(4, 0);
      line.recompute();
      foot.recompute();
      expect(foot.isDefined, isTrue);
      expect(foot.position!.closeTo(const Vec2(1, 0)), isTrue);
    });
  });
}
