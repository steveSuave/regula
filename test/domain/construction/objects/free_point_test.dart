import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FreePoint', () {
    test('is a defined root with no parents', () {
      final p = FreePoint(id: 'p1', position: const Vec2(1, 2));
      expect(p.parents, isEmpty);
      expect(p.isDefined, isTrue);
      expect(p.position, const Vec2(1, 2));
    });

    test('position is mutable and recompute is a no-op', () {
      final p = FreePoint(id: 'p1', position: Vec2.zero);
      p.position = const Vec2(3, 4);
      p.recompute();
      expect(p.position, const Vec2(3, 4));
    });
  });
}
