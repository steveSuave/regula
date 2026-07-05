import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('Midpoint', () {
    test('computes the midpoint on construction', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 2));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      expect(m.position, const Vec2(2, 1));
      expect(m.parents, [a, b]);
    });

    test('tracks a moved parent after recompute', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      b.position = const Vec2(0, 6);
      m.recompute();
      expect(m.position, const Vec2(0, 3));
    });

    test('coincident parents are not degenerate', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 1));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      expect(m.isDefined, isTrue);
      expect(m.position, const Vec2(1, 1));
    });
  });
}
