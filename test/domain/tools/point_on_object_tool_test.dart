import 'package:fgex/domain/commands/add_object_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/circle_center_point.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/point_on_object.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/point_on_object_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nextId;
  late PointOnObjectTool tool;

  setUp(() {
    nextId = 0;
    tool = PointOnObjectTool(newId: () => 'n${nextId++}');
  });

  group('PointOnObjectTool', () {
    test('tap on a line commits a constrained point at the projection', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      construction
        ..add(a)
        ..add(b)
        ..add(line);

      final result = tool.onInput(ToolInput(const Vec2(3, 1), hit: line));

      expect(result, isA<ToolCommitted>());
      final command = (result as ToolCommitted).command;
      final point = (command as AddObjectCommand).object as PointOnObject;
      expect(point.parents, [line]);
      command.apply(construction);
      expect(point.position!.closeTo(const Vec2(3, 0)), isTrue);
    });

    test('tap on a circle commits a constrained point on the rim', () {
      final center = FreePoint(id: 'c', position: Vec2.zero);
      final rim = FreePoint(id: 'r', position: const Vec2(2, 0));
      final circle = CircleCenterPoint(id: 'k', center: center, onCircle: rim);

      final result = tool.onInput(ToolInput(const Vec2(0, 5), hit: circle));

      final point =
          ((result as ToolCommitted).command as AddObjectCommand).object
              as PointOnObject;
      expect(point.position!.closeTo(const Vec2(0, 2)), isTrue);
    });

    test('taps on empty canvas and on points are ignored', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);

      expect(tool.onInput(const ToolInput(Vec2(1, 1))), isA<ToolIgnored>());
      expect(tool.onInput(ToolInput(Vec2.zero, hit: a)), isA<ToolIgnored>());
      expect(nextId, 0, reason: 'no id must be consumed for an ignored tap');
    });
  });
}
