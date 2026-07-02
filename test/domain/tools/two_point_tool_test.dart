import 'package:fgex/domain/commands/add_object_command.dart';
import 'package:fgex/domain/commands/macro_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/circle_center_point.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:fgex/domain/tools/two_point_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nextId;

  TwoPointTool toolFor(TwoPointBuilder build) =>
      TwoPointTool(newId: () => 'n${nextId++}', build: build);

  setUp(() => nextId = 0);

  group('TwoPointTool', () {
    test('two taps on existing points commit just the object', () {
      final a = FreePoint(id: 'a', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final tool = toolFor(
        (id, p, q) => LineThroughTwoPoints(id: id, point1: p, point2: q),
      );

      expect(tool.onInput(ToolInput(a.position, hit: a)), isA<ToolAccepted>());
      final result = tool.onInput(ToolInput(b.position, hit: b));

      expect(result, isA<ToolCommitted>());
      final command = (result as ToolCommitted).command;
      final line =
          (command as AddObjectCommand).object as LineThroughTwoPoints;
      expect(line.parents, [a, b]);
    });

    test('tap order is builder argument order: first tap is the center', () {
      final construction = Construction();
      final tool = toolFor(
        (id, p, q) => CircleCenterPoint(id: id, center: p, onCircle: q),
      );

      tool.onInput(const ToolInput(Vec2(1, 1)));
      final result =
          tool.onInput(const ToolInput(Vec2(4, 1))) as ToolCommitted;

      expect(result.command, isA<MacroCommand>());
      result.command.apply(construction);
      expect(construction.length, 3, reason: '2 free points + the circle');
      final circle = construction.objects.last as CircleCenterPoint;
      expect(circle.circle!.center, const Vec2(1, 1));
      expect(circle.circle!.radius, closeTo(3, 1e-12));

      result.command.undo(construction);
      expect(construction.isEmpty, isTrue,
          reason: 'the whole step is one undo unit');
    });

    test('the same existing point twice is ignored', () {
      final a = FreePoint(id: 'a', position: const Vec2(1, 1));
      final tool = toolFor(
        (id, p, q) => Midpoint(id: id, point1: p, point2: q),
      );

      expect(tool.onInput(ToolInput(a.position, hit: a)), isA<ToolAccepted>());
      expect(tool.onInput(ToolInput(a.position, hit: a)), isA<ToolIgnored>());
      expect(tool.collectedVertices, hasLength(1));
    });

    test('previewPositions tracks collection and clears on commit', () {
      final tool = toolFor(
        (id, p, q) => Midpoint(id: id, point1: p, point2: q),
      );

      expect(tool.previewPositions, isEmpty);
      tool.onInput(const ToolInput(Vec2(2, 3)));
      expect(tool.previewPositions, [const Vec2(2, 3)]);

      tool.onInput(const ToolInput(Vec2(4, 5)));
      expect(tool.previewPositions, isEmpty);
    });
  });
}
