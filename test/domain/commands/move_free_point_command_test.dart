import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/move_free_point_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('MoveFreePointCommand', () {
    test('apply moves the point to `to`, undo back to `from`', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      c.add(a);
      final cmd = MoveFreePointCommand(
        pointId: 'a',
        from: Vec2.zero,
        to: const Vec2(3, 4),
      );

      cmd.apply(c);
      expect(a.position, const Vec2(3, 4));

      cmd.undo(c);
      expect(a.position, Vec2.zero);
    });

    test('apply and undo both recompute transitive dependents', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      final m2 = Midpoint(id: 'm2', point1: m, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(m)
        ..add(m2);
      final cmd = MoveFreePointCommand(
        pointId: 'a',
        from: Vec2.zero,
        to: const Vec2(8, 4),
      );

      cmd.apply(c);
      expect(m.position, const Vec2(6, 2));
      expect(m2.position, const Vec2(5, 1));

      cmd.undo(c);
      expect(m.position, const Vec2(2, 0));
      expect(m2.position, const Vec2(3, 0));
    });

    test('undo then apply restores the same state (redo)', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      c.add(a);
      final cmd = MoveFreePointCommand(
        pointId: 'a',
        from: const Vec2(1, 1),
        to: const Vec2(-2, 5),
      );

      cmd.apply(c);
      cmd.undo(c);
      cmd.apply(c);
      expect(a.position, const Vec2(-2, 5));
    });

    test('throws on a non-free point', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(m);
      final cmd = MoveFreePointCommand(
        pointId: 'm',
        from: const Vec2(2, 0),
        to: const Vec2(3, 0),
      );

      expect(() => cmd.apply(c), throwsArgumentError);
    });
  });
}
