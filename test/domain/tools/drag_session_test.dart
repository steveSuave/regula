import 'package:fgex/domain/commands/move_free_point_command.dart';
import 'package:fgex/domain/commands/translate_objects_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/drag_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Construction construction;
  late FreePoint a;
  late FreePoint b;
  late Segment segment;
  late Midpoint midpoint;

  setUp(() {
    construction = Construction();
    a = FreePoint(id: 'a', position: Vec2.zero);
    b = FreePoint(id: 'b', position: const Vec2(4, 0));
    segment = Segment(id: 's', point1: a, point2: b);
    midpoint = Midpoint(id: 'm', point1: a, point2: b);
    construction
      ..add(a)
      ..add(b)
      ..add(segment)
      ..add(midpoint);
  });

  group('DragSession.start', () {
    test('refuses derived points', () {
      expect(DragSession.start(construction, midpoint, Vec2.zero), isNull);
    });

    test('accepts free points and derived non-points', () {
      expect(DragSession.start(construction, a, Vec2.zero), isNotNull);
      expect(
        DragSession.start(construction, segment, const Vec2(2, 0)),
        isNotNull,
      );
    });
  });

  group('free-point drag', () {
    test('previews per frame, ends with one MoveFreePointCommand', () {
      final session = DragSession.start(construction, a, Vec2.zero)!;

      session.update(const Vec2(1, 1));
      expect(a.position, const Vec2(1, 1));
      expect(midpoint.position, const Vec2(2.5, 0.5),
          reason: 'dependents recompute per preview frame');

      session.update(const Vec2(2, 3));
      final command = session.end()!;

      expect(a.position, Vec2.zero,
          reason: 'end rolls the preview back — the command replays it');
      expect(command, isA<MoveFreePointCommand>());
      command.apply(construction);
      expect(a.position, const Vec2(2, 3));
      expect(midpoint.position, const Vec2(3, 1.5));
      command.undo(construction);
      expect(a.position, Vec2.zero);
    });

    test('the delta rides the pointer, not the grab point', () {
      // Grabbed 0.5 away from the point's center: the point must move by
      // the pointer's delta, not jump under the cursor.
      final session =
          DragSession.start(construction, a, const Vec2(0.5, 0))!;
      session.update(const Vec2(1.5, 2));
      expect(a.position, const Vec2(1, 2));
      session.cancel();
      expect(a.position, Vec2.zero);
    });

    test('zero-delta gesture ends with no command', () {
      final session = DragSession.start(construction, a, Vec2.zero)!;
      expect(session.end(), isNull);

      final grabbed = DragSession.start(construction, a, Vec2.zero)!;
      grabbed.update(const Vec2(1, 0));
      grabbed.update(Vec2.zero); // dragged back home
      expect(grabbed.end(), isNull);
      expect(a.position, Vec2.zero);
    });
  });

  group('derived-object drag', () {
    test('rigidly translates the free ancestors, one command', () {
      final session =
          DragSession.start(construction, segment, const Vec2(2, 0))!;

      session.update(const Vec2(3, 2));
      expect(a.position, const Vec2(1, 2));
      expect(b.position, const Vec2(5, 2));
      expect(midpoint.position, const Vec2(3, 2),
          reason: 'the whole configuration translates rigidly');

      final command = session.end()!;
      expect(a.position, Vec2.zero);
      expect(b.position, const Vec2(4, 0));
      expect(command, isA<TranslateObjectsCommand>());

      command.apply(construction);
      expect(a.position, const Vec2(1, 2));
      expect(b.position, const Vec2(5, 2));
      command.undo(construction);
      expect(a.position, Vec2.zero);
      expect(b.position, const Vec2(4, 0));
    });

    test('cancel rolls the preview back', () {
      final session =
          DragSession.start(construction, segment, const Vec2(2, 0))!;
      session.update(const Vec2(7, -3));
      session.cancel();
      expect(a.position, Vec2.zero);
      expect(b.position, const Vec2(4, 0));
    });

    test('rollback skips points removed mid-session instead of throwing',
        () {
      final session =
          DragSession.start(construction, segment, const Vec2(2, 0))!;
      session.update(const Vec2(3, 1));

      // An undo mid-drag can delete a dragged point (and its dependents).
      construction.removeWithDependents('a');

      session.cancel();
      expect(b.position, const Vec2(4, 0),
          reason: 'the surviving point still rolls back');
    });
  });
}
