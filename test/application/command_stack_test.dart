import 'package:fgex/application/command_stack.dart';
import 'package:fgex/domain/commands/add_object_command.dart';
import 'package:fgex/domain/commands/delete_objects_command.dart';
import 'package:fgex/domain/commands/move_free_point_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandStack', () {
    test('execute applies and enables undo; undo enables redo', () {
      final c = Construction();
      final stack = CommandStack(c);
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);

      stack.execute(AddObjectCommand(FreePoint(id: 'a', position: Vec2.zero)));
      expect(c.contains('a'), isTrue);
      expect(stack.canUndo, isTrue);
      expect(stack.canRedo, isFalse);

      stack.undo();
      expect(c.isEmpty, isTrue);
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isTrue);

      stack.redo();
      expect(c.contains('a'), isTrue);
      expect(stack.canUndo, isTrue);
      expect(stack.canRedo, isFalse);
    });

    test('a full session round-trips: undo everything, redo everything', () {
      final c = Construction();
      final stack = CommandStack(c);
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      stack
        ..execute(AddObjectCommand(a))
        ..execute(AddObjectCommand(b))
        ..execute(AddObjectCommand(Midpoint(id: 'm', point1: a, point2: b)))
        ..execute(
          MoveFreePointCommand(
            pointId: 'a',
            from: Vec2.zero,
            to: const Vec2(2, 2),
          ),
        )
        ..execute(DeleteObjectsCommand(['b']));
      expect(c.objects.map((o) => o.id), ['a']);

      while (stack.canUndo) {
        stack.undo();
      }
      expect(c.isEmpty, isTrue);

      while (stack.canRedo) {
        stack.redo();
      }
      expect(c.objects.map((o) => o.id), ['a']);
      expect((c.byId('a')! as FreePoint).position, const Vec2(2, 2));
    });

    test('executing a new command clears the redo stack', () {
      final c = Construction();
      final stack = CommandStack(c);
      stack.execute(AddObjectCommand(FreePoint(id: 'a', position: Vec2.zero)));
      stack.undo();
      expect(stack.canRedo, isTrue);

      stack.execute(AddObjectCommand(FreePoint(id: 'b', position: Vec2.zero)));
      expect(stack.canRedo, isFalse);
      expect(stack.canUndo, isTrue);
    });

    test('a failed apply records nothing', () {
      final c = Construction();
      final stack = CommandStack(c);
      // Moving a point that does not exist throws inside apply.
      expect(
        () => stack.execute(
          MoveFreePointCommand(
            pointId: 'ghost',
            from: Vec2.zero,
            to: const Vec2(1, 1),
          ),
        ),
        throwsArgumentError,
      );
      expect(stack.canUndo, isFalse);
    });

    test('undo/redo on empty stacks throw, clear forgets history', () {
      final c = Construction();
      final stack = CommandStack(c);
      expect(stack.undo, throwsStateError);
      expect(stack.redo, throwsStateError);

      stack.execute(AddObjectCommand(FreePoint(id: 'a', position: Vec2.zero)));
      stack.clear();
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
      // The construction itself is untouched by clear().
      expect(c.contains('a'), isTrue);
    });
  });
}
