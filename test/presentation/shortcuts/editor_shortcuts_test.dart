import 'package:fgex/application/providers/command_stack_provider.dart';
import 'package:fgex/application/providers/construction_provider.dart';
import 'package:fgex/application/providers/preferences_provider.dart';
import 'package:fgex/application/providers/selection_provider.dart';
import 'package:fgex/application/providers/theme_provider.dart';
import 'package:fgex/application/providers/tool_provider.dart';
import 'package:fgex/application/providers/viewport_provider.dart';
import 'package:fgex/domain/commands/add_object_command.dart';
import 'package:fgex/domain/construction/objects/centroid.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/domain/tools/point_and_line_tool.dart';
import 'package:fgex/domain/tools/point_tool.dart';
import 'package:fgex/domain/tools/square_macro_tool.dart';
import 'package:fgex/domain/tools/tool.dart';
import 'package:fgex/domain/tools/triangle_center_tool.dart';
import 'package:fgex/domain/tools/two_line_tool.dart';
import 'package:fgex/domain/tools/two_point_tool.dart';
import 'package:fgex/main.dart';
import 'package:fgex/presentation/canvas/geometry_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget tests for the keyboard shortcut wiring: key events go in, the
/// providers (tool, selection, viewport, command stack) change as the
/// shortcut table promises.
void main() {
  late ProviderContainer container;

  Future<void> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditorScreen()),
      ),
    );
  }

  Tool? activeTool() => container.read(toolProvider).tool;

  /// Feeds the active tool a canvas input directly — the canvas→tool
  /// funnel has its own tests; here only the activation matters.
  void tapWorld(double x, double y) =>
      container.read(toolProvider.notifier).handleInput(ToolInput(Vec2(x, y)));

  /// Two free points and their midpoint, added like real edits.
  (FreePoint, FreePoint, Midpoint) buildSmallConstruction() {
    final stack = container.read(commandStackProvider.notifier);
    final a = FreePoint(id: 'a', position: const Vec2(0, 0));
    final b = FreePoint(id: 'b', position: const Vec2(4, 2));
    final m = Midpoint(id: 'm', point1: a, point2: b);
    stack.execute(AddObjectCommand(a));
    stack.execute(AddObjectCommand(b));
    stack.execute(AddObjectCommand(m));
    return (a, b, m);
  }

  testWidgets('letter keys activate tools; Esc and V leave them',
      (tester) async {
    await pumpEditor(tester);
    expect(activeTool(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(activeTool(), isA<PointTool>());

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(activeTool(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    expect(activeTool(), isA<PointAndLineTool>());

    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    expect(activeTool(), isNull);
  });

  testWidgets('S builds segments end to end', (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    expect(activeTool(), isA<TwoPointTool>());

    tapWorld(0, 0);
    tapWorld(4, 0);
    final objects =
        container.read(constructionProvider).construction.objects.toList();
    expect(objects, hasLength(3));
    expect(objects.last, isA<Segment>());
  });

  testWidgets('shifted letters pick the shifted variant', (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(activeTool(), isA<TwoLineTool>());
  });

  testWidgets('G leader chords reach constructions', (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    expect(activeTool(), isNull, reason: 'leader alone activates nothing');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    expect(activeTool(), isA<TriangleCenterTool>());

    tapWorld(0, 0);
    tapWorld(4, 0);
    tapWorld(0, 3);
    final objects =
        container.read(constructionProvider).construction.objects.toList();
    expect(objects.last, isA<Centroid>());
  });

  testWidgets('a held (auto-repeating) leader still chords', (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    expect(activeTool(), isA<TriangleCenterTool>());
  });

  testWidgets('a failed chord swallows the stroke instead of firing it',
      (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(activeTool(), isNull, reason: 'G P is no chord, P must not fire');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(activeTool(), isA<PointTool>(), reason: 'table is clean again');
  });

  testWidgets('X leader reaches the macros', (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    expect(activeTool(), isA<SquareMacroTool>());
  });

  testWidgets('G R asks for the ratio; cancel activates nothing',
      (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();
    expect(find.text('Segment ratio'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(activeTool(), isNull);
  });

  testWidgets('undo/redo shortcuts, on both primary modifiers',
      (tester) async {
    await pumpEditor(tester);
    buildSmallConstruction();
    final construction = container.read(constructionProvider).construction;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(construction.length, 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(construction.length, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(construction.length, 2, reason: 'Ctrl+Shift+Z redoes');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(construction.length, 3, reason: 'Ctrl+Y redoes too');

    // An empty redo stack must not throw (the handler gates on canRedo).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(construction.length, 3);
  });

  testWidgets('select all, hide, reveal', (tester) async {
    await pumpEditor(tester);
    final (a, _, _) = buildSmallConstruction();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(container.read(selectionProvider), hasLength(3));

    container.read(selectionProvider.notifier).select(a.id);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    expect(a.attributes.visible, isFalse);
    expect(
      container.read(selectionProvider),
      contains(a.id),
      reason: 'hiding keeps the selection',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(a.attributes.visible, isTrue);
    expect(
      container.read(commandStackProvider).canUndo,
      isTrue,
      reason: 'hide/reveal are commands',
    );
  });

  testWidgets('Del deletes a self-contained selection without asking',
      (tester) async {
    await pumpEditor(tester);
    final (a, b, m) = buildSmallConstruction();
    container
        .read(selectionProvider.notifier)
        .selectMany([a.id, b.id, m.id]);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(container.read(constructionProvider).construction.isEmpty, isTrue);
  });

  testWidgets('Del warns when the cascade reaches beyond the selection',
      (tester) async {
    await pumpEditor(tester);
    final (a, _, _) = buildSmallConstruction();
    container.read(selectionProvider.notifier).select(a.id);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.text('Delete dependent objects too?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await tester.pumpAndSettle();
    final construction = container.read(constructionProvider).construction;
    expect(construction.length, 1, reason: 'a and the midpoint are gone');
    expect(construction.contains('b'), isTrue);
  });

  testWidgets('arrow keys nudge with camera semantics, repeating',
      (tester) async {
    await pumpEditor(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    var pan = container.read(viewportProvider).pan;
    expect(pan.x, greaterThan(0), reason: '→ looks further right');
    expect(pan.y, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    pan = container.read(viewportProvider).pan;
    expect(pan.y, greaterThan(0), reason: '↑ looks further up (world y-up)');
    expect(
      pan.y,
      2 * 32,
      reason: 'held arrows auto-repeat: one press + one repeat',
    );
  });

  testWidgets('zoom keys: in, out, and back to 100 % about the center',
      (tester) async {
    await pumpEditor(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    expect(container.read(viewportProvider).scale, closeTo(1.2, 1e-12));

    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    expect(container.read(viewportProvider).scale, closeTo(1, 1e-12));

    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    expect(container.read(viewportProvider).scale, 1);
  });

  testWidgets('F fits the construction', (tester) async {
    await pumpEditor(tester);
    container.read(commandStackProvider.notifier).execute(
          AddObjectCommand(
            FreePoint(id: 'far', position: const Vec2(100, 100)),
          ),
        );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    final viewport = container.read(viewportProvider);
    expect(viewport.scale, 1, reason: 'single point centers at 100 %');
    expect(viewport.pan, isNot(Vec2.zero));
  });

  testWidgets('Ctrl/Cmd+N asks before discarding a construction',
      (tester) async {
    await pumpEditor(tester);
    buildSmallConstruction();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('New construction'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(container.read(constructionProvider).construction.isEmpty, isTrue);
  });

  testWidgets('Ctrl/Cmd+D toggles the theme', (tester) async {
    await pumpEditor(tester);
    expect(container.read(themeModeProvider), ThemeMode.system);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    // The test surface renders light, so the toggle lands on dark.
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('shortcuts stand down while a text field is focused',
      (tester) async {
    await pumpEditor(tester);
    final (a, _, _) = buildSmallConstruction();
    container.read(selectionProvider.notifier).select(a.id);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(activeTool(), isNull, reason: 'typing a name must not switch tools');

    // Clicking the canvas takes focus back; shortcuts revive.
    await tester.tap(find.byType(GeometryCanvas), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    expect(activeTool(), isA<PointTool>());
  });
}
