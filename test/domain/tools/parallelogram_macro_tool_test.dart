import 'package:fgex/domain/commands/macro_command.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/intersection_point.dart';
import 'package:fgex/domain/construction/objects/parallel_line.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/parallelogram_macro_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int nextId;
  late ParallelogramMacroTool tool;

  setUp(() {
    nextId = 0;
    tool = ParallelogramMacroTool(newId: () => 'n${nextId++}');
  });

  /// Applies three empty-canvas taps A(0,0), B(4,0), C(5,2) and returns
  /// the committed construction.
  Construction buildParallelogram() {
    final construction = Construction();
    tool.onInput(const ToolInput(Vec2(0, 0)));
    tool.onInput(const ToolInput(Vec2(4, 0)));
    (tool.onInput(const ToolInput(Vec2(5, 2))) as ToolCommitted)
        .command
        .apply(construction);
    return construction;
  }

  IntersectionPoint cornerOf(Construction c) =>
      c.objects.whereType<IntersectionPoint>().single;

  group('ParallelogramMacroTool', () {
    test('three empty-canvas taps commit the whole shape as one macro', () {
      final construction = Construction();

      expect(tool.onInput(const ToolInput(Vec2(0, 0))), isA<ToolAccepted>());
      expect(tool.onInput(const ToolInput(Vec2(4, 0))), isA<ToolAccepted>());
      final result =
          tool.onInput(const ToolInput(Vec2(5, 2))) as ToolCommitted;

      expect(result.command, isA<MacroCommand>());
      result.command.apply(construction);
      expect(construction.length, 10,
          reason: '3 free points + 2 sides + 2 parallels + corner + 2 sides');
      expect(cornerOf(construction).position, const Vec2(1, 2),
          reason: 'D = A + (C − B)');

      result.command.undo(construction);
      expect(construction.isEmpty, isTrue,
          reason: 'the whole parallelogram is one undo unit');
    });

    test('scaffolding is hidden, corner and sides are visible', () {
      final construction = buildParallelogram();

      final hidden =
          construction.objects.where((o) => !o.attributes.visible).toList();
      expect(hidden, hasLength(2));
      expect(hidden.whereType<ParallelLine>(), hasLength(2));

      final visible = construction.objects.where((o) => o.attributes.visible);
      expect(visible.whereType<Segment>(), hasLength(4));
      expect(visible.whereType<IntersectionPoint>(), hasLength(1));
    });

    test('dragging a tapped corner keeps the shape a parallelogram', () {
      final construction = buildParallelogram();
      final b = construction.objects.whereType<FreePoint>().elementAt(1);

      construction.moveFreePoint(b.id, const Vec2(2, 1));

      final d = cornerOf(construction).position!;
      expect(d.x, closeTo(3, 1e-9), reason: 'D tracks A + (C − B)');
      expect(d.y, closeTo(1, 1e-9));
    });

    test('the shape survives a drag through collinearity', () {
      final construction = buildParallelogram();
      final c = construction.objects.whereType<FreePoint>().elementAt(2);
      final cornerD = cornerOf(construction);

      construction.moveFreePoint(c.id, const Vec2(2, 0));
      expect(cornerD.position, isNull,
          reason: 'collinear corners make the two parallels parallel');

      construction.moveFreePoint(c.id, const Vec2(5, 2));
      expect(cornerD.position, const Vec2(1, 2));
    });
  });
}
