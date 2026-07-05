import 'package:glados/glados.dart';
import 'package:regula/domain/math/angle_bisector.dart';
import 'package:regula/domain/math/line_eq.dart';
import 'package:regula/domain/math/vec2.dart';

import 'generators.dart';

void main() {
  group('angleBisector', () {
    test('right angle at the origin: y = x', () {
      final bisector = angleBisector(
        const Vec2(5, 0),
        Vec2.zero,
        const Vec2(0, 5),
      )!;
      expect(
        bisector.closeTo(LineEq.throughPoints(Vec2.zero, const Vec2(1, 1))),
        isTrue,
      );
    });

    test('arm distance does not matter', () {
      final near = angleBisector(
        const Vec2(1, 0),
        Vec2.zero,
        const Vec2(0, 1),
      )!;
      final far = angleBisector(
        const Vec2(1000, 0),
        Vec2.zero,
        const Vec2(0, 0.001),
      )!;
      expect(near.closeTo(far, 1e-6), isTrue);
    });

    test('opposite rays: the perpendicular at the vertex', () {
      final bisector = angleBisector(
        const Vec2(-3, 2),
        const Vec2(1, 2),
        const Vec2(7, 2),
      )!;
      expect(bisector.contains(const Vec2(1, 2)), isTrue);
      expect(bisector.contains(const Vec2(1, 100)), isTrue);
    });

    test('arms on the same ray: the ray itself', () {
      final bisector = angleBisector(
        const Vec2(2, 2),
        Vec2.zero,
        const Vec2(5, 5),
      )!;
      expect(
        bisector.closeTo(LineEq.throughPoints(Vec2.zero, const Vec2(1, 1))),
        isTrue,
      );
    });

    test('an arm coincident with the vertex: null', () {
      expect(angleBisector(Vec2.zero, Vec2.zero, const Vec2(1, 0)), isNull);
      expect(angleBisector(const Vec2(1, 0), Vec2.zero, Vec2.zero), isNull);
    });

    Glados3(any.vec2, any.vec2, any.vec2).test(
        'contains the vertex and is equidistant from equal-length arm marks',
        (arm1, vertex, arm2) {
      final bisector = angleBisector(arm1, vertex, arm2);
      if (bisector == null) {
        return; // an arm sat (nearly) on the vertex — nothing to check
      }
      expect(bisector.distanceTo(vertex), lessThan(1e-6));
      // The defining property: points at equal arc length along either arm
      // are equidistant from the bisector.
      final u = (arm1 - vertex).normalized();
      final v = (arm2 - vertex).normalized();
      expect(
        bisector.distanceTo(vertex + u),
        closeTo(bisector.distanceTo(vertex + v), 1e-6),
      );
    });

    Glados2(any.vec2, any.vec2).test('symmetric in its arms', (arm1, arm2) {
      final forward = angleBisector(arm1, Vec2.zero, arm2);
      final backward = angleBisector(arm2, Vec2.zero, arm1);
      if (forward == null || backward == null) {
        expect(forward, backward);
        return;
      }
      expect(forward.closeTo(backward, 1e-6), isTrue);
    });
  });
}
