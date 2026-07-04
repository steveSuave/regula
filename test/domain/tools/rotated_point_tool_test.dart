import 'dart:math' as math;

import 'package:fgex/domain/commands/add_object_command.dart';
import 'package:fgex/domain/commands/macro_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/rotated_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/rotated_point_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nextId;

  RotatedPointTool toolFor(double angle) =>
      RotatedPointTool(newId: () => 'n${nextId++}', angle: angle);

  setUp(() => nextId = 0);

  group('RotatedPointTool', () {
    test('taps are point then center; commits just the object on existing '
        'points', () {
      final p = FreePoint(id: 'p', position: const Vec2(1, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 0));
      final tool = toolFor(math.pi / 2);

      expect(tool.onInput(ToolInput(p.position, hit: p)), isA<ToolAccepted>());
      final result = tool.onInput(ToolInput(c.position, hit: c));

      expect(result, isA<ToolCommitted>());
      final command = (result as ToolCommitted).command;
      final rotated = (command as AddObjectCommand).object as RotatedPoint;
      expect(rotated.parents, [p, c]);
      expect(rotated.angle, math.pi / 2);
      expect(rotated.position!.closeTo(const Vec2(0, 1), 1e-12), isTrue);
    });

    test('empty-canvas taps create free points, all one undo unit', () {
      final construction = Construction();
      final tool = toolFor(math.pi);

      tool.onInput(const ToolInput(Vec2(3, 1)));
      final result =
          tool.onInput(const ToolInput(Vec2(2, 1))) as ToolCommitted;

      expect(result.command, isA<MacroCommand>());
      result.command.apply(construction);
      expect(construction.length, 3, reason: '2 free points + the rotation');
      final rotated = construction.objects.last as RotatedPoint;
      expect(rotated.position!.closeTo(const Vec2(1, 1), 1e-12), isTrue);

      result.command.undo(construction);
      expect(construction.isEmpty, isTrue,
          reason: 'the whole step is one undo unit');
    });

    test('the same existing point twice is ignored', () {
      final p = FreePoint(id: 'p', position: const Vec2(1, 1));
      final tool = toolFor(1);

      expect(tool.onInput(ToolInput(p.position, hit: p)), isA<ToolAccepted>());
      expect(tool.onInput(ToolInput(p.position, hit: p)), isA<ToolIgnored>());
      expect(tool.collectedVertices, hasLength(1));
    });
  });
}
