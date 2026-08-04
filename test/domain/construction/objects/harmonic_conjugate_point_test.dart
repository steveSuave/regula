import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/harmonic_conjugate_point.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('HarmonicConjugatePoint', () {
    test('the fourth harmonic of the quarter point on construction', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(1, 0));
      final d = HarmonicConjugatePoint(
          id: 'd', point1: a, point2: b, point3: c);
      expect(d.position!.closeTo(const Vec2(-2, 0)), isTrue);
      expect(d.parents, [a, b, c]);
    });

    test('undefined while the points are not collinear, recovers after', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(1, 3));
      final d = HarmonicConjugatePoint(
          id: 'd', point1: a, point2: b, point3: c);
      expect(d.isDefined, isFalse);

      c.position = const Vec2(1, 0);
      d.recompute();
      expect(d.isDefined, isTrue);
      expect(d.position!.closeTo(const Vec2(-2, 0)), isTrue);
    });

    test('undefined while C is the midpoint of AB (conjugate at infinity)',
        () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(2, 0));
      final d = HarmonicConjugatePoint(
          id: 'd', point1: a, point2: b, point3: c);
      expect(d.isDefined, isFalse);
    });

    test('undefined while the base pair coincides', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 1));
      final c = FreePoint(id: 'c', position: const Vec2(3, 1));
      final d = HarmonicConjugatePoint(
          id: 'd', point1: a, point2: b, point3: c);
      expect(d.isDefined, isFalse);
    });

    test('tracks moved parents after recompute', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(1, 0));
      final d = HarmonicConjugatePoint(
          id: 'd', point1: a, point2: b, point3: c);

      // Slide C outside the segment: the conjugate returns inside.
      c.position = const Vec2(-2, 0);
      d.recompute();
      expect(d.position!.closeTo(const Vec2(1, 0)), isTrue,
          reason: 'the harmonic map is an involution');
    });
  });
}
