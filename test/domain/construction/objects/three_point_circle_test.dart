import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/three_point_circle.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('ThreePointCircle', () {
    test('right triangle: circumcircle centered on the hypotenuse midpoint',
        () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final k = ThreePointCircle(id: 'k', point1: a, point2: b, point3: c);
      expect(k.circle!.center.closeTo(const Vec2(2, 1.5)), isTrue);
      expect(k.circle!.radius, closeTo(2.5, 1e-9));
      expect(k.parents, [a, b, c]);
    });

    test('passes through all three points', () {
      final a = FreePoint(id: 'a', position: const Vec2(-1, 2));
      final b = FreePoint(id: 'b', position: const Vec2(5, 0));
      final c = FreePoint(id: 'c', position: const Vec2(2, 7));
      final k = ThreePointCircle(id: 'k', point1: a, point2: b, point3: c);
      final circle = k.circle!;
      for (final p in [a, b, c]) {
        expect(circle.center.distanceTo(p.position),
            closeTo(circle.radius, 1e-9));
      }
    });

    test('drag through collinearity: undefined, then recovers', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final k = ThreePointCircle(id: 'k', point1: a, point2: b, point3: c);
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(k);

      construction.moveFreePoint('c', const Vec2(2, 0));
      expect(k.isDefined, isFalse);
      expect(k.circle, isNull);

      construction.moveFreePoint('c', const Vec2(0, 3));
      expect(k.isDefined, isTrue);
      expect(k.circle!.center.closeTo(const Vec2(2, 1.5)), isTrue);
    });

    test('coincident points are collinear, so undefined', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 1));
      final c = FreePoint(id: 'c', position: const Vec2(4, 5));
      final k = ThreePointCircle(id: 'k', point1: a, point2: b, point3: c);
      expect(k.isDefined, isFalse);
    });
  });
}
