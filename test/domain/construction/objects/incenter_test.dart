import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/incenter.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Incenter', () {
    test('3-4-5 right triangle: incenter at (r, r) with r = 1', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final i = Incenter(id: 'i', vertex1: a, vertex2: b, vertex3: c);
      expect(i.position!.closeTo(const Vec2(1, 1), 1e-9), isTrue);
      expect(i.parents, [a, b, c]);
    });

    test('isosceles triangle: incenter lies on the axis of symmetry', () {
      final a = FreePoint(id: 'a', position: const Vec2(-3, 0));
      final b = FreePoint(id: 'b', position: const Vec2(3, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 5));
      final i = Incenter(id: 'i', vertex1: a, vertex2: b, vertex3: c);
      expect(i.position!.x, closeTo(0, 1e-9));
      expect(i.position!.y, greaterThan(0));
      expect(i.position!.y, lessThan(5));
    });

    test('drag through collinearity: undefined, then recovers', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final i = Incenter(id: 'i', vertex1: a, vertex2: b, vertex3: c);
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(i);

      construction.moveFreePoint('c', const Vec2(2, 0));
      expect(i.isDefined, isFalse);

      construction.moveFreePoint('c', const Vec2(0, 3));
      expect(i.position!.closeTo(const Vec2(1, 1), 1e-9), isTrue);
    });
  });
}
