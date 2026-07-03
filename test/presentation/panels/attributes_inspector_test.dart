import 'package:fgex/application/providers/command_stack_provider.dart';
import 'package:fgex/application/providers/construction_provider.dart';
import 'package:fgex/application/providers/selection_provider.dart';
import 'package:fgex/domain/construction/object_attributes.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/main.dart';
import 'package:fgex/presentation/panels/attributes_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  /// The full editor, so the inspector's undo interplay is tested through
  /// the same app bar the user has.
  Future<void> pumpEditor(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditorScreen()),
      ),
    );
  }

  FreePoint addPoint(String id, Vec2 position) {
    final point = FreePoint(id: id, position: position);
    container.read(constructionProvider).construction.add(point);
    return point;
  }

  testWidgets('collapsed while the selection is empty', (tester) async {
    await pumpEditor(tester);
    addPoint('a', Vec2.zero);
    await tester.pump();

    expect(find.byType(AttributesInspector), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Point'), findsNothing);
  });

  testWidgets('single selection: kind header, rename commits one command, '
      'undo restores the old name', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    expect(find.text('Point'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(a.attributes.name, 'A');
    expect(container.read(commandStackProvider).canUndo, isTrue);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(a.attributes.name, '');
    expect(find.widgetWithText(TextField, 'A'), findsNothing,
        reason: 'undo swaps the field for one showing the restored name');
  });

  testWidgets('submitting an unchanged name adds nothing to the undo stack',
      (tester) async {
    await pumpEditor(tester);
    addPoint('a', Vec2.zero);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(container.read(commandStackProvider).canUndo, isFalse);
  });

  testWidgets('visibility toggle: one command, undo restores, and the '
      'hidden object stays in the inspector', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Visible'));
    await tester.pump();
    expect(a.attributes.visible, isFalse);
    expect(container.read(commandStackProvider).canUndo, isTrue);
    // Hidden but still selected: the panel is the way back to un-hiding.
    expect(find.text('Point'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(a.attributes.visible, isTrue);
  });

  testWidgets('label toggle flips labelVisible', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Show label'));
    await tester.pump();
    expect(a.attributes.labelVisible, isFalse);
    expect(a.attributes.visible, isTrue,
        reason: 'the two toggles must not bleed into each other');

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Show label'));
    await tester.pump();
    expect(a.attributes.labelVisible, isTrue);
  });

  testWidgets('multi-selection toggle: mixed resolves to all-on in one '
      'undoable command', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = FreePoint(
      id: 'b',
      position: const Vec2(4, 0),
      attributes: const ObjectAttributes(visible: false),
    );
    container.read(constructionProvider).construction.add(b);
    container.read(selectionProvider.notifier).selectMany(['a', 'b']);
    await tester.pump();

    final visibleTile = find.widgetWithText(CheckboxListTile, 'Visible');
    expect(
      tester.widget<CheckboxListTile>(visibleTile).value,
      isNull,
      reason: 'mixed visibility shows the tristate dash',
    );

    await tester.tap(visibleTile);
    await tester.pump();
    expect(a.attributes.visible, isTrue);
    expect(b.attributes.visible, isTrue);

    await tester.tap(visibleTile);
    await tester.pump();
    expect(a.attributes.visible, isFalse);
    expect(b.attributes.visible, isFalse);

    // One undo per tap: all-off -> all-on -> the original mixed state.
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(a.attributes.visible, isTrue);
    expect(b.attributes.visible, isTrue);
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(a.attributes.visible, isTrue);
    expect(b.attributes.visible, isFalse);
  });

  testWidgets('multi-selection: count header and a read-only list',
      (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = addPoint('b', const Vec2(4, 0));
    container
        .read(constructionProvider)
        .construction
        .add(Segment(id: 's', point1: a, point2: b));
    container.read(selectionProvider.notifier).selectMany(['a', 'b', 's']);
    await tester.pump();

    expect(find.text('3 selected'), findsOneWidget);
    expect(find.text('Point'), findsNWidgets(2));
    expect(find.text('Segment'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('clearing the selection collapses the panel again',
      (tester) async {
    await pumpEditor(tester);
    addPoint('a', Vec2.zero);
    final selection = container.read(selectionProvider.notifier);
    selection.select('a');
    await tester.pump();
    expect(find.text('Point'), findsOneWidget);

    selection.clear();
    await tester.pump();
    expect(find.text('Point'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('an object deleted out from under the selection drops out '
      'before the pruner runs', (tester) async {
    await pumpEditor(tester);
    addPoint('a', Vec2.zero);
    addPoint('b', const Vec2(4, 0));
    container.read(selectionProvider.notifier).selectMany(['a', 'b']);
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    container.read(constructionProvider).construction.removeWithDependents('a');
    await tester.pump();

    // Down to one object — the header is the survivor's kind, not a count.
    expect(find.text('Point'), findsOneWidget);
    expect(find.text('2 selected'), findsNothing);
  });
}
