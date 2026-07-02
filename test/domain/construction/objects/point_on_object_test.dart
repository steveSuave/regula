import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/circle_center_point.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/point_on_object.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointOnObject', () {
    test('near() on a line lands on the tap projection', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);

      final p = PointOnObject.near(
        id: 'p',
        curve: line,
        position: const Vec2(3, 5),
      );

      expect(p.position!.closeTo(const Vec2(3, 0)), isTrue);
      expect(p.parents, [line]);
    });

    test('near() on a circle lands on the radial projection', () {
      final center = FreePoint(id: 'c', position: const Vec2(1, 1));
      final rim = FreePoint(id: 'r', position: const Vec2(3, 1));
      final circle = CircleCenterPoint(id: 'k', center: center, onCircle: rim);

      final p = PointOnObject.near(
        id: 'p',
        curve: circle,
        position: const Vec2(1, 9),
      );

      expect(p.position!.closeTo(const Vec2(1, 3)), isTrue);
    });

    test('rides along when the line moves', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = PointOnObject.near(
        id: 'p',
        curve: line,
        position: const Vec2(3, 0),
      );
      construction
        ..add(a)
        ..add(b)
        ..add(line)
        ..add(p);

      // Translate the whole line upward; the point must stay on it.
      construction.moveFreePoint('a', const Vec2(0, 2));
      construction.moveFreePoint('b', const Vec2(4, 2));
      expect(line.line!.contains(p.position!), isTrue);
      expect(p.position!.y, closeTo(2, 1e-9));
    });

    test('rides along when the circle grows', () {
      final construction = Construction();
      final center = FreePoint(id: 'c', position: Vec2.zero);
      final rim = FreePoint(id: 'r', position: const Vec2(2, 0));
      final circle = CircleCenterPoint(id: 'k', center: center, onCircle: rim);
      final p = PointOnObject.near(
        id: 'p',
        curve: circle,
        position: const Vec2(0, 2),
      );
      construction
        ..add(center)
        ..add(rim)
        ..add(circle)
        ..add(p);

      construction.moveFreePoint('r', const Vec2(5, 0));
      expect(p.position!.closeTo(const Vec2(0, 5)), isTrue,
          reason: 'the polar angle is fixed, the radius follows the curve');
    });

    test('undefined while the curve is, recovers after', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = PointOnObject.near(
        id: 'p',
        curve: line,
        position: const Vec2(3, 0),
      );
      construction
        ..add(a)
        ..add(b)
        ..add(line)
        ..add(p);

      construction.moveFreePoint('b', Vec2.zero); // line degenerates
      expect(line.isDefined, isFalse);
      expect(p.isDefined, isFalse);

      construction.moveFreePoint('b', const Vec2(4, 0));
      expect(p.isDefined, isTrue);
      expect(line.line!.contains(p.position!), isTrue);
    });

    test('rejects a point parent and projection onto an undefined curve',
        () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: Vec2.zero); // coincident
      final undefinedLine = LineThroughTwoPoints(id: 'l', point1: a, point2: b);

      expect(
        () => PointOnObject(id: 'p', curve: a, parameter: 0),
        throwsArgumentError,
      );
      expect(
        () => PointOnObject.near(
          id: 'p',
          curve: undefinedLine,
          position: Vec2.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => PointOnObject(id: 'p', curve: undefinedLine, parameter: 1),
        returnsNormally,
        reason: 'a stored parameter survives construction while undefined',
      );
    });
  });
}
