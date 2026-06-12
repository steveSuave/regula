import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

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
    });
  });
}
