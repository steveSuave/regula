import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/centroid.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Centroid', () {
    test('computes (a + b + c) / 3 on construction', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      final g = Centroid(id: 'g', vertex1: a, vertex2: b, vertex3: c);
      expect(g.position!.closeTo(const Vec2(4 / 3, 1)), isTrue);
      expect(g.parents, [a, b, c]);
    });

    test('collinear and coincident vertices are not degenerate', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(1, 1));
      final c = FreePoint(id: 'c', position: const Vec2(2, 2));
      final g = Centroid(id: 'g', vertex1: a, vertex2: b, vertex3: c);
      expect(g.isDefined, isTrue);
      expect(g.position!.closeTo(const Vec2(1, 1)), isTrue);

      b.position = const Vec2(0, 0);
      c.position = const Vec2(0, 0);
      g.recompute();
      expect(g.isDefined, isTrue);
      expect(g.position!.closeTo(const Vec2(0, 0)), isTrue);
    });

    test('tracks a dragged vertex through the construction', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(6, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 6));
      final g = Centroid(id: 'g', vertex1: a, vertex2: b, vertex3: c);
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(g);

      construction.moveFreePoint('c', const Vec2(3, 9));
      expect(g.position!.closeTo(const Vec2(3, 3)), isTrue);
    });
  });
}
