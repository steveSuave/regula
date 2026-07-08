import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/command_stack_provider.dart';
import 'package:regula/application/providers/construction_provider.dart';
import 'package:regula/application/providers/tool_provider.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/commands/delete_objects_command.dart';
import 'package:regula/domain/commands/macro_command.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/object_attributes.dart';
import 'package:regula/domain/construction/objects/centroid.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/tools/point_tool.dart';
import 'package:regula/domain/tools/tool.dart';
import 'package:regula/domain/tools/triangle_center_tool.dart';

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

    group('drag vs. activation (Phase 30b)', () {
      late FreePoint p;

      setUp(() {
        p = FreePoint(id: 'p', position: Vec2.zero);
        container
            .read(commandStackProvider.notifier)
            .execute(AddObjectCommand(p));
      });

      test('activating a tool mid-drag commits the move as one undo step',
          () {
        final notifier = container.read(toolProvider.notifier);
        expect(notifier.startDrag(p, Vec2.zero), isTrue);
        notifier.updateDrag(const Vec2(5, 0));
        expect(p.position, const Vec2(5, 0), reason: 'preview applied');

        notifier.activate(_StubTool([]));

        expect(p.position, const Vec2(5, 0),
            reason: 'the switch must not discard the move');
        container.read(commandStackProvider.notifier).undo();
        expect(p.position, Vec2.zero,
            reason: 'the drag-so-far became one command');
      });

      test('deactivating mid-drag still rolls the preview back (Esc abort)',
          () {
        final notifier = container.read(toolProvider.notifier);
        notifier.startDrag(p, Vec2.zero);
        notifier.updateDrag(const Vec2(5, 0));

        notifier.deactivate();

        expect(p.position, Vec2.zero, reason: 'Esc aborts the drag');
        container.read(commandStackProvider.notifier).undo();
        expect(
          container.read(constructionProvider).construction.isEmpty,
          isTrue,
          reason: 'an aborted drag leaves nothing on the stack — the top '
              'undo step is still the AddObjectCommand',
        );
      });

      test('activating a tool over an unmoved drag commits nothing', () {
        final notifier = container.read(toolProvider.notifier);
        notifier.startDrag(p, Vec2.zero);

        notifier.activate(_StubTool([]));

        expect(p.position, Vec2.zero);
        container.read(commandStackProvider.notifier).undo();
        expect(
          container.read(constructionProvider).construction.isEmpty,
          isTrue,
          reason: 'the only undo step is the AddObjectCommand',
        );
      });
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

    test('undo, redo, and construction replace discard in-progress input',
        () {
      final notifier = container.read(toolProvider.notifier);
      final tool = _StubTool([]);
      notifier.activate(tool);

      final stack = container.read(commandStackProvider.notifier);
      stack.execute(AddObjectCommand(FreePoint(id: 'x', position: Vec2.zero)));

      stack.undo();
      expect(tool.resets, 1);
      expect(container.read(toolProvider).revision, 1,
          reason: 'previews of the discarded input must repaint');

      stack.redo();
      expect(tool.resets, 2);

      container.read(constructionProvider.notifier).replace(Construction());
      expect(tool.resets, 3,
          reason: 'a swapped-in construction invalidates collected objects');
      expect(container.read(toolProvider).tool, same(tool),
          reason: 'the tool itself stays active — only its input is dropped');
    });

    test('undo mid-collection: stale parent cannot poison the next commit',
        () {
      var nextId = 0;
      final notifier = container.read(toolProvider.notifier);

      // Place a point, then start collecting a centroid on it.
      notifier.activate(PointTool(newId: () => 'p${nextId++}'));
      notifier.handleInput(const ToolInput(Vec2(1, 1)));
      final placed =
          container.read(constructionProvider).construction.byId('p0')!;

      final centerTool = TriangleCenterTool(
        newId: () => 'n${nextId++}',
        buildCenter: Centroid.new,
      );
      notifier.activate(centerTool);
      notifier.handleInput(ToolInput(const Vec2(1, 1), hit: placed));
      expect(centerTool.collectedVertices, hasLength(1));

      // Undo removes the collected point out from under the tool.
      container.read(commandStackProvider.notifier).undo();
      expect(centerTool.collectedVertices, isEmpty);

      // Three fresh taps still commit cleanly.
      notifier.handleInput(const ToolInput(Vec2(0, 0)));
      notifier.handleInput(const ToolInput(Vec2(6, 0)));
      final result = notifier.handleInput(const ToolInput(Vec2(0, 6)));
      expect(result, isA<ToolCommitted>());
      expect(
        container.read(constructionProvider).construction.length,
        4,
        reason: '3 free points + the centroid',
      );
    });

    group('automatic naming', () {
      /// Commits [command] through the handleInput funnel via a stub tool.
      void commit(ProviderContainer container, MacroCommand command) {
        final notifier = container.read(toolProvider.notifier)
          ..activate(_StubTool([ToolCommitted(command)]));
        notifier.handleInput(const ToolInput(Vec2.zero));
      }

      String nameOf(ProviderContainer container, String id) => container
          .read(constructionProvider)
          .construction
          .byId(id)!
          .attributes
          .name;

      test('successive points are named A, B; a new segment gets a', () {
        final notifier = container.read(toolProvider.notifier);
        var nextId = 0;
        notifier.activate(PointTool(newId: () => 'p${nextId++}'));
        notifier.handleInput(const ToolInput(Vec2(0, 0)));
        notifier.handleInput(const ToolInput(Vec2(4, 0)));

        expect(nameOf(container, 'p0'), 'A');
        expect(nameOf(container, 'p1'), 'B');

        final construction =
            container.read(constructionProvider).construction;
        final segment = Segment(
          id: 's0',
          point1: construction.byId('p0')! as FreePoint,
          point2: construction.byId('p1')! as FreePoint,
        );
        commit(container, MacroCommand([AddObjectCommand(segment)]));

        expect(nameOf(container, 's0'), 'a');
        expect(segment.attributes.labelVisible, isFalse,
            reason: 'lines are named but their canvas label stays hidden');
      });

      test('points keep labelVisible, hidden scaffolding burns no letters',
          () {
        final visible = FreePoint(id: 'v', position: Vec2.zero);
        final hidden = FreePoint(
          id: 'h',
          position: const Vec2(1, 0),
          attributes: const ObjectAttributes(visible: false),
        );
        final named = FreePoint(
          id: 'n',
          position: const Vec2(2, 0),
          attributes: const ObjectAttributes(name: 'custom'),
        );
        final after = FreePoint(id: 'z', position: const Vec2(3, 0));
        commit(
          container,
          MacroCommand([
            AddObjectCommand(visible),
            AddObjectCommand(hidden),
            AddObjectCommand(named),
            AddObjectCommand(after),
          ]),
        );

        expect(visible.attributes.name, 'A');
        expect(visible.attributes.labelVisible, isTrue);
        expect(hidden.attributes.name, isEmpty);
        expect(named.attributes.name, 'custom',
            reason: 'a pre-set name is never overwritten');
        expect(after.attributes.name, 'B',
            reason:
                'the batch-local scan skips the hidden object, not a letter');
      });

      test('deleting B frees the name for the next point', () {
        final notifier = container.read(toolProvider.notifier);
        var nextId = 0;
        notifier.activate(PointTool(newId: () => 'p${nextId++}'));
        notifier.handleInput(const ToolInput(Vec2(0, 0)));
        notifier.handleInput(const ToolInput(Vec2(4, 0)));
        container
            .read(commandStackProvider.notifier)
            .execute(DeleteObjectsCommand(['p1']));

        notifier.handleInput(const ToolInput(Vec2(8, 0)));

        expect(nameOf(container, 'p2'), 'B');
      });

      test('names survive undo/redo', () {
        final notifier = container.read(toolProvider.notifier);
        var nextId = 0;
        notifier.activate(PointTool(newId: () => 'p${nextId++}'));
        notifier.handleInput(const ToolInput(Vec2(0, 0)));
        notifier.handleInput(const ToolInput(Vec2(4, 0)));

        final stack = container.read(commandStackProvider.notifier);
        stack.undo();
        stack.redo();

        expect(nameOf(container, 'p0'), 'A');
        expect(nameOf(container, 'p1'), 'B');
      });
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
