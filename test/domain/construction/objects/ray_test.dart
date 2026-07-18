import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/ray.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('Ray', () {
    test('carrier contains both points; start/through expose the extent',
        () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(4, 5));
      final r = Ray(id: 'r', origin: a, through: b);
      expect(r.line!.contains(const Vec2(1, 1)), isTrue);
      expect(r.line!.contains(const Vec2(4, 5)), isTrue);
      expect(r.start, const Vec2(1, 1));
      expect(r.throughPosition, const Vec2(4, 5));
      expect(r.parents, [a, b]);
    });

    test('parameterExtent is bounded at the origin, open past through', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final r = Ray(id: 'r', origin: a, through: b);

      final line = r.line!;
      final t0 = line.parameterAt(const Vec2(1, 0));
      final tThrough = line.parameterAt(const Vec2(4, 0));
      final (min, max) = r.parameterExtent!;
      // Whichever way the carrier is oriented, the origin is the one
      // bound and the through side is open.
      if (tThrough >= t0) {
        expect(min, t0);
        expect(max, isNull);
      } else {
        expect(min, isNull);
        expect(max, t0);
      }

      expect(r.clampParameter(tThrough), tThrough,
          reason: 'parameters on the ray pass through untouched');
      final behind = t0 - (tThrough - t0);
      expect(r.clampParameter(behind), t0,
          reason: 'behind the origin clamps onto it');
      final far = t0 + 100 * (tThrough - t0);
      expect(r.clampParameter(far), far,
          reason: 'the through side is unbounded');
    });

    test('drag through coincidence: undefined, then recovers', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(2, 0));
      final r = Ray(id: 'r', origin: a, through: b);
      construction
        ..add(a)
        ..add(b)
        ..add(r);

      construction.moveFreePoint('b', Vec2.zero);
      expect(r.isDefined, isFalse);
      expect(r.line, isNull);
      expect(r.parameterExtent, isNull);

      construction.moveFreePoint('b', const Vec2(0, 3));
      expect(r.isDefined, isTrue);
      expect(r.line!.contains(const Vec2(0, 2)), isTrue);
    });
  });
}
