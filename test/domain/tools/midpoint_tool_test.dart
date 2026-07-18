import 'package:flutter_test/flutter_test.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/arc.dart';
import 'package:regula/domain/construction/objects/circle_center.dart';
import 'package:regula/domain/construction/objects/circle_center_point.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/tools/midpoint_tool.dart';
import 'package:regula/domain/tools/tool.dart';

void main() {
  late int nextId;

  MidpointTool tool() => MidpointTool(newId: () => 'n${nextId++}');

  setUp(() => nextId = 0);

  group('MidpointTool', () {
    test('two taps on existing points still build a Midpoint', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 2));
      final t = tool();

      expect(t.onInput(ToolInput(a.position, hit: a)), isA<ToolAccepted>());
      final result = t.onInput(ToolInput(b.position, hit: b));

      expect(result, isA<ToolCommitted>());
      final command = (result as ToolCommitted).command;
      final midpoint = (command as AddObjectCommand).object as Midpoint;
      expect(midpoint.parents, [a, b]);
      expect(midpoint.position, const Vec2(2, 1));
    });

    test('a first tap on a circle commits its CircleCenter in one step', () {
      final a = FreePoint(id: 'a', position: const Vec2(2, 1));
      final b = FreePoint(id: 'b', position: const Vec2(5, 1));
      final circle = CircleCenterPoint(id: 'c', center: a, onCircle: b);
      final construction = Construction()
        ..add(a)
        ..add(b)
        ..add(circle);
      final t = tool();

      final result = t.onInput(ToolInput(const Vec2(5, 1.1), hit: circle));

      expect(result, isA<ToolCommitted>());
      final command = (result as ToolCommitted).command;
      command.apply(construction);
      final center = construction.objects.whereType<CircleCenter>().single;
      expect(center.parents, [circle]);
      expect(center.position, const Vec2(2, 1));
      expect(t.previewPositions, isEmpty,
          reason: 'the tool is back in its initial state');
      expect(t.previewObjectIds, isEmpty);
    });

    test('an arc yields the center of its carrier circle', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 1));
      final b = FreePoint(id: 'b', position: const Vec2(1, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, -1));
      final arc = Arc(id: 'arc', start: a, via: b, end: c);
      final t = tool();

      final result =
          t.onInput(ToolInput(const Vec2(1, 0.1), hit: arc)) as ToolCommitted;

      final center = (result.command as AddObjectCommand).object as CircleCenter;
      expect(center.position!.closeTo(Vec2.zero), isTrue);
    });

    test('a point hit wins over the circle it sits on', () {
      final a = FreePoint(id: 'a', position: const Vec2(2, 1));
      final b = FreePoint(id: 'b', position: const Vec2(5, 1));
      final circle = CircleCenterPoint(id: 'c', center: a, onCircle: b);
      final t = tool();

      final result = t.onInput(
        ToolInput(b.position, hit: b, extraHits: [circle]),
      );

      expect(result, isA<ToolAccepted>(),
          reason: 'the rim point is collected as a midpoint parent');
      expect(t.collectedVertices, [b]);
    });

    test('a circle tap after a collected point glues, not centers', () {
      final a = FreePoint(id: 'a', position: const Vec2(2, 1));
      final b = FreePoint(id: 'b', position: const Vec2(5, 1));
      final p = FreePoint(id: 'p', position: const Vec2(10, 10));
      final circle = CircleCenterPoint(id: 'c', center: a, onCircle: b);
      final construction = Construction()
        ..add(a)
        ..add(b)
        ..add(p)
        ..add(circle);
      final t = tool();

      t.onInput(ToolInput(p.position, hit: p));
      final result =
          t.onInput(ToolInput(const Vec2(5, 1.1), hit: circle)) as ToolCommitted;

      result.command.apply(construction);
      expect(construction.objects.whereType<CircleCenter>(), isEmpty);
      final glued = construction.objects.whereType<PointOnObject>().single;
      expect(glued.parents, [circle]);
      final midpoint = construction.objects.whereType<Midpoint>().single;
      expect(midpoint.parents, [p, glued]);
    });
  });
}
