import 'package:fgex/domain/commands/add_object_command.dart';
import 'package:fgex/domain/commands/macro_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/angle_bisector_line.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/three_point_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nextId;

  ThreePointTool bisectorTool() => ThreePointTool(
        newId: () => 'n${nextId++}',
        build: (id, a, b, c) =>
            AngleBisectorLine(id: id, arm1: a, vertex: b, arm2: c),
      );

  setUp(() => nextId = 0);

  group('ThreePointTool', () {
    test('three existing points commit just the object, in tap order', () {
      final a = FreePoint(id: 'a', position: const Vec2(5, 0));
      final v = FreePoint(id: 'v', position: const Vec2(0, 0));
      final b = FreePoint(id: 'b', position: const Vec2(0, 5));
      final tool = bisectorTool();

      expect(tool.onInput(ToolInput(a.position, hit: a)), isA<ToolAccepted>());
      expect(tool.onInput(ToolInput(v.position, hit: v)), isA<ToolAccepted>());
      final result = tool.onInput(ToolInput(b.position, hit: b));

      expect(result, isA<ToolCommitted>());
      final command = (result as ToolCommitted).command;
      final bisector =
          (command as AddObjectCommand).object as AngleBisectorLine;
      expect(bisector.parents, [a, v, b],
          reason: 'tap order is builder order: arm, vertex, arm');
    });

    test('three canvas taps: 3 free points + object in one MacroCommand', () {
      final construction = Construction();
      final tool = bisectorTool();

      tool.onInput(const ToolInput(Vec2(5, 0)));
      tool.onInput(const ToolInput(Vec2(0, 0)));
      final result =
          tool.onInput(const ToolInput(Vec2(0, 5))) as ToolCommitted;

      expect(result.command, isA<MacroCommand>());
      result.command.apply(construction);
      expect(construction.length, 4);
      final bisector = construction.objects.last as AngleBisectorLine;
      expect(bisector.line!.contains(const Vec2(1, 1)), isTrue);

      result.command.undo(construction);
      expect(construction.isEmpty, isTrue,
          reason: 'the whole step is one undo unit');
    });
  });
}
