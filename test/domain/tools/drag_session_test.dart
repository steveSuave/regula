import 'dart:math' as math;

import 'package:fgex/domain/commands/move_free_point_command.dart';
import 'package:fgex/domain/commands/set_point_on_object_parameter_command.dart';
import 'package:fgex/domain/commands/translate_objects_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/circle_center_point.dart';
import 'package:fgex/domain/construction/objects/compass_circle.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/construction/objects/point_on_object.dart';
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

  group('CompassCircle drag', () {
    test('moves only the center — the radius points are a measurement', () {
      final center = FreePoint(id: 'c', position: const Vec2(10, 10));
      final compass = CompassCircle(
        id: 'k',
        radiusPoint1: a,
        radiusPoint2: b,
        center: center,
      );
      construction
        ..add(center)
        ..add(compass);
      expect(compass.circle!.radius, 4);

      final session =
          DragSession.start(construction, compass, const Vec2(14, 10))!;
      session.update(const Vec2(15, 12));
      expect(center.position, const Vec2(11, 12));
      expect(a.position, Vec2.zero,
          reason: 'radius-defining points stay put');
      expect(b.position, const Vec2(4, 0));
      expect(compass.circle!.radius, 4,
          reason: 'the measured radius is unchanged');

      final command = session.end()!;
      expect(center.position, const Vec2(10, 10));
      expect(command, isA<TranslateObjectsCommand>());
      command.apply(construction);
      expect(center.position, const Vec2(11, 12));
      expect(a.position, Vec2.zero);
      command.undo(construction);
      expect(center.position, const Vec2(10, 10));
    });

    test('a derived center drags through its own free ancestors', () {
      // Center = midpoint of a and b: those ARE radius ancestors too, so
      // the radius may change — the rule is "the center's free ancestors",
      // not "anything but the radius points".
      final compass = CompassCircle(
        id: 'k',
        radiusPoint1: a,
        radiusPoint2: b,
        center: midpoint,
      );
      construction.add(compass);

      final session =
          DragSession.start(construction, compass, const Vec2(2, 4))!;
      session.update(const Vec2(3, 4));
      expect(a.position, const Vec2(1, 0));
      expect(b.position, const Vec2(5, 0));
      session.cancel();
      expect(a.position, Vec2.zero);
      expect(b.position, const Vec2(4, 0));
    });

    test("a constrained center drags its host curve's free points only",
        () {
      // Center rides a line through two points unrelated to the radius
      // pair: dragging the compass translates the line's points, while a
      // and b (the measurement) stay put.
      final d = FreePoint(id: 'd', position: const Vec2(0, 10));
      final e = FreePoint(id: 'e', position: const Vec2(10, 10));
      final l1 = LineThroughTwoPoints(id: 'l1', point1: d, point2: e);
      construction
        ..add(d)
        ..add(e)
        ..add(l1);
      final onLine = PointOnObject(id: 'ol', curve: l1, parameter: 5);
      construction.add(onLine);
      final compass = CompassCircle(
        id: 'k',
        radiusPoint1: a,
        radiusPoint2: b,
        center: onLine,
      );
      construction.add(compass);

      final session =
          DragSession.start(construction, compass, const Vec2(9, 10))!;
      session.update(const Vec2(9, 13));
      expect(d.position, const Vec2(0, 13));
      expect(e.position, const Vec2(10, 13));
      expect(a.position, Vec2.zero);
      expect(b.position, const Vec2(4, 0));
      session.cancel();
      expect(d.position, const Vec2(0, 10));
      expect(e.position, const Vec2(10, 10));
    });
  });

  group('PointOnObject slide-drag', () {
    late PointOnObject onSegment;

    setUp(() {
      // Segment a→b runs along the x axis from 0 to 4; parameter 1 puts
      // the point at (1, 0) (arc-length along the unit direction).
      onSegment = PointOnObject(id: 'p', curve: segment, parameter: 1);
      construction.add(onSegment);
    });

    test('slides along the host line, ends with one parameter command', () {
      final session =
          DragSession.start(construction, onSegment, const Vec2(1, 0))!;

      session.update(const Vec2(3, 2));
      expect(onSegment.position, const Vec2(3, 0),
          reason: 'the pointer projects onto the carrier per frame');
      expect(onSegment.parameter, 3);

      final command = session.end()!;
      expect(onSegment.parameter, 1,
          reason: 'end rolls the preview back — the command replays it');
      expect(command, isA<SetPointOnObjectParameterCommand>());
      command.apply(construction);
      expect(onSegment.position, const Vec2(3, 0));
      command.undo(construction);
      expect(onSegment.position, const Vec2(1, 0));
    });

    test('the parameter rides the pointer, not the grab point', () {
      // Grabbed 0.5 short of the point (hit threshold): the point must
      // follow the pointer's motion, not jump under the cursor.
      final session =
          DragSession.start(construction, onSegment, const Vec2(0.5, 0))!;
      session.update(const Vec2(2.5, 0));
      expect(onSegment.position, const Vec2(3, 0));
      session.cancel();
      expect(onSegment.position, const Vec2(1, 0));
      expect(onSegment.parameter, 1, reason: 'rollback is float-exact');
    });

    test('zero-motion gesture ends with no command', () {
      final session =
          DragSession.start(construction, onSegment, const Vec2(1, 0))!;
      expect(session.end(), isNull);
    });

    test('slides around a circle host, staying on the rim', () {
      final center = FreePoint(id: 'c', position: Vec2.zero);
      // b sits at (4, 0), so the circle has radius 4.
      final circle = CircleCenterPoint(id: 'k', center: center, onCircle: b);
      final onCircle = PointOnObject(id: 'q', curve: circle, parameter: 0);
      construction
        ..add(center)
        ..add(circle)
        ..add(onCircle);
      expect(onCircle.position, const Vec2(4, 0));

      final session =
          DragSession.start(construction, onCircle, const Vec2(4, 0))!;
      // Drag toward the top of the circle, from off-rim: the point must
      // radially project back onto the rim.
      session.update(const Vec2(0, 7));
      expect(onCircle.position!.x, closeTo(0, 1e-12));
      expect(onCircle.position!.y, closeTo(4, 1e-12));

      final command = session.end()!;
      expect(onCircle.position, const Vec2(4, 0));
      command.apply(construction);
      expect(onCircle.position!.y, closeTo(4, 1e-12));
    });

    test('grabbing near the ±π angular cut never jumps the point a turn',
        () {
      final center = FreePoint(id: 'c', position: Vec2.zero);
      final circle =
          CircleCenterPoint(id: 'k', center: center, onCircle: b);
      final onCircle =
          PointOnObject(id: 'q', curve: circle, parameter: math.pi);
      construction
        ..add(center)
        ..add(circle)
        ..add(onCircle);
      expect(onCircle.position!.x, closeTo(-4, 1e-12));

      // Grab a hair below the −x axis: atan2 there is ≈ −π while the
      // parameter is +π — the raw offset is ~2π and must be normalized.
      final session = DragSession.start(
          construction, onCircle, const Vec2(-4, -1e-9))!;
      session.update(const Vec2(-4, -1e-9));
      expect(onCircle.position!.x, closeTo(-4, 1e-6),
          reason: 'a still gesture must not move the point');
      expect(onCircle.position!.y, closeTo(0, 1e-6));
      expect(onCircle.parameter.abs(), lessThan(math.pi + 1e-6),
          reason: 'the normalized offset keeps the parameter within a '
              'turn (±π may swap sign at the cut — same rim position)');
      session.cancel();
      expect(onCircle.parameter, math.pi, reason: 'rollback is float-exact');
    });

    test('refuses to start while the host curve is undefined', () {
      construction.moveFreePoint('b', Vec2.zero); // a == b: carrier gone
      expect(
        DragSession.start(construction, onSegment, Vec2.zero),
        isNull,
      );
      construction.moveFreePoint('b', const Vec2(4, 0));
    });

    test('rollback skips a point removed mid-session instead of throwing',
        () {
      final session =
          DragSession.start(construction, onSegment, const Vec2(1, 0))!;
      session.update(const Vec2(2, 0));
      construction.removeWithDependents('p');
      session.cancel(); // must not throw
      expect(construction.contains('p'), isFalse);
    });
  });
}
