import 'package:fgex/domain/commands/translate_objects_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranslateObjectsCommand', () {
    test('apply shifts every point by delta and recomputes dependents', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(m);
      final cmd = TranslateObjectsCommand(
        pointIds: ['a', 'b'],
        delta: const Vec2(1, 2),
      );

      cmd.apply(c);
      expect(a.position, const Vec2(1, 2));
      expect(b.position, const Vec2(5, 2));
      // Rigid translation: the derived midpoint shifts by the same delta.
      expect(m.position, const Vec2(3, 2));
    });

    test('undo restores the original positions bit-for-bit', () {
      final c = Construction();
      // 0.1 + 0.2 is the classic non-associative float case: subtracting
      // the delta again would not return here, the stored snapshot must.
      final a = FreePoint(id: 'a', position: const Vec2(0.1, 0.1));
      c.add(a);
      final cmd = TranslateObjectsCommand(
        pointIds: ['a'],
        delta: const Vec2(0.2, 0.2),
      );

      cmd.apply(c);
      cmd.undo(c);
      expect(a.position, const Vec2(0.1, 0.1));
    });

    test('undo then apply restores the same state (redo)', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      c.add(a);
      final cmd = TranslateObjectsCommand(
        pointIds: ['a'],
        delta: const Vec2(-3, 7),
      );

      cmd.apply(c);
      final moved = a.position;
      cmd.undo(c);
      cmd.apply(c);
      expect(a.position, moved);
    });

    test('rejects non-free points before moving anything', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(m);
      final cmd = TranslateObjectsCommand(
        pointIds: ['a', 'm'],
        delta: const Vec2(1, 0),
      );

      expect(() => cmd.apply(c), throwsArgumentError);
      // Up-front validation: `a` (listed before the bad id) did not move.
      expect(a.position, Vec2.zero);
    });
  });
}
