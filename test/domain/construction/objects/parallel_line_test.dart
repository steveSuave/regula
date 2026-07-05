import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/parallel_line.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('ParallelLine', () {
    test('contains the through-point and is parallel to the reference', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 2));
      final ref = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(1, 5));
      final par = ParallelLine(id: 'k', through: p, reference: ref);

      expect(par.parents, [p, ref]);
      expect(par.line!.contains(p.position), isTrue);
      expect(par.line!.isParallelTo(ref.line!), isTrue);
      expect(par.line!.contains(a.position), isFalse,
          reason: 'a distinct parallel, not the reference itself');
    });

    test('a through-point on the reference yields the same (defined) line',
        () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 2));
      final ref = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final par = ParallelLine(id: 'k', through: a, reference: ref);

      expect(par.isDefined, isTrue);
      expect(par.line!.closeTo(ref.line!), isTrue);
    });

    test('reference degenerates (coincident points): undefined, then recovers',
        () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final ref = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(1, 5));
      final par = ParallelLine(id: 'k', through: p, reference: ref);
      construction
        ..add(a)
        ..add(b)
        ..add(ref)
        ..add(p)
        ..add(par);

      construction.moveFreePoint('b', const Vec2(0, 0));
      expect(par.isDefined, isFalse);
      expect(par.line, isNull);

      construction.moveFreePoint('b', const Vec2(0, 4));
      expect(par.isDefined, isTrue);
      expect(par.line!.contains(p.position), isTrue);
      expect(par.line!.isParallelTo(ref.line!), isTrue);
    });

    test('tracks a rotating reference', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final ref = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final p = FreePoint(id: 'p', position: const Vec2(1, 5));
      final par = ParallelLine(id: 'k', through: p, reference: ref);
      construction
        ..add(a)
        ..add(b)
        ..add(ref)
        ..add(p)
        ..add(par);

      construction.moveFreePoint('b', const Vec2(4, 4));
      expect(par.line!.contains(p.position), isTrue);
      expect(par.line!.isParallelTo(ref.line!), isTrue);
    });
  });
}
