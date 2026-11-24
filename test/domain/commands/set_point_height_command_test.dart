import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/set_point_height_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';

void main() {
  group('SetPointHeightCommand', () {
    late Construction c;
    late FreePoint a;
    late Segment s;

    setUp(() {
      c = Construction();
      a = FreePoint(id: 'a', position: const Vec2(1, 2));
      final b = FreePoint(id: 'b', position: const Vec2(5, 2));
      s = Segment(id: 's', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(s);
    });

    test('apply lifts, undo returns, and the foot does not move', () {
      final cmd = SetPointHeightCommand(pointId: 'a', from: 0, to: 3);

      cmd.apply(c);
      expect(a.height, 3);
      expect(a.chartPosition, const Vec2(1, 2));
      expect(a.spacePosition, const Vec3(1, 2, 3));
      expect(s.hasSpaceExtent, isTrue);

      cmd.undo(c);
      expect(a.height, 0);
      expect(a.position, const Vec2(1, 2));
      expect(s.line, isNotNull);

      cmd.apply(c);
      expect(a.spacePosition, const Vec3(1, 2, 3));
    });

    test('each of apply and undo notifies once', () {
      var notified = 0;
      c.addListener(() => notified++);
      final cmd = SetPointHeightCommand(pointId: 'a', from: 0, to: 3)..apply(c);
      expect(notified, 1);
      cmd.undo(c);
      expect(notified, 2);
    });
  });
}
