import 'package:fgex/domain/commands/delete_objects_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeleteObjectsCommand', () {
    /// a, b free; m = midpoint(a, b); l = line(a, m).
    Construction buildChain() {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(m)
        ..add(LineThroughTwoPoints(id: 'l', point1: a, point2: m));
      return c;
    }

    test('apply cascades to dependents, undo restores them all', () {
      final c = buildChain();
      final cmd = DeleteObjectsCommand(['m']);

      cmd.apply(c);
      expect(c.objects.map((o) => o.id), ['a', 'b']);

      cmd.undo(c);
      expect(c.length, 4);
      final m = c.byId('m')! as Midpoint;
      expect(m.position, const Vec2(2, 0));

      // The restored graph is still live: dragging propagates through it.
      c.moveFreePoint('b', const Vec2(8, 0));
      expect(m.position, const Vec2(4, 0));
    });

    test('undo restores cross-batch dependencies in a valid order', () {
      final c = buildChain();
      // Deleting `a` sweeps m and l with it; `b` is removed in a second
      // batch. Undo must restore b *before* m (m's parent), which forces
      // the reverse-batch-order restore.
      final cmd = DeleteObjectsCommand(['a', 'b']);

      cmd.apply(c);
      expect(c.isEmpty, isTrue);

      cmd.undo(c);
      expect(c.length, 4);
      expect((c.byId('m')! as Midpoint).position, const Vec2(2, 0));
    });

    test('skips ids already swept away by an earlier cascade', () {
      final c = buildChain();
      // `m` dies in a's cascade before its own turn comes up.
      final cmd = DeleteObjectsCommand(['a', 'm']);

      cmd.apply(c);
      expect(c.objects.map((o) => o.id), ['b']);

      cmd.undo(c);
      expect(c.length, 4);
    });

    test('redo recaptures: apply-undo-apply-undo round-trips', () {
      final c = buildChain();
      final cmd = DeleteObjectsCommand(['a']);

      cmd.apply(c);
      cmd.undo(c);
      cmd.apply(c);
      expect(c.objects.map((o) => o.id), ['b']);

      cmd.undo(c);
      expect(c.length, 4);
      expect((c.byId('m')! as Midpoint).position, const Vec2(2, 0));
    });
  });
}
