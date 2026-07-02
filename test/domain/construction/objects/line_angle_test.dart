import 'dart:math' as math;

import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_angle.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineAngle', () {
    test('marks the acute angle at the crossing', () {
      final o = FreePoint(id: 'o', position: Vec2.zero);
      final x = FreePoint(id: 'x', position: const Vec2(4, 0));
      final d = FreePoint(id: 'd', position: const Vec2(1, 1));
      final l1 = LineThroughTwoPoints(id: 'l1', point1: o, point2: x);
      final l2 = LineThroughTwoPoints(id: 'l2', point1: o, point2: d);
      final angle = LineAngle(id: 'g', line1: l1, line2: l2);

      expect(angle.angle!.vertex.closeTo(Vec2.zero), isTrue);
      expect(angle.angle!.measure, closeTo(math.pi / 4, 1e-9));
      expect(angle.parents, [l1, l2]);
    });

    test('is order-independent and never obtuse', () {
      final o = FreePoint(id: 'o', position: Vec2.zero);
      final x = FreePoint(id: 'x', position: const Vec2(4, 0));
      // Direction 120° from the x-axis: the lines cross at 60°.
      final d = FreePoint(id: 'd', position: const Vec2(-1, 1.7320508));
      final l1 = LineThroughTwoPoints(id: 'l1', point1: o, point2: x);
      final l2 = LineThroughTwoPoints(id: 'l2', point1: o, point2: d);

      final ab = LineAngle(id: 'g1', line1: l1, line2: l2);
      final ba = LineAngle(id: 'g2', line1: l2, line2: l1);
      expect(ab.angle!.measure, closeTo(math.pi / 3, 1e-6));
      expect(ba.angle!.measure, closeTo(math.pi / 3, 1e-6));
    });

    test('segments work through their carriers, vertex beyond the extents',
        () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(2, 2));
      final c = FreePoint(id: 'c', position: const Vec2(1, -1));
      final d = FreePoint(id: 'd', position: const Vec2(2, -2));
      final s1 = Segment(id: 's1', point1: a, point2: b);
      final s2 = Segment(id: 's2', point1: c, point2: d);
      final angle = LineAngle(id: 'g', line1: s1, line2: s2);

      expect(angle.angle!.vertex.closeTo(Vec2.zero), isTrue);
      expect(angle.angle!.measure, closeTo(math.pi / 2, 1e-9));
    });

    test('undefined while parallel; recovers when the crossing returns', () {
      final construction = Construction();
      final o = FreePoint(id: 'o', position: Vec2.zero);
      final x = FreePoint(id: 'x', position: const Vec2(4, 0));
      final p = FreePoint(id: 'p', position: const Vec2(0, 1));
      final q = FreePoint(id: 'q', position: const Vec2(4, 2));
      final l1 = LineThroughTwoPoints(id: 'l1', point1: o, point2: x);
      final l2 = LineThroughTwoPoints(id: 'l2', point1: p, point2: q);
      final angle = LineAngle(id: 'g', line1: l1, line2: l2);
      construction
        ..add(o)
        ..add(x)
        ..add(p)
        ..add(q)
        ..add(l1)
        ..add(l2)
        ..add(angle);

      expect(angle.isDefined, isTrue);

      construction.moveFreePoint('q', const Vec2(4, 1));
      expect(angle.isDefined, isFalse);
      expect(angle.angle, isNull);

      construction.moveFreePoint('q', const Vec2(4, 2));
      expect(angle.isDefined, isTrue);
    });

    test('undefined while a parent line is undefined', () {
      final o = FreePoint(id: 'o', position: Vec2.zero);
      final x = FreePoint(id: 'x', position: Vec2.zero); // coincident
      final p = FreePoint(id: 'p', position: const Vec2(0, 1));
      final q = FreePoint(id: 'q', position: const Vec2(4, 2));
      final broken = LineThroughTwoPoints(id: 'l1', point1: o, point2: x);
      final l2 = LineThroughTwoPoints(id: 'l2', point1: p, point2: q);

      expect(LineAngle(id: 'g', line1: broken, line2: l2).isDefined, isFalse);
    });
  });
}
