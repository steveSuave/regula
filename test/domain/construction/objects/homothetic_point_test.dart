import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/homothetic_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('HomotheticPoint', () {
    test('scales about the center on construction', () {
      final p = FreePoint(id: 'p', position: const Vec2(3, 1));
      final c = FreePoint(id: 'c', position: const Vec2(1, 1));
      final h = HomotheticPoint(id: 'h', point: p, center: c, ratio: 2);
      expect(h.position!.closeTo(const Vec2(5, 1)), isTrue);
      expect(h.parents, [p, c]);
    });

    test('a negative ratio lands on the far side of the center', () {
      final p = FreePoint(id: 'p', position: const Vec2(4, 2));
      final c = FreePoint(id: 'c', position: Vec2.zero);
      final h = HomotheticPoint(id: 'h', point: p, center: c, ratio: -0.5);
      expect(h.position!.closeTo(const Vec2(-2, -1)), isTrue);
    });

    test('ratio 1 is the identity, ratio 0 is the center itself', () {
      final p = FreePoint(id: 'p', position: const Vec2(4, 2));
      final c = FreePoint(id: 'c', position: const Vec2(1, -1));
      expect(
        HomotheticPoint(id: 'h1', point: p, center: c, ratio: 1)
            .position!
            .closeTo(p.position),
        isTrue,
      );
      expect(
        HomotheticPoint(id: 'h0', point: p, center: c, ratio: 0)
            .position!
            .closeTo(c.position),
        isTrue,
      );
    });

    test('a point on the center maps to itself', () {
      final p = FreePoint(id: 'p', position: const Vec2(2, 2));
      final c = FreePoint(id: 'c', position: const Vec2(2, 2));
      final h = HomotheticPoint(id: 'h', point: p, center: c, ratio: 3);
      expect(h.position!.closeTo(const Vec2(2, 2)), isTrue);
    });

    test('tracks moved parents after recompute', () {
      final p = FreePoint(id: 'p', position: const Vec2(3, 0));
      final c = FreePoint(id: 'c', position: Vec2.zero);
      final h = HomotheticPoint(id: 'h', point: p, center: c, ratio: 2);

      p.position = const Vec2(0, 3);
      h.recompute();
      expect(h.position!.closeTo(const Vec2(0, 6)), isTrue);

      c.position = const Vec2(0, 3);
      h.recompute();
      expect(h.position!.closeTo(const Vec2(0, 3)), isTrue,
          reason: 'point on the center maps to itself');
    });

    test('undefined while a parent is, recovers after', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: Vec2.zero); // coincident
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final onLine = PointOnObject(id: 'q', curve: line, parameter: 2);
      final c = FreePoint(id: 'c', position: const Vec2(1, 1));
      final h = HomotheticPoint(id: 'h', point: onLine, center: c, ratio: 2);
      expect(h.isDefined, isFalse);

      b.position = const Vec2(1, 0); // line and onLine come back: (2, 0)
      line.recompute();
      onLine.recompute();
      h.recompute();
      expect(h.isDefined, isTrue);
      expect(h.position!.closeTo(const Vec2(3, -1)), isTrue);
    });

    test('rejects a non-finite ratio', () {
      final p = FreePoint(id: 'p', position: const Vec2(3, 0));
      final c = FreePoint(id: 'c', position: Vec2.zero);
      expect(
        () => HomotheticPoint(
            id: 'h', point: p, center: c, ratio: double.nan),
        throwsArgumentError,
      );
      expect(
        () => HomotheticPoint(
            id: 'h', point: p, center: c, ratio: double.infinity),
        throwsArgumentError,
      );
    });
  });
}
