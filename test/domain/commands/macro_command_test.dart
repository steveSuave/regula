import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/commands/macro_command.dart';
import 'package:regula/domain/commands/move_free_point_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/math/vec2.dart';

void main() {
  group('MacroCommand', () {
    /// Children build on each other: the midpoint depends on points the
    /// earlier children add, so apply order and reverse undo order are
    /// both load-bearing.
    MacroCommand buildMacro() {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      return MacroCommand([
        AddObjectCommand(a),
        AddObjectCommand(b),
        AddObjectCommand(Midpoint(id: 'm', point1: a, point2: b)),
      ]);
    }

    test('apply runs children in order, undo unwinds them in reverse', () {
      final c = Construction();
      final macro = buildMacro();

      macro.apply(c);
      expect(c.objects.map((o) => o.id), ['a', 'b', 'm']);
      expect((c.byId('m')! as Midpoint).position, const Vec2(2, 0));

      // Forward-order undo would trip AddObjectCommand's dependents
      // assert on `a`; reverse order removes the midpoint first.
      macro.undo(c);
      expect(c.isEmpty, isTrue);
    });

    test('undo then apply restores the same state (redo)', () {
      final c = Construction();
      final macro = buildMacro();

      macro.apply(c);
      macro.undo(c);
      macro.apply(c);
      expect(c.length, 3);
      expect((c.byId('m')! as Midpoint).position, const Vec2(2, 0));
    });

    test('macros nest', () {
      final c = Construction();
      final inner = buildMacro();
      final outer = MacroCommand([
        inner,
        MoveFreePointCommand(
          pointId: 'a',
          from: Vec2.zero,
          to: const Vec2(2, 2),
        ),
      ]);

      outer.apply(c);
      expect((c.byId('m')! as Midpoint).position, const Vec2(3, 1));

      outer.undo(c);
      expect(c.isEmpty, isTrue);
    });
  });
}
