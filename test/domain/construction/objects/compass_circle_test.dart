import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/compass_circle.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompassCircle', () {
    test('carries the radius-point distance to the center', () {
      final r1 = FreePoint(id: 'r1', position: const Vec2(0, 0));
      final r2 = FreePoint(id: 'r2', position: const Vec2(3, 4));
      final c = FreePoint(id: 'c', position: const Vec2(10, -2));
      final k = CompassCircle(
        id: 'k',
        radiusPoint1: r1,
        radiusPoint2: r2,
        center: c,
      );
      expect(k.circle!.center, const Vec2(10, -2));
      expect(k.circle!.radius, closeTo(5, 1e-9));
      expect(k.parents, [r1, r2, c]);
    });

    test('tracks moved parents through the construction', () {
      final construction = Construction();
      final r1 = FreePoint(id: 'r1', position: const Vec2(0, 0));
      final r2 = FreePoint(id: 'r2', position: const Vec2(2, 0));
      final c = FreePoint(id: 'c', position: const Vec2(5, 5));
      final k = CompassCircle(
        id: 'k',
        radiusPoint1: r1,
        radiusPoint2: r2,
        center: c,
      );
      construction
        ..add(r1)
        ..add(r2)
        ..add(c)
        ..add(k);

      construction.moveFreePoint('r2', const Vec2(7, 0));
      expect(k.circle!.radius, closeTo(7, 1e-9));

      construction.moveFreePoint('c', Vec2.zero);
      expect(k.circle!.center, Vec2.zero);
    });

    test('coincident radius points give a zero-radius circle, not undefined',
        () {
      final r1 = FreePoint(id: 'r1', position: const Vec2(1, 1));
      final r2 = FreePoint(id: 'r2', position: const Vec2(1, 1));
      final c = FreePoint(id: 'c', position: const Vec2(4, 4));
      final k = CompassCircle(
        id: 'k',
        radiusPoint1: r1,
        radiusPoint2: r2,
        center: c,
      );
      expect(k.isDefined, isTrue);
      expect(k.circle!.radius, 0);
    });
  });
}
