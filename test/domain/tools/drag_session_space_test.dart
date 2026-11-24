// Intent 004, milestone 2: a drag of a lifted point, at the session
// level — the command path enforces the engine's invariants again, so
// the engine alone is not the proof.

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/move_free_point_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/compass_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/intersection_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/drag_session.dart';

void main() {
  late Construction c;
  late FreePoint a;
  late FreePoint apex;
  late Segment edge;
  late Midpoint mid;

  setUp(() {
    c = Construction();
    a = FreePoint(id: 'a', position: Vec2.zero);
    apex = FreePoint(id: 'o', position: const Vec2(4, 0), height: 6);
    edge = Segment(id: 's', point1: a, point2: apex);
    mid = Midpoint(id: 'm', point1: a, point2: apex);
    c
      ..add(a)
      ..add(apex)
      ..add(edge)
      ..add(mid);
  });

  test('a lifted point drags parallel to its plane and keeps its height', () {
    final session = DragSession.start(c, apex, const Vec2(4, 0))!;
    session.update(const Vec2(5, 1));
    session.update(const Vec2(7, 3));
    expect(apex.spacePosition, const Vec3(7, 3, 6));
    expect(mid.spacePosition, const Vec3(3.5, 1.5, 3));

    final command = session.end()!;
    expect(command, isA<MoveFreePointCommand>());
    // The session rolled its preview back; the command is the move.
    expect(apex.chartPosition, const Vec2(4, 0));
    command.apply(c);
    expect(apex.spacePosition, const Vec3(7, 3, 6));
    expect(edge.spaceEnd, const Vec3(7, 3, 6));
    command.undo(c);
    expect(apex.spacePosition, const Vec3(4, 0, 6));
    expect(apex.height, 6);
  });

  test('cancelling restores the lifted point', () {
    final session = DragSession.start(c, apex, const Vec2(4, 0))!
      ..update(const Vec2(9, 9));
    session.cancel();
    expect(apex.spacePosition, const Vec3(4, 0, 6));
  });

  test('dragging the base end of an edge to a lifted point moves the edge', () {
    final session = DragSession.start(c, a, Vec2.zero)!
      ..update(const Vec2(-2, 2));
    expect(edge.spaceStart, const Vec3(-2, 2, 0));
    expect(edge.spaceEnd, const Vec3(4, 0, 6));
    final command = session.end()!..apply(c);
    expect(mid.spacePosition, const Vec3(1, 1, 3));
    command.undo(c);
    expect(mid.spacePosition, const Vec3(2, 0, 3));
  });

  test('dragging the space edge translates both ends and keeps the height', () {
    final session = DragSession.start(c, edge, const Vec2(2, 0))!
      ..update(const Vec2(3, 5));
    expect(a.position, const Vec2(1, 5));
    expect(apex.spacePosition, const Vec3(5, 5, 6));
    session.end()!.apply(c);
    expect(apex.height, 6);
  });

  test('a traced drag past planar intersections is unaffected by a lifted '
      'bystander', () {
    final p = FreePoint(id: 'p', position: const Vec2(-3, 0));
    final q = FreePoint(id: 'q', position: const Vec2(3, 1));
    final circle = CompassCircle(
      id: 'k',
      radiusPoint1: p,
      radiusPoint2: q,
      center: p,
    );
    final line = LineThroughTwoPoints(id: 'l', point1: a, point2: q);
    final x = IntersectionPoint(
      id: 'x',
      curve1: line,
      curve2: circle,
      branchIndex: 0,
    );
    c
      ..add(p)
      ..add(q)
      ..add(circle)
      ..add(line)
      ..add(x);
    final before = x.position!;
    final session = DragSession.start(c, q, const Vec2(3, 1))!
      ..update(const Vec2(3.5, 1.5))
      ..update(const Vec2(3, 1));
    expect(x.position!.distanceTo(before), lessThan(1e-9));
    session.cancel();
    expect(apex.spacePosition, const Vec3(4, 0, 6));
  });
}
