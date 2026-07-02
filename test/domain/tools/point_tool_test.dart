import 'package:fgex/domain/commands/add_object_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/point_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nextId;
  late PointTool tool;

  setUp(() {
    nextId = 0;
    tool = PointTool(newId: () => 'p${nextId++}');
  });

  group('PointTool', () {
    test('tap on empty canvas commits an AddObjectCommand for a FreePoint',
        () {
      final result = tool.onInput(const ToolInput(Vec2(3, -2)));

      expect(result, isA<ToolCommitted>());
      final command = (result as ToolCommitted).command;
      expect(command, isA<AddObjectCommand>());
      final object = (command as AddObjectCommand).object;
      expect(object, isA<FreePoint>());
      expect((object as FreePoint).position, const Vec2(3, -2));
      expect(object.id, 'p0');
    });

    test('committed command adds the point to a construction', () {
      final construction = Construction();
      final result =
          tool.onInput(const ToolInput(Vec2(1, 1))) as ToolCommitted;

      result.command.apply(construction);

      expect(construction.length, 1);
      final point = construction.objects.single as FreePoint;
      expect(point.position, const Vec2(1, 1));
    });

    test('successive taps produce distinct ids', () {
      final first =
          tool.onInput(const ToolInput(Vec2.zero)) as ToolCommitted;
      final second =
          tool.onInput(const ToolInput(Vec2(1, 0))) as ToolCommitted;

      final firstId = (first.command as AddObjectCommand).object.id;
      final secondId = (second.command as AddObjectCommand).object.id;
      expect(firstId, isNot(secondId));
    });

    test('tap that hits an existing point is ignored', () {
      final existing = FreePoint(id: 'x', position: Vec2.zero);

      final result = tool.onInput(ToolInput(Vec2.zero, hit: existing));

      expect(result, isA<ToolIgnored>());
      expect(nextId, 0, reason: 'no id must be consumed for an ignored tap');
    });

    test('tap that hits a line still places an unconstrained free point', () {
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(2, 2));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);

      final result = tool.onInput(ToolInput(const Vec2(1, 1), hit: line));

      expect(result, isA<ToolCommitted>());
    });

    test('reset is safe at any time and the tool keeps working after it', () {
      tool.reset();
      expect(tool.onInput(const ToolInput(Vec2.zero)), isA<ToolCommitted>());
      tool.reset();
    });
  });
}
