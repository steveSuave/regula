// Intent 004, milestone 2, stage B: the tools that build planes and what
// planes give.

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/commands/macro_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/fixed_radius_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/intersection_point.dart';
import 'package:regula/domain/construction/objects/line_plane_intersection_point.dart';
import 'package:regula/domain/construction/objects/line_point_plane.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/parallel_plane.dart';
import 'package:regula/domain/construction/objects/perpendicular_plane.dart';
import 'package:regula/domain/construction/objects/perpendicular_to_plane_line.dart';
import 'package:regula/domain/construction/objects/plane_intersection_line.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/construction/space_content.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/tools/intersection_tool.dart';
import 'package:regula/domain/tools/plane_tool.dart';
import 'package:regula/domain/tools/point_and_line_tool.dart';
import 'package:regula/domain/tools/point_and_plane_tool.dart';
import 'package:regula/domain/tools/tool.dart';

void main() {
  late int nextId;
  late Construction c;
  late FreePoint a;
  late FreePoint b;
  late FreePoint d;
  late FreePoint o;
  late LineThroughTwoPoints ab;
  late ThreePointPlane base;

  String newId() => 'n${nextId++}';
  ToolInput tap(GeoObject? hit, [Vec2 at = Vec2.zero]) =>
      ToolInput(at, hit: hit, objects: c.objects);

  setUp(() {
    nextId = 0;
    c = Construction();
    a = FreePoint(id: 'a', position: Vec2.zero);
    b = FreePoint(id: 'b', position: const Vec2(4, 0));
    d = FreePoint(id: 'd', position: const Vec2(0, 4));
    o = FreePoint(id: 'o', position: const Vec2(1, 1), height: 3);
    ab = LineThroughTwoPoints(id: 'ab', point1: a, point2: b);
    base = ThreePointPlane(id: 'base', point1: a, point2: b, point3: d);
    c
      ..add(a)
      ..add(b)
      ..add(d)
      ..add(o)
      ..add(ab)
      ..add(base);
  });

  group('PlaneTool', () {
    test('three points make the plane through them, in tap order', () {
      final tool = PlaneTool(newId: newId);
      expect(tool.onInput(tap(o)), isA<ToolAccepted>());
      expect(tool.hasPartialInput, isTrue);
      expect(tool.previewObjectIds, ['o']);
      expect(tool.onInput(tap(a)), isA<ToolAccepted>());
      final result = tool.onInput(tap(b)) as ToolCommitted;
      final plane = (result.command as AddObjectCommand).object;
      expect(plane, isA<ThreePointPlane>());
      expect(plane.parents, [o, a, b]);
      expect(tool.hasPartialInput, isFalse);
    });

    test(
      'a line and a point, in either order, make the plane through both',
      () {
        for (final lineFirst in [true, false]) {
          final tool = PlaneTool(newId: newId);
          final taps = lineFirst ? [tap(ab), tap(o)] : [tap(o), tap(ab)];
          expect(tool.onInput(taps[0]), isA<ToolAccepted>());
          final result = tool.onInput(taps[1]) as ToolCommitted;
          final plane = (result.command as AddObjectCommand).object;
          expect(plane, isA<LinePointPlane>());
          expect(plane.parents, [ab, o]);
        }
      },
    );

    test('taps on empty canvas place the points, in one command', () {
      final tool = PlaneTool(newId: newId);
      tool
        ..onInput(tap(null, const Vec2(9, 9)))
        ..onInput(tap(o));
      expect(tool.previewPositions, [const Vec2(9, 9)]);
      final result = tool.onInput(tap(null, const Vec2(7, 1))) as ToolCommitted;
      final commands = (result.command as MacroCommand).commands;
      expect(commands, hasLength(3));
      result.command.apply(c);
      final plane = c.objects.last as ThreePointPlane;
      expect(plane.isDefined, isTrue);
      expect(plane.point1.spacePosition, const Vec3(9, 9, 0));
      result.command.undo(c);
      expect(c.objects, hasLength(6));
    });

    test('ignores a repeated point, a second line, a line after two points, '
        'and anything that is neither', () {
      final tool = PlaneTool(newId: newId);
      final circle = FixedRadiusCircle(id: 'k', center: a, radius: 1);
      expect(tool.onInput(tap(circle)), isA<ToolIgnored>());
      expect(tool.onInput(tap(base)), isA<ToolIgnored>());
      tool.onInput(tap(a));
      expect(tool.onInput(tap(a)), isA<ToolIgnored>());
      tool.onInput(tap(b));
      expect(tool.onInput(tap(ab)), isA<ToolIgnored>());
      tool.reset();
      expect(tool.hasPartialInput, isFalse);
      final other = Segment(id: 's', point1: a, point2: d);
      tool.onInput(tap(ab));
      expect(tool.onInput(tap(other)), isA<ToolIgnored>());
    });
  });

  group('PointAndPlaneTool', () {
    test('perpendicular to a plane: point then plane, or plane then point', () {
      for (final planeFirst in [true, false]) {
        final tool = PointAndPlaneTool(
          newId: newId,
          build: buildPerpendicularToPlane,
        );
        final taps = planeFirst ? [tap(base), tap(o)] : [tap(o), tap(base)];
        expect(tool.onInput(taps[0]), isA<ToolAccepted>());
        final result = tool.onInput(taps[1]) as ToolCommitted;
        final line =
            (result.command as AddObjectCommand).object
                as PerpendicularToPlaneLine;
        expect(line.parents, [o, base]);
        expect(line.isDefined, isTrue);
      }
    });

    test('parallel plane through a new point placed by the tap', () {
      final tool = PointAndPlaneTool(newId: newId, build: buildParallelPlane);
      tool.onInput(tap(base));
      expect(tool.previewObjectIds, ['base']);
      final result = tool.onInput(tap(null, const Vec2(2, 2))) as ToolCommitted;
      final commands = (result.command as MacroCommand).commands;
      expect((commands[0] as AddObjectCommand).object, isA<FreePoint>());
      expect((commands[1] as AddObjectCommand).object, isA<ParallelPlane>());
    });

    test('ignores a second point, a second plane and a line', () {
      final tool = PointAndPlaneTool(newId: newId, build: buildParallelPlane);
      expect(tool.onInput(tap(ab)), isA<ToolIgnored>());
      tool.onInput(tap(o));
      expect(tool.onInput(tap(a)), isA<ToolIgnored>());
      expect(tool.onInput(tap(null)), isA<ToolIgnored>());
      tool.reset();
      tool.onInput(tap(base));
      expect(tool.onInput(tap(base)), isA<ToolIgnored>());
    });
  });

  test('the point-and-line tool builds a plane perpendicular to a line', () {
    final tool = PointAndLineTool(newId: newId, build: buildPerpendicularPlane);
    tool.onInput(tap(o));
    final result = tool.onInput(tap(ab)) as ToolCommitted;
    final plane =
        (result.command as AddObjectCommand).object as PerpendicularPlane;
    expect(plane.parents, [o, ab]);
    expect(
      plane.frame!.normal.cross(const Vec3(1, 0, 0)).norm,
      lessThan(1e-12),
    );
  });

  group('IntersectionTool with planes', () {
    late Segment edge;
    late ThreePointPlane face;

    setUp(() {
      edge = Segment(id: 'oa', point1: o, point2: a);
      face = ThreePointPlane(id: 'face', point1: o, point2: b, point3: d);
      c
        ..add(edge)
        ..add(face);
    });

    test('a line and a plane, in either order, meet in a point', () {
      for (final planeFirst in [true, false]) {
        final tool = IntersectionTool(newId: newId);
        final taps = planeFirst ? [tap(face), tap(ab)] : [tap(ab), tap(face)];
        expect(tool.onInput(taps[0]), isA<ToolAccepted>());
        final result = tool.onInput(taps[1]) as ToolCommitted;
        final point =
            (result.command as AddObjectCommand).object
                as LinePlaneIntersectionPoint;
        expect(point.parents, [ab, face]);
        expect(
          point.spacePosition!.distanceTo(const Vec3(4, 0, 0)),
          lessThan(1e-9),
        );
      }
    });

    test('two planes meet in a line', () {
      final tool = IntersectionTool(newId: newId)..onInput(tap(base));
      final result = tool.onInput(tap(face)) as ToolCommitted;
      final line =
          (result.command as AddObjectCommand).object as PlaneIntersectionLine;
      expect(line.isDefined, isTrue);
      expect(line.spaceLine!.contains(b.spacePoint!, 1e-9), isTrue);
      expect(line.spaceLine!.contains(d.spacePoint!, 1e-9), isTrue);
    });

    test('refuses an intersection that already exists, in either order', () {
      final first = IntersectionTool(newId: newId)..onInput(tap(base));
      (first.onInput(tap(face)) as ToolCommitted).command.apply(c);
      final again = IntersectionTool(newId: newId)..onInput(tap(face));
      expect(again.onInput(tap(base)), isA<ToolIgnored>());
    });

    test('refuses a circle with a plane, and a line in space with a planar '
        'line', () {
      final circle = FixedRadiusCircle(id: 'k', center: a, radius: 1);
      final tool = IntersectionTool(newId: newId)..onInput(tap(circle));
      expect(tool.onInput(tap(base)), isA<ToolIgnored>());
      final lines = IntersectionTool(newId: newId)..onInput(tap(edge));
      expect(lines.onInput(tap(ab)), isA<ToolIgnored>());
    });

    test('two planar lines still intersect as they always did', () {
      final ad = LineThroughTwoPoints(id: 'ad', point1: a, point2: d);
      final bd = LineThroughTwoPoints(id: 'bd', point1: b, point2: d);
      c
        ..add(ad)
        ..add(bd);
      final tool = IntersectionTool(newId: newId)..onInput(tap(ab));
      final result = tool.onInput(tap(bd, const Vec2(4, 0)));
      // AB and BD meet at B, which already exists: refused as before.
      expect(result, isA<ToolIgnored>());
      final fresh = IntersectionTool(newId: newId);
      final e = FreePoint(id: 'e', position: const Vec2(1, 3));
      final ae = LineThroughTwoPoints(id: 'ae', point1: a, point2: e);
      c
        ..add(e)
        ..add(ae);
      fresh.onInput(tap(ae));
      final made = fresh.onInput(tap(bd, const Vec2(1, 3))) as ToolCommitted;
      expect(
        (made.command as AddObjectCommand).object,
        isA<IntersectionPoint>(),
      );
    });
  });

  group('hasSpaceContent', () {
    test('is false for a planar document and true for each space thing', () {
      final planar = Construction()
        ..add(FreePoint(id: 'p', position: Vec2.zero))
        ..add(FreePoint(id: 'q', position: const Vec2(1, 0)));
      expect(hasSpaceContent(planar.objects), isFalse);
      planar.setFreePointHeight('p', 1);
      expect(hasSpaceContent(planar.objects), isTrue);
      planar.setFreePointHeight('p', 0);
      expect(hasSpaceContent(planar.objects), isFalse);
      expect(hasSpaceContent(c.objects), isTrue);
      expect(hasSpaceContent([base]), isTrue);
      expect(
        hasSpaceContent([
          PerpendicularToPlaneLine(id: 'h', through: a, plane: base),
        ]),
        isTrue,
      );
    });
  });
}
