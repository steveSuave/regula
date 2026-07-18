import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/objects/circle_center_point.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('CircleCenterPoint', () {
    test('circle is centered on the first parent through the second', () {
      final c = FreePoint(id: 'c', position: const Vec2(1, 1));
      final p = FreePoint(id: 'p', position: const Vec2(4, 5));
      final circle = CircleCenterPoint(id: 'k', center: c, onCircle: p);
      expect(circle.circle!.center, const Vec2(1, 1));
      expect(circle.circle!.radius, 5);
    });

    test('coincident parents give a defined zero-radius circle', () {
      final c = FreePoint(id: 'c', position: const Vec2(2, 3));
      final p = FreePoint(id: 'p', position: const Vec2(2, 3));
      final circle = CircleCenterPoint(id: 'k', center: c, onCircle: p);
      expect(circle.isDefined, isTrue);
      expect(circle.circle!.radius, 0);
    });

    test('a full circle offers the whole turn: no angular extent, '
        'clampAngle passes through', () {
      final c = FreePoint(id: 'c', position: Vec2.zero);
      final p = FreePoint(id: 'p', position: const Vec2(2, 0));
      final circle = CircleCenterPoint(id: 'k', center: c, onCircle: p);
      expect(circle.angularExtent, isNull);
      expect(circle.clampAngle(5.87), 5.87);
    });

    test('radius tracks a dragged perimeter point', () {
      final c = FreePoint(id: 'c', position: Vec2.zero);
      final p = FreePoint(id: 'p', position: const Vec2(2, 0));
      final circle = CircleCenterPoint(id: 'k', center: c, onCircle: p);
      p.position = const Vec2(0, 7);
      circle.recompute();
      expect(circle.circle!.radius, 7);
    });
  });
}
