import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/arc.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('Arc', () {
    test('carrier is the circumcircle, extent starts at the start point',
        () {
      final s = FreePoint(id: 's', position: const Vec2(1, 0));
      final v = FreePoint(id: 'v', position: const Vec2(0, 1));
      final e = FreePoint(id: 'e', position: const Vec2(-1, 0));
      final arc = Arc(id: 'arc', start: s, via: v, end: e);

      expect(arc.circle!.center.closeTo(Vec2.zero), isTrue);
      expect(arc.circle!.radius, closeTo(1, 1e-9));
      expect(arc.startAngle, closeTo(0, 1e-9));
      expect(arc.parents, [s, v, e]);
    });

    test('sweep is positive when via sits on the CCW branch', () {
      final s = FreePoint(id: 's', position: const Vec2(1, 0));
      final v = FreePoint(id: 'v', position: const Vec2(0, 1));
      final e = FreePoint(id: 'e', position: const Vec2(-1, 0));
      final arc = Arc(id: 'arc', start: s, via: v, end: e);

      expect(arc.sweep, closeTo(math.pi, 1e-9));
    });

    test('sweep is negative when via sits on the CW branch', () {
      final s = FreePoint(id: 's', position: const Vec2(1, 0));
      final v = FreePoint(id: 'v', position: const Vec2(0, -1));
      final e = FreePoint(id: 'e', position: const Vec2(-1, 0));
      final arc = Arc(id: 'arc', start: s, via: v, end: e);

      expect(arc.sweep, closeTo(-math.pi, 1e-9));
    });

    test('containsAngle covers the via branch, endpoints included', () {
      final s = FreePoint(id: 's', position: const Vec2(1, 0));
      final v = FreePoint(id: 'v', position: const Vec2(0, 1));
      final e = FreePoint(id: 'e', position: const Vec2(-1, 0));
      final arc = Arc(id: 'arc', start: s, via: v, end: e);

      expect(arc.containsAngle(0), isTrue);
      expect(arc.containsAngle(math.pi / 2), isTrue);
      expect(arc.containsAngle(math.pi), isTrue);
      expect(arc.containsAngle(-math.pi / 2), isFalse);

      // Mirror arc: same endpoints, via below.
      final mirrored = Arc(
        id: 'arc2',
        start: s,
        via: FreePoint(id: 'v2', position: const Vec2(0, -1)),
        end: e,
      );
      expect(mirrored.containsAngle(-math.pi / 2), isTrue);
      expect(mirrored.containsAngle(math.pi / 2), isFalse);
    });

    test('angularExtent is a CCW span; clampAngle snaps outside angles '
        'to the nearer endpoint', () {
      final s = FreePoint(id: 's', position: const Vec2(1, 0));
      final e = FreePoint(id: 'e', position: const Vec2(-1, 0));
      final upper = Arc(
        id: 'up',
        start: s,
        via: FreePoint(id: 'v', position: const Vec2(0, 1)),
        end: e,
      );
      var (start, sweep) = upper.angularExtent!;
      expect(start, closeTo(0, 1e-9));
      expect(sweep, closeTo(math.pi, 1e-9));
      expect(upper.clampAngle(math.pi / 3), math.pi / 3,
          reason: 'inside angles pass through untouched');
      expect(upper.clampAngle(-math.pi / 4), closeTo(0, 1e-9));
      expect(upper.clampAngle(-3 * math.pi / 4), closeTo(math.pi, 1e-9));

      // The CW mirror stores a negative sweep; its extent starts at the
      // far endpoint so the span reads counter-clockwise regardless.
      final lower = Arc(
        id: 'down',
        start: s,
        via: FreePoint(id: 'v2', position: const Vec2(0, -1)),
        end: e,
      );
      (start, sweep) = lower.angularExtent!;
      expect(start, closeTo(-math.pi, 1e-9));
      expect(sweep, closeTo(math.pi, 1e-9));
      expect(lower.clampAngle(-math.pi / 2), -math.pi / 2);
      expect(lower.clampAngle(math.pi / 4), closeTo(0, 1e-9));
    });

    test('drag through collinearity: undefined, then recovers', () {
      final construction = Construction();
      final s = FreePoint(id: 's', position: const Vec2(0, 0));
      final v = FreePoint(id: 'v', position: const Vec2(2, 2));
      final e = FreePoint(id: 'e', position: const Vec2(4, 0));
      final arc = Arc(id: 'arc', start: s, via: v, end: e);
      construction
        ..add(s)
        ..add(v)
        ..add(e)
        ..add(arc);

      construction.moveFreePoint('v', const Vec2(2, 0));
      expect(arc.isDefined, isFalse);
      expect(arc.circle, isNull);
      expect(arc.sweep, isNull);
      expect(arc.containsAngle(0), isFalse);
      expect(arc.angularExtent, isNull);

      construction.moveFreePoint('v', const Vec2(2, 2));
      expect(arc.isDefined, isTrue);
      expect(arc.circle!.center.closeTo(const Vec2(2, 0)), isTrue);
    });

    test('dragging via across the chord flips the branch', () {
      final construction = Construction();
      final s = FreePoint(id: 's', position: const Vec2(1, 0));
      final v = FreePoint(id: 'v', position: const Vec2(0, 1));
      final e = FreePoint(id: 'e', position: const Vec2(-1, 0));
      final arc = Arc(id: 'arc', start: s, via: v, end: e);
      construction
        ..add(s)
        ..add(v)
        ..add(e)
        ..add(arc);

      expect(arc.sweep, greaterThan(0));
      construction.moveFreePoint('v', const Vec2(0, -1));
      expect(arc.sweep, lessThan(0));
    });
  });
}
