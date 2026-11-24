import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/set_point_height_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/lift_session.dart';

void main() {
  late Construction c;
  late FreePoint a;
  late Midpoint m;

  setUp(() {
    c = Construction();
    a = FreePoint(id: 'a', position: Vec2.zero);
    final b = FreePoint(id: 'b', position: const Vec2(4, 0));
    m = Midpoint(id: 'm', point1: a, point2: b);
    c
      ..add(a)
      ..add(b)
      ..add(m);
  });

  test('previews move the point and its dependents', () {
    final session = LiftSession(c, a)
      ..update(2)
      ..update(6);
    expect(session.height, 6);
    expect(a.height, 6);
    expect(m.spacePosition, const Vec3(2, 0, 3));
  });

  test('end rolls the preview back and returns the one command', () {
    final session = LiftSession(c, a)..update(6);
    final command = session.end()! as SetPointHeightCommand;
    expect(a.height, 0);
    expect((command.from, command.to), (0.0, 6.0));
    command.apply(c);
    expect(a.height, 6);
    command.undo(c);
    expect(a.height, 0);
    expect(m.position, const Vec2(2, 0));
  });

  test('a gesture that ends where it began is no command', () {
    final session = LiftSession(c, a)
      ..update(6)
      ..update(0);
    expect(session.end(), isNull);
    expect(a.height, 0);
  });

  test('a lift of an already lifted point starts from its height', () {
    c.setFreePointHeight('a', 3);
    final session = LiftSession(c, a)..update(-1);
    final command = session.end()! as SetPointHeightCommand;
    expect((command.from, command.to), (3.0, -1.0));
    expect(a.height, 3);
  });

  test('cancel restores the height and notifies no more than it must', () {
    final session = LiftSession(c, a)..update(6);
    var notified = 0;
    c.addListener(() => notified++);
    session.cancel();
    expect(a.height, 0);
    expect(notified, 1);
    session.cancel();
    expect(notified, 1);
  });

  test('a session whose point has left the construction is inert', () {
    final session = LiftSession(c, a)..update(6);
    c.removeWithDependents('a');
    session
      ..update(9)
      ..cancel();
    expect(session.end(), isNull);
  });
}
