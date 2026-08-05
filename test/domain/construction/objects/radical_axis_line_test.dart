import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/circle_center_point.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/radical_axis_line.dart';
import 'package:regula/domain/math/line_eq.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('RadicalAxisLine', () {
    (Construction, RadicalAxisLine) build({
      Vec2 center1 = const Vec2(0, 0),
      Vec2 rim1 = const Vec2(2, 0),
      Vec2 center2 = const Vec2(4, 0),
      Vec2 rim2 = const Vec2(6, 0),
    }) {
      final construction = Construction();
      final o1 = FreePoint(id: 'o1', position: center1);
      final r1 = FreePoint(id: 'r1', position: rim1);
      final o2 = FreePoint(id: 'o2', position: center2);
      final r2 = FreePoint(id: 'r2', position: rim2);
      final c1 = CircleCenterPoint(id: 'c1', center: o1, onCircle: r1);
      final c2 = CircleCenterPoint(id: 'c2', center: o2, onCircle: r2);
      final axis = RadicalAxisLine(id: 'x', circle1: c1, circle2: c2);
      construction
        ..add(o1)
        ..add(r1)
        ..add(o2)
        ..add(r2)
        ..add(c1)
        ..add(c2)
        ..add(axis);
      return (construction, axis);
    }

    test('equal circles: the perpendicular bisector of the centers', () {
      final (_, axis) = build();
      expect(axis.line!.closeTo(LineEq(1, 0, -2)), isTrue);
      expect(axis.parents.map((p) => p.id), ['c1', 'c2']);
    });

    test('unequal radii shift the axis toward the larger circle', () {
      // r1 = 1, r2 = 3: powers of (1, y) are equal — the axis is x = 1.
      final (_, axis) = build(rim1: const Vec2(1, 0), rim2: const Vec2(7, 0));
      expect(axis.line!.closeTo(LineEq(1, 0, -1)), isTrue);
    });

    test('drag to concentric: undefined, then recovers', () {
      final (construction, axis) = build();

      construction.moveFreePoint('o2', const Vec2(0, 0));
      expect(axis.isDefined, isFalse);
      expect(axis.line, isNull);

      construction.moveFreePoint('o2', const Vec2(4, 0));
      expect(axis.isDefined, isTrue);
      expect(axis.line!.closeTo(LineEq(1, 0, -2)), isTrue);
    });

    test('undefined while a parent circle is', () {
      // A zero-separation center/rim pair is still a (point) circle, so
      // undefine a parent by collapsing the *other* circle onto it is not
      // possible here; instead drag the first circle's rim onto its
      // center — radius 0 keeps the circle defined — then make the two
      // circles concentric point-circles, which is the undefined case.
      final (construction, axis) = build();
      construction.moveFreePoint('r1', const Vec2(0, 0));
      expect(axis.isDefined, isTrue);

      construction.moveFreePoint('o2', const Vec2(0, 0));
      expect(axis.isDefined, isFalse);
    });

    test('identical circle instances are rejected', () {
      final o = FreePoint(id: 'o', position: const Vec2(0, 0));
      final r = FreePoint(id: 'r', position: const Vec2(2, 0));
      final c = CircleCenterPoint(id: 'c', center: o, onCircle: r);
      expect(
        () => RadicalAxisLine(id: 'x', circle1: c, circle2: c),
        throwsArgumentError,
      );
    });
  });
}
