import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/vertex_angle.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('VertexAngle', () {
    test('right angle: CCW from the first arm to the second', () {
      final a = FreePoint(id: 'a', position: const Vec2(3, 1));
      final v = FreePoint(id: 'v', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 4));
      final angle = VertexAngle(id: 'g', arm1: a, vertex: v, arm2: b);

      expect(angle.angle!.vertex, const Vec2(1, 1));
      expect(angle.angle!.startDirection.closeTo(const Vec2(1, 0)), isTrue);
      expect(angle.angle!.measure, closeTo(math.pi / 2, 1e-9));
      expect(angle.parents, [a, v, b]);
    });

    test('swapping the arms marks the complementary (reflex) angle', () {
      final a = FreePoint(id: 'a', position: const Vec2(3, 1));
      final v = FreePoint(id: 'v', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 4));
      final reflex = VertexAngle(id: 'g', arm1: b, vertex: v, arm2: a);

      expect(reflex.angle!.measure, closeTo(3 * math.pi / 2, 1e-9));
    });

    test('undefined while an arm sits on the vertex; recovers', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(3, 1));
      final v = FreePoint(id: 'v', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 4));
      final angle = VertexAngle(id: 'g', arm1: a, vertex: v, arm2: b);
      construction
        ..add(a)
        ..add(v)
        ..add(b)
        ..add(angle);

      construction.moveFreePoint('a', const Vec2(1, 1));
      expect(angle.isDefined, isFalse);
      expect(angle.angle, isNull);

      construction.moveFreePoint('a', const Vec2(3, 1));
      expect(angle.isDefined, isTrue);
      expect(angle.angle!.measure, closeTo(math.pi / 2, 1e-9));
    });

    test('the measure follows a dragged arm', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(1, 0));
      final v = FreePoint(id: 'v', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(0, 1));
      final angle = VertexAngle(id: 'g', arm1: a, vertex: v, arm2: b);
      construction
        ..add(a)
        ..add(v)
        ..add(b)
        ..add(angle);

      construction.moveFreePoint('b', const Vec2(-1, 1));
      expect(angle.angle!.measure, closeTo(3 * math.pi / 4, 1e-9));
    });
  });
}
