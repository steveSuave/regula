import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/diameter_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('DiameterCircle', () {
    test('centered on the midpoint, radius half the endpoint distance', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(6, 8));
      final circle = DiameterCircle(id: 'k', point1: a, point2: b);
      expect(circle.circle!.center, const Vec2(3, 4));
      expect(circle.circle!.radius, 5);
      expect(circle.parents, [a, b]);
    });

    test('passes through both endpoints (they span a diameter)', () {
      final a = FreePoint(id: 'a', position: const Vec2(-1, 2));
      final b = FreePoint(id: 'b', position: const Vec2(5, 7));
      final circle = DiameterCircle(id: 'k', point1: a, point2: b);
      expect(circle.circle!.distanceTo(a.position), lessThan(1e-9));
      expect(circle.circle!.distanceTo(b.position), lessThan(1e-9));
    });

    test('coincident endpoints give a defined zero-radius circle', () {
      final a = FreePoint(id: 'a', position: const Vec2(2, 3));
      final b = FreePoint(id: 'b', position: const Vec2(2, 3));
      final circle = DiameterCircle(id: 'k', point1: a, point2: b);
      expect(circle.isDefined, isTrue);
      expect(circle.circle!.radius, 0);
    });

    test('tracks a dragged endpoint', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final circle = DiameterCircle(id: 'k', point1: a, point2: b);
      b.position = const Vec2(0, 10);
      circle.recompute();
      expect(circle.circle!.center, const Vec2(0, 5));
      expect(circle.circle!.radius, 5);
    });
  });
}
