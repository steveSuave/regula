// Intent 004, milestone 3: a point glued to an edge of space — placed by
// the Point tool, slid by a session that ends in one command.

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/commands/set_point_on_object_parameter_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/fixed_radius_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/construction/objects/polygon.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/plane_scope.dart';
import 'package:regula/domain/tools/point_tool.dart';
import 'package:regula/domain/tools/space_slide_session.dart';
import 'package:regula/domain/tools/tool.dart';
import 'package:regula/domain/tools/two_point_tool.dart';

void main() {
  late Construction c;
  late FreePoint a;
  late FreePoint apex;
  late Segment edge;
  var ids = 0;
  String newId() => 'n${ids++}';

  setUp(() {
    ids = 0;
    c = Construction();
    a = FreePoint(id: 'a', position: Vec2.zero);
    apex = FreePoint(id: 'o', position: const Vec2(3, 0), height: 4);
    edge = Segment(id: 'e', point1: a, point2: apex);
    c
      ..add(a)
      ..add(apex)
      ..add(edge);
  });

  group('the Point tool on an edge of space', () {
    test('glues a point where the canvas says the tap fell on it', () {
      final tool = PointTool(newId: newId);
      final result = tool.onInput(
        ToolInput(
          const Vec2(50, 50),
          hit: edge,
          objects: c.objects,
          spaceParameterOn: (line) =>
              line.spaceParameterOf(const Vec3(1.5, 0, 2)),
        ),
      );
      final command = (result as ToolCommitted).command as AddObjectCommand;
      command.apply(c);
      final glued = c.objects.last as PointOnObject;
      expect(glued.curve, same(edge));
      expect(glued.onSpaceLine, isTrue);
      expect(
        glued.spacePosition!.distanceTo(const Vec3(1.5, 0, 2)),
        lessThan(1e-12),
      );
      command.undo(c);
      expect(c.objects, hasLength(3));
    });

    test('a tap past the end glues at the end', () {
      final tool = PointTool(newId: newId);
      final result = tool.onInput(
        ToolInput(
          Vec2.zero,
          hit: edge,
          objects: c.objects,
          spaceParameterOn: (_) => 1e6,
        ),
      );
      final glued =
          ((result as ToolCommitted).command as AddObjectCommand).object
              as PointOnObject;
      expect(
        glued.spacePosition!.distanceTo(const Vec3(3, 0, 4)),
        lessThan(1e-12),
      );
    });

    test('with no reading of the edge it places a free point instead of '
        'throwing', () {
      final tool = PointTool(newId: newId);
      for (final reading in <double? Function(GeoLine)?>[null, (_) => null]) {
        final result = tool.onInput(
          ToolInput(
            const Vec2(7, 8),
            hit: edge,
            objects: c.objects,
            spaceParameterOn: reading,
          ),
        );
        final made =
            ((result as ToolCommitted).command as AddObjectCommand).object;
        expect(made, isA<FreePoint>());
      }
    });

    test('the active plane lets the edge through to the Point tool, and to '
        'no planar tool', () {
      final scope = PlaneScope();
      final input = ToolInput(Vec2.zero, hit: edge, objects: c.objects);
      final forPoint = scope.adapt(input, PointTool(newId: newId), newId);
      expect(forPoint.refusal, isNull);
      expect(forPoint.input!.hit, same(edge));

      final circle = TwoPointTool(
        newId: newId,
        build: (id, p, q) => FixedRadiusCircle(id: id, center: p, radius: 1),
      );
      expect(
        scope.adapt(input, circle, newId).refusal,
        ScopeRefusal.notInPlane,
      );
    });
  });

  test('a face over points of space is ground to a planar tool: the tap '
      'passes through it', () {
    final b = FreePoint(id: 'b', position: const Vec2(0, 5));
    final face = Polygon(id: 'p', vertices: [a, b, apex]);
    c
      ..add(b)
      ..add(face);
    final scope = PlaneScope();
    final tool = PointTool(newId: newId);
    final seen = scope.adapt(
      ToolInput(const Vec2(1, 1), hit: face, objects: c.objects),
      tool,
      newId,
    );
    expect(seen.refusal, isNull);
    expect(seen.input!.hits, isEmpty);
    final made =
        ((tool.onInput(seen.input!) as ToolCommitted).command
                as AddObjectCommand)
            .object;
    expect((made as FreePoint).chartPosition, const Vec2(1, 1));

    // A lifted point under the tap is still what was tapped: refused.
    expect(
      scope
          .adapt(
            ToolInput(Vec2.zero, hit: apex, extraHits: [face]),
            tool,
            newId,
          )
          .refusal,
      ScopeRefusal.notInPlane,
    );
  });

  group('SpaceSlideSession', () {
    late PointOnObject g;
    late Midpoint m;

    setUp(() {
      g = PointOnObject(id: 'g', curve: edge, parameter: 1);
      m = Midpoint(id: 'm', point1: a, point2: g);
      c
        ..add(g)
        ..add(m);
    });

    test('does not start for a point on a planar host', () {
      final b = FreePoint(id: 'b', position: const Vec2(0, 5));
      final flat = Segment(id: 'f', point1: a, point2: b);
      final onFlat = PointOnObject(id: 'h', curve: flat, parameter: 1);
      c
        ..add(b)
        ..add(flat)
        ..add(onFlat);
      expect(SpaceSlideSession.start(c, onFlat), isNull);
    });

    test('previews move the point and what is built on it', () {
      final session = SpaceSlideSession.start(c, g)!;
      expect(session.startParameter, 1);
      session.update(2.5);
      expect(g.parameter, 2.5);
      expect(
        g.spacePosition!.distanceTo(const Vec3(1.5, 0, 2)),
        lessThan(1e-12),
      );
      expect(
        m.spacePosition!.distanceTo(const Vec3(0.75, 0, 1)),
        lessThan(1e-12),
      );
    });

    test('the point stops at the ends of its edge', () {
      final session = SpaceSlideSession.start(c, g)!..update(40);
      expect(g.parameter, 5);
      session.update(-3);
      expect(g.parameter, 0);
    });

    test('end rolls back and returns one command; undo and redo hold', () {
      final session = SpaceSlideSession.start(c, g)!..update(4);
      final command = session.end()! as SetPointOnObjectParameterCommand;
      expect(g.parameter, 1);
      expect((command.from, command.to), (1.0, 4.0));
      command.apply(c);
      expect(g.parameter, 4);
      expect(
        m.spacePosition!.distanceTo(const Vec3(1.2, 0, 1.6)),
        lessThan(1e-12),
      );
      command.undo(c);
      expect(g.parameter, 1);
      command.apply(c);
      expect(g.parameter, 4);
    });

    test('a slide that ends where it began is no command', () {
      final session = SpaceSlideSession.start(c, g)!
        ..update(3)
        ..update(1);
      expect(session.end(), isNull);
    });

    test('cancel restores the stored parameter', () {
      SpaceSlideSession.start(c, g)!
        ..update(3)
        ..cancel();
      expect(g.parameter, 1);
    });

    test('a point whose host shrank past it is grabbed where it is drawn, '
        'and an untouched gesture leaves the stored parameter', () {
      c.setPointOnObjectParameter('g', 9);
      final session = SpaceSlideSession.start(c, g)!;
      expect(session.startParameter, 5);
      expect(session.end(), isNull);
      expect(g.parameter, 9);
    });

    test('survives the point vanishing under it', () {
      final session = SpaceSlideSession.start(c, g)!..update(3);
      c.removeWithDependents('g');
      session
        ..update(4)
        ..cancel();
      expect(session.end(), isNull);
    });
  });
}
