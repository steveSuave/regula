import 'package:fgex/application/providers/command_stack_provider.dart';
import 'package:fgex/application/providers/construction_provider.dart';
import 'package:fgex/application/providers/tool_provider.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/point_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted tool for exercising the notifier: replays [results] in order
/// and records calls.
class _StubTool implements Tool {
  _StubTool(this.results);

  final List<ToolResult> results;
  int inputs = 0;
  int resets = 0;

  @override
  ToolResult onInput(ToolInput input) => results[inputs++];

  @override
  void reset() => resets++;
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group('toolProvider', () {
    test('starts with no active tool; input in move/select mode is ignored',
        () {
      expect(container.read(toolProvider).tool, isNull);

      final result = container
          .read(toolProvider.notifier)
          .handleInput(const ToolInput(Vec2.zero));

      expect(result, isA<ToolIgnored>());
      expect(container.read(toolProvider).revision, 0);
    });

    test('activate / deactivate swap the tool and reset the outgoing one',
        () {
      final notifier = container.read(toolProvider.notifier);
      final tool = _StubTool([]);

      notifier.activate(tool);
      expect(container.read(toolProvider).tool, same(tool));

      notifier.deactivate();
      expect(container.read(toolProvider).tool, isNull);
      expect(tool.resets, 1,
          reason: 'partially-collected input must not leak across a switch');
    });

    test('committed command executes on the command stack', () {
      var nextId = 0;
      container
          .read(toolProvider.notifier)
          .activate(PointTool(newId: () => 'p${nextId++}'));

      final result = container
          .read(toolProvider.notifier)
          .handleInput(const ToolInput(Vec2(2, 3)));

      expect(result, isA<ToolCommitted>());
      final construction = container.read(constructionProvider).construction;
      expect(construction.contains('p0'), isTrue);
      expect(
        (construction.byId('p0')! as FreePoint).position,
        const Vec2(2, 3),
      );
      expect(container.read(commandStackProvider).canUndo, isTrue,
          reason: 'the tool tap must be undoable');
      expect(container.read(toolProvider).revision, 1,
          reason: 'commit resets the tool, so previews must repaint');
    });

    test('accepted input bumps revision, ignored input does not', () {
      final tool =
          _StubTool([const ToolAccepted(), const ToolIgnored()]);
      final notifier = container.read(toolProvider.notifier)..activate(tool);

      final revisions = <int>[];
      container.listen(
        toolProvider,
        (_, next) => revisions.add(next.revision),
      );

      notifier.handleInput(const ToolInput(Vec2.zero)); // accepted
      notifier.handleInput(const ToolInput(Vec2.zero)); // ignored

      expect(revisions, [1], reason: 'ignored input must not notify');
    });

    test('activating a new tool starts it at revision 0', () {
      final notifier = container.read(toolProvider.notifier);
      notifier.activate(_StubTool([const ToolAccepted()]));
      notifier.handleInput(const ToolInput(Vec2.zero));
      expect(container.read(toolProvider).revision, 1);

      notifier.activate(_StubTool([]));

      expect(container.read(toolProvider).revision, 0);
    });
  });
}
