// Intent 004, milestone 3: the four tools that build a solid.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/command.dart';
import 'package:regula/domain/commands/macro_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/prism.dart';
import 'package:regula/domain/construction/objects/proportional_raised_point.dart';
import 'package:regula/domain/construction/objects/pyramid.dart';
import 'package:regula/domain/construction/objects/raised_point.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/construction/objects/translated_point.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/drag_session.dart';
import 'package:regula/domain/tools/regular_solid_tool.dart';
import 'package:regula/domain/tools/solid_tool.dart';
import 'package:regula/domain/tools/tool.dart';

void main() {
  late Construction c;
  var ids = 0;
  String newId() => 'n${ids++}';

  setUp(() {
    ids = 0;
    c = Construction();
  });

  ToolInput tap(
    Vec2 at, {
    GeoObject? hit,
    GeoPlane? plane,
    double viewerSide = 1,
  }) => ToolInput(
    at,
    hit: hit,
    objects: c.objects,
    snapThreshold: 0.2,
    plane: plane,
    viewerSide: viewerSide,
  );

  /// Feeds [taps] and applies the commit the last one must give.
  Command run(Tool tool, List<ToolInput> taps) {
    for (final input in taps.take(taps.length - 1)) {
      expect(tool.onInput(input), isA<ToolAccepted>());
    }
    final command = (tool.onInput(taps.last) as ToolCommitted).command
      ..apply(c);
    return command;
  }

  T only<T>() => c.objects.whereType<T>().single;

  List<double> edgeLengths(GeoSolid solid) {
    final v = solid.spaceVertices!;
    return [for (final (i, j) in solid.edges) v[i].distanceTo(v[j])];
  }

  group('PyramidTool', () {
    test('base, the first corner again, then anywhere: a lifted apex over '
        'the middle, every edge, one command, and the apex handed over', () {
      final tool = PyramidTool(newId: newId);
      final command = run(tool, [
        tap(const Vec2(0, 0)),
        tap(const Vec2(4, 0)),
        tap(const Vec2(4, 4)),
        tap(const Vec2(0, 4)),
        tap(const Vec2(0.1, 0)),
        tap(const Vec2(9, 9)),
      ]);
      final solid = only<Pyramid>();
      expect(solid.base, hasLength(4));
      expect(solid.isDefined, isTrue);
      final apex = solid.apex as FreePoint;
      expect(apex.chartPosition, const Vec2(2, 2));
      expect(apex.height, 4);
      expect(c.objects.whereType<Segment>(), hasLength(8));
      expect(c.objects.whereType<FreePoint>(), hasLength(5));
      expect(c.objects.last, same(solid));
      expect(tool.takeSelection(), apex.id);
      expect(tool.takeSelection(), isNull);
      expect(tool.hasPartialInput, isFalse);

      command.undo(c);
      expect(c.objects, isEmpty);
    });

    test('on existing points and an existing apex it adds only what is '
        'missing, and hands nothing over', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final d = FreePoint(id: 'd', position: const Vec2(0, 3));
      final o = FreePoint(id: 'o', position: const Vec2(1, 1), height: 5);
      final ab = Segment(id: 'ab', point1: b, point2: a);
      for (final object in [a, b, d, o, ab]) {
        c.add(object);
      }
      final tool = PyramidTool(newId: newId);
      run(tool, [
        tap(Vec2.zero, hit: a),
        tap(Vec2.zero, hit: b),
        tap(Vec2.zero, hit: d),
        tap(Vec2.zero, hit: a),
        tap(Vec2.zero, hit: o),
      ]);
      final solid = only<Pyramid>();
      expect(solid.apex, same(o));
      expect(c.objects.whereType<Segment>(), hasLength(6));
      expect(c.objects.whereType<FreePoint>(), hasLength(4));
      expect(tool.takeSelection(), isNull);
    });

    test('a base corner that is not in the active plane is refused, and '
        'the tool goes on', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final lifted = FreePoint(id: 'l', position: const Vec2(2, 2), height: 1);
      c
        ..add(a)
        ..add(lifted);
      final tool = PyramidTool(newId: newId);
      expect(tool.onInput(tap(Vec2.zero, hit: a)), isA<ToolAccepted>());
      final refused = tool.onInput(tap(Vec2.zero, hit: lifted));
      expect((refused as ToolRefused).reason, ScopeRefusal.notInPlane);
      expect(tool.previewObjectIds, ['a']);
      // The same point is welcome as the apex.
      tool
        ..onInput(tap(const Vec2(4, 0)))
        ..onInput(tap(const Vec2(0, 4)))
        ..onInput(tap(Vec2.zero, hit: a));
      final done = tool.onInput(tap(Vec2.zero, hit: lifted));
      expect(done, isA<ToolCommitted>());
    });

    test('closing needs three corners, a corner twice is ignored, and a '
        'base corner is no apex', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final d = FreePoint(id: 'd', position: const Vec2(0, 3));
      for (final p in [a, b, d]) {
        c.add(p);
      }
      final tool = PyramidTool(newId: newId)
        ..onInput(tap(Vec2.zero, hit: a))
        ..onInput(tap(Vec2.zero, hit: b));
      expect(tool.onInput(tap(Vec2.zero, hit: a)), isA<ToolIgnored>());
      expect(tool.onInput(tap(Vec2.zero, hit: b)), isA<ToolIgnored>());
      tool
        ..onInput(tap(Vec2.zero, hit: d))
        ..onInput(tap(Vec2.zero, hit: a));
      expect(tool.onInput(tap(Vec2.zero, hit: b)), isA<ToolIgnored>());
      tool.reset();
      expect(tool.hasPartialInput, isFalse);
    });

    test('in an active plane the new apex is a point of that plane, lifted '
        'on the viewer\'s side', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final up = FreePoint(id: 'u', position: Vec2.zero, height: 4);
      final wall = ThreePointPlane(id: 'w', point1: a, point2: b, point3: up);
      for (final object in [a, b, up, wall]) {
        c.add(object);
      }
      final tool = PyramidTool(newId: newId);
      run(tool, [
        tap(Vec2.zero, hit: a, plane: wall),
        tap(Vec2.zero, hit: b, plane: wall),
        tap(Vec2.zero, hit: up, plane: wall),
        tap(Vec2.zero, hit: a, plane: wall),
        tap(const Vec2(1, 1), plane: wall, viewerSide: -1),
      ]);
      final apex = only<Pyramid>().apex as FreePoint;
      expect(apex.plane, same(wall));
      expect(apex.height, lessThan(0));
      expect(only<Pyramid>().isDefined, isTrue);
    });
  });

  group('PrismTool', () {
    test('pulled up, it is right: a raised point over the first corner, the '
        'other far corners as translations, twelve edges', () {
      final tool = PrismTool(newId: newId);
      final command = run(tool, [
        tap(const Vec2(0, 0)),
        tap(const Vec2(4, 0)),
        tap(const Vec2(4, 2)),
        tap(const Vec2(0, 2)),
        tap(const Vec2(0, 0.1)),
        tap(const Vec2(9, 9)),
      ]);
      final solid = only<Prism>();
      final top = solid.top as RaisedPoint;
      expect(top.foot, same(solid.base.first));
      expect(top.height, 3);
      expect(c.objects.whereType<TranslatedPoint>(), hasLength(3));
      expect(c.objects.whereType<Segment>(), hasLength(12));
      expect(tool.takeSelection(), top.id);
      // Its far corners are where the solid says they are.
      final corners = [top, ...c.objects.whereType<TranslatedPoint>()];
      for (var i = 0; i < 4; i++) {
        expect(corners[i].spacePosition, solid.spaceVertices![4 + i]);
      }
      // Dragging a base corner keeps it right.
      c.moveFreePoint(solid.base.first.id, const Vec2(-1, -1));
      expect(top.spacePosition, const Vec3(-1, -1, 3));

      command.undo(c);
      expect(c.objects, isEmpty);
    });

    test('to an existing point it is the oblique prism to it', () {
      final o = FreePoint(id: 'o', position: const Vec2(2, 1), height: 5);
      c.add(o);
      final tool = PrismTool(newId: newId);
      run(tool, [
        tap(const Vec2(0, 0)),
        tap(const Vec2(4, 0)),
        tap(const Vec2(0, 3)),
        tap(const Vec2(0, 0)),
        tap(Vec2.zero, hit: o),
      ]);
      final solid = only<Prism>();
      expect(solid.top, same(o));
      expect(solid.spaceVertices![4], const Vec3(6, 1, 5));
      expect(c.objects.whereType<Segment>(), hasLength(9));
      expect(tool.takeSelection(), isNull);
    });
  });

  group('CubeTool', () {
    test('two corners give a cube: twelve equal edges, square faces, one '
        'command', () {
      final tool = CubeTool(newId: newId);
      final command = run(tool, [tap(const Vec2(1, 1)), tap(const Vec2(4, 5))]);
      final solid = only<Prism>();
      expect(solid.isDefined, isTrue);
      for (final length in edgeLengths(solid)) {
        expect(length, closeTo(5, 1e-12));
      }
      final v = solid.spaceVertices!;
      // Square faces: the three edges at a corner are at right angles.
      final e1 = v[1] - v[0];
      final e2 = v[3] - v[0];
      final e3 = v[4] - v[0];
      expect(e1.dot(e2).abs(), lessThan(1e-12));
      expect(e1.dot(e3).abs(), lessThan(1e-12));
      expect(e2.dot(e3).abs(), lessThan(1e-12));
      expect(e3.z, closeTo(5, 1e-12));
      expect(c.objects.whereType<Segment>(), hasLength(12));
      expect(only<ProportionalRaisedPoint>().factor, 1);

      command.undo(c);
      expect(c.objects, isEmpty);
    });

    test('it stays a cube through a session-level drag of each corner', () {
      final tool = CubeTool(newId: newId);
      run(tool, [tap(const Vec2(1, 1)), tap(const Vec2(4, 5))]);
      final solid = only<Prism>();
      for (final (point, to) in [
        (solid.base[0], const Vec2(-2, 3)),
        (solid.base[1], const Vec2(6, -1)),
      ]) {
        final session = DragSession.start(c, point, point.position!)!
          ..update(to * 0.5)
          ..update(to);
        session.end()!.apply(c);
        final lengths = edgeLengths(solid);
        final side = solid.base[0].spacePosition!.distanceTo(
          solid.base[1].spacePosition!,
        );
        expect(side, greaterThan(1));
        for (final length in lengths) {
          expect(length, closeTo(side, 1e-9));
        }
      }
    });

    test('it rises on the viewer\'s side', () {
      final tool = CubeTool(newId: newId);
      tool.onInput(tap(const Vec2(0, 0), viewerSide: -1));
      (tool.onInput(tap(const Vec2(2, 0), viewerSide: -1)) as ToolCommitted)
          .command
          .apply(c);
      expect(only<Prism>().spaceVertices![4], const Vec3(0, 0, -2));
    });

    test('in an active plane it stands on that plane', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final up = FreePoint(id: 'u', position: Vec2.zero, height: 4);
      final wall = ThreePointPlane(id: 'w', point1: a, point2: b, point3: up);
      for (final object in [a, b, up, wall]) {
        c.add(object);
      }
      final tool = CubeTool(newId: newId);
      run(tool, [
        tap(const Vec2(1, 1), plane: wall),
        tap(const Vec2(3, 1), plane: wall),
      ]);
      final solid = only<Prism>();
      expect(solid.plane, same(wall));
      expect(solid.isDefined, isTrue);
      for (final length in edgeLengths(solid)) {
        expect(length, closeTo(2, 1e-12));
      }
      // Its base is in the wall and its height along the wall's normal.
      final v = solid.spaceVertices!;
      for (var i = 0; i < 4; i++) {
        expect(wall.frame!.heightOf(v[i]).abs(), lessThan(1e-12));
        expect(wall.frame!.heightOf(v[4 + i]), closeTo(2, 1e-12));
      }
    });
  });

  group('RegularTetrahedronTool', () {
    test('two corners give six equal edges, and they stay equal through a '
        'session-level drag', () {
      final tool = RegularTetrahedronTool(newId: newId);
      final command = run(tool, [tap(const Vec2(0, 0)), tap(const Vec2(6, 0))]);
      final solid = only<Pyramid>();
      expect(solid.base, hasLength(3));
      for (final length in edgeLengths(solid)) {
        expect(length, closeTo(6, 1e-12));
      }
      expect(solid.spaceVertices![3].z, closeTo(6 * math.sqrt(2 / 3), 1e-12));
      expect(c.objects.whereType<Segment>(), hasLength(6));

      final b = solid.base[1];
      final session = DragSession.start(c, b, b.position!)!
        ..update(const Vec2(3, 3))
        ..update(const Vec2(2, 7));
      session.end()!.apply(c);
      final side = math.sqrt(4 + 49);
      for (final length in edgeLengths(solid)) {
        expect(length, closeTo(side, 1e-9));
      }

      // The drag's command is on top; undo both.
      c.moveFreePoint(b.id, const Vec2(6, 0));
      command.undo(c);
      expect(c.objects, isEmpty);
      expect(command, isA<MacroCommand>());
    });
  });
}
