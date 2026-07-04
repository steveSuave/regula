import 'dart:math' as math;

import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/rotated_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RotatedPoint', () {
    test('rotates counter-clockwise around the center on construction', () {
      final p = FreePoint(id: 'p', position: const Vec2(1, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 0));
      final r = RotatedPoint(id: 'r', point: p, center: c, angle: math.pi / 2);
      expect(r.position!.closeTo(const Vec2(0, 1), 1e-12), isTrue);
      expect(r.parents, [p, c]);
    });

    test('rotation is about the center, not the origin', () {
      final p = FreePoint(id: 'p', position: const Vec2(4, 1));
      final c = FreePoint(id: 'c', position: const Vec2(3, 1));
      final r = RotatedPoint(id: 'r', point: p, center: c, angle: math.pi / 2);
      expect(r.position!.closeTo(const Vec2(3, 2), 1e-12), isTrue);
    });

    test('preserves the distance to the center, also after drags', () {
      final p = FreePoint(id: 'p', position: const Vec2(5, -2));
      final c = FreePoint(id: 'c', position: const Vec2(-1, 3));
      final r = RotatedPoint(id: 'r', point: p, center: c, angle: 0.75);
      expect(
        r.position!.distanceTo(c.position),
        closeTo(p.position.distanceTo(c.position), 1e-9),
      );

      p.position = const Vec2(-7, 0.5);
      r.recompute();
      expect(
        r.position!.distanceTo(c.position),
        closeTo(p.position.distanceTo(c.position), 1e-9),
      );
    });

    test('angle 0 is the identity, opposite angles cancel', () {
      final p = FreePoint(id: 'p', position: const Vec2(2, 7));
      final c = FreePoint(id: 'c', position: const Vec2(-3, 1));
      expect(
        RotatedPoint(id: 'r0', point: p, center: c, angle: 0).position,
        p.position,
      );
      final forth = RotatedPoint(id: 'rf', point: p, center: c, angle: 1.2);
      final back = RotatedPoint(id: 'rb', point: forth, center: c, angle: -1.2);
      expect(back.position!.closeTo(p.position, 1e-9), isTrue);
    });

    test('a point at the center is its own image', () {
      final p = FreePoint(id: 'p', position: const Vec2(1, 1));
      final c = FreePoint(id: 'c', position: const Vec2(1, 1));
      final r = RotatedPoint(id: 'r', point: p, center: c, angle: 2);
      expect(r.isDefined, isTrue);
      expect(r.position!.closeTo(const Vec2(1, 1), 1e-12), isTrue);
    });

    test('tracks a moved center after recompute', () {
      final p = FreePoint(id: 'p', position: const Vec2(1, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 0));
      final r = RotatedPoint(id: 'r', point: p, center: c, angle: math.pi);
      c.position = const Vec2(2, 0);
      r.recompute();
      expect(r.position!.closeTo(const Vec2(3, 0), 1e-12), isTrue);
    });
  });
}
