import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('LineThroughTwoPoints', () {
    test('line contains both defining points', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 1));
      final b = FreePoint(id: 'b', position: const Vec2(3, 4));
      final l = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      expect(l.isDefined, isTrue);
      expect(l.line!.contains(a.position), isTrue);
      expect(l.line!.contains(b.position), isTrue);
    });

    test('undefined while points coincide, recovers when they separate', () {
      final a = FreePoint(id: 'a', position: const Vec2(2, 2));
      final b = FreePoint(id: 'b', position: const Vec2(5, 2));
      final l = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      expect(l.isDefined, isTrue);

      b.position = const Vec2(2, 2); // drag onto a: degenerate
      l.recompute();
      expect(l.isDefined, isFalse);
      expect(l.line, isNull);

      b.position = const Vec2(2, 7); // drag away: defined again
      l.recompute();
      expect(l.isDefined, isTrue);
      expect(l.line!.contains(const Vec2(2, 5)), isTrue);
    });
  });
}
