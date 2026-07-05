import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('AddObjectCommand', () {
    test('apply adds the object, undo removes it', () {
      final c = Construction();
      final cmd = AddObjectCommand(FreePoint(id: 'a', position: Vec2.zero));

      cmd.apply(c);
      expect(c.contains('a'), isTrue);

      cmd.undo(c);
      expect(c.isEmpty, isTrue);
    });

    test('apply recomputes a derived object on entry', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      c
        ..add(a)
        ..add(b);

      final m = Midpoint(id: 'm', point1: a, point2: b);
      AddObjectCommand(m).apply(c);
      expect(m.position, const Vec2(2, 0));
    });

    test('undo then apply restores the same state (redo)', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      c
        ..add(a)
        ..add(b);
      final cmd = AddObjectCommand(Midpoint(id: 'm', point1: a, point2: b));

      cmd.apply(c);
      cmd.undo(c);
      cmd.apply(c);

      final m = c.byId('m')! as Midpoint;
      expect(m.position, const Vec2(2, 0));
      expect(c.length, 3);

      // The re-added instance is the original, so dependents created after
      // a redo wire up against the same object the command first added.
      expect(identical(m, cmd.object), isTrue);
    });

    test('undo asserts when later-added dependents still exist', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final cmd = AddObjectCommand(a);
      cmd.apply(c);
      c
        ..add(b)
        ..add(Midpoint(id: 'm', point1: a, point2: b));

      // Undoing the add of `a` without first undoing the midpoint is a
      // stack-ordering bug; the command flags it in debug builds.
      expect(() => cmd.undo(c), throwsAssertionError);
    });
  });
}
