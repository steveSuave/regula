import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/orthocenter.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Orthocenter', () {
    test('right triangle: orthocenter is the right-angle vertex', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final h = Orthocenter(id: 'h', vertex1: a, vertex2: b, vertex3: c);
      expect(h.position!.closeTo(const Vec2(0, 0)), isTrue);
      expect(h.parents, [a, b, c]);
    });

    test('equilateral triangle: orthocenter coincides with the centroid', () {
      const apex = Vec2(1, 1.7320508075688772); // (1, √3)
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(2, 0));
      final c = FreePoint(id: 'c', position: apex);
      final h = Orthocenter(id: 'h', vertex1: a, vertex2: b, vertex3: c);
      expect(h.position!.closeTo((const Vec2(2, 0) + apex) / 3, 1e-9), isTrue);
    });

    test('drag through collinearity: undefined, then recovers', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final h = Orthocenter(id: 'h', vertex1: a, vertex2: b, vertex3: c);
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(h);

      construction.moveFreePoint('c', const Vec2(2, 0));
      expect(h.isDefined, isFalse);

      construction.moveFreePoint('c', const Vec2(4, 3));
      expect(h.isDefined, isTrue);
      // Right angle now at b = (4, 0).
      expect(h.position!.closeTo(const Vec2(4, 0)), isTrue);
    });
  });
}
