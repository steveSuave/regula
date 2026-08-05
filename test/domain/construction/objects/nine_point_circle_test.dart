import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/nine_point_circle.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('NinePointCircle', () {
    test('3-4-5 right triangle: center (1, 0.75), radius 1.25', () {
      // Circumcenter (2, 1.5) — the hypotenuse midpoint — and orthocenter
      // (0, 0) — the right-angle vertex; the nine-point circle sits halfway
      // between them at half the circumradius.
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final k = NinePointCircle(id: 'k', vertex1: a, vertex2: b, vertex3: c);
      expect(k.circle!.center.closeTo(const Vec2(1, 0.75)), isTrue);
      expect(k.circle!.radius, closeTo(1.25, 1e-9));
      expect(k.parents, [a, b, c]);
    });

    test('passes through the three side midpoints', () {
      final a = FreePoint(id: 'a', position: const Vec2(-1, 2));
      final b = FreePoint(id: 'b', position: const Vec2(5, 0));
      final c = FreePoint(id: 'c', position: const Vec2(2, 7));
      final k = NinePointCircle(id: 'k', vertex1: a, vertex2: b, vertex3: c);
      final circle = k.circle!;
      final midpoints = [
        (a.position + b.position) / 2,
        (b.position + c.position) / 2,
        (c.position + a.position) / 2,
      ];
      for (final m in midpoints) {
        expect(circle.center.distanceTo(m), closeTo(circle.radius, 1e-9));
      }
    });

    test('drag through collinearity: undefined, then recovers', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final k = NinePointCircle(id: 'k', vertex1: a, vertex2: b, vertex3: c);
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
      expect(k.circle!.center.closeTo(const Vec2(1, 0.75)), isTrue);
    });

    test('coincident points are collinear, so undefined', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 1));
      final c = FreePoint(id: 'c', position: const Vec2(4, 5));
      final k = NinePointCircle(id: 'k', vertex1: a, vertex2: b, vertex3: c);
      expect(k.isDefined, isFalse);
    });
  });
}
