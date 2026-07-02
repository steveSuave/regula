import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/circumcenter.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Circumcenter', () {
    test('right triangle: circumcenter is the hypotenuse midpoint', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final o = Circumcenter(id: 'o', vertex1: a, vertex2: b, vertex3: c);
      expect(o.position!.closeTo(const Vec2(2, 1.5)), isTrue);
      expect(o.parents, [a, b, c]);
    });

    test('is equidistant from all three vertices', () {
      final a = FreePoint(id: 'a', position: const Vec2(-1, 2));
      final b = FreePoint(id: 'b', position: const Vec2(5, 0));
      final c = FreePoint(id: 'c', position: const Vec2(2, 7));
      final o = Circumcenter(id: 'o', vertex1: a, vertex2: b, vertex3: c);
      final p = o.position!;
      final r = p.distanceTo(a.position);
      expect(p.distanceTo(b.position), closeTo(r, 1e-9));
      expect(p.distanceTo(c.position), closeTo(r, 1e-9));
    });

    test('drag through collinearity: undefined, then recovers', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final o = Circumcenter(id: 'o', vertex1: a, vertex2: b, vertex3: c);
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(o);

      construction.moveFreePoint('c', const Vec2(2, 0));
      expect(o.isDefined, isFalse);
      expect(o.position, isNull);

      construction.moveFreePoint('c', const Vec2(0, 3));
      expect(o.isDefined, isTrue);
      expect(o.position!.closeTo(const Vec2(2, 1.5)), isTrue);
    });

    test('dependents chained on an undefined circumcenter go undefined too',
        () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final o = Circumcenter(id: 'o', vertex1: a, vertex2: b, vertex3: c);
      final m = Midpoint(id: 'm', point1: a, point2: o);
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(o)
        ..add(m);

      expect(m.position!.closeTo(const Vec2(1, 0.75)), isTrue);

      construction.moveFreePoint('c', const Vec2(2, 0));
      expect(m.isDefined, isFalse);

      construction.moveFreePoint('c', const Vec2(0, 3));
      expect(m.position!.closeTo(const Vec2(1, 0.75)), isTrue);
    });
  });
}
