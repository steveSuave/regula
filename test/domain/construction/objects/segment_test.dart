import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('Segment', () {
    test('exposes endpoints and a carrier line through both', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 4));
      final s = Segment(id: 's', point1: a, point2: b);
      expect(s.start, const Vec2(0, 0));
      expect(s.end, const Vec2(4, 4));
      expect(s.line!.contains(const Vec2(2, 2)), isTrue);
    });

    test('undefined while endpoints coincide, endpoints still readable', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 1));
      final s = Segment(id: 's', point1: a, point2: b);
      expect(s.isDefined, isFalse);
      expect(s.line, isNull);
      expect(s.start, const Vec2(1, 1));
      expect(s.end, const Vec2(1, 1));
      expect(s.parameterExtent, isNull);
    });

    test('parameterExtent spans the endpoints; clampParameter confines '
        'carrier parameters to it', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 0));
      final b = FreePoint(id: 'b', position: const Vec2(5, 0));
      final s = Segment(id: 's', point1: a, point2: b);

      final (min, max) = s.parameterExtent!;
      final line = s.line!;
      expect(min, line.parameterAt(const Vec2(1, 0)));
      expect(max, line.parameterAt(const Vec2(5, 0)));
      expect(min!, lessThan(max!), reason: 'bounds come out ordered');

      final inside = (min + max) / 2;
      expect(s.clampParameter(inside), inside,
          reason: 'inside parameters pass through untouched');
      expect(s.clampParameter(min - 3), min);
      expect(s.clampParameter(max + 3), max);

      // Swapped parents: bounds still ordered, spanning the same world
      // endpoints regardless of the carrier's orientation.
      final reversed = Segment(id: 'r', point1: b, point2: a);
      final (rMin, rMax) = reversed.parameterExtent!;
      expect(rMin!, lessThan(rMax!));
      final ends = [
        reversed.line!.pointAt(rMin),
        reversed.line!.pointAt(rMax),
      ];
      expect(ends.any((p) => p.closeTo(const Vec2(1, 0))), isTrue);
      expect(ends.any((p) => p.closeTo(const Vec2(5, 0))), isTrue);
    });
  });
}
