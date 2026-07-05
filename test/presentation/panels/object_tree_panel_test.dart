import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/command_stack_provider.dart';
import 'package:regula/application/providers/construction_provider.dart';
import 'package:regula/application/providers/selection_provider.dart';
import 'package:regula/domain/construction/object_attributes.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/main.dart';
import 'package:regula/presentation/panels/object_tree_panel.dart';

void main() {
  late ProviderContainer container;

  /// The full editor, so the tree is reached the way the user reaches it:
  /// through the app-bar toggle.
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

  Future<void> openTree(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Show object tree'));
    await tester.pump();
  }

  FreePoint addPoint(String id, Vec2 position) {
    final point = FreePoint(id: id, position: position);
    container.read(constructionProvider).construction.add(point);
    return point;
  }

  testWidgets('hidden by default; the app-bar toggle shows and hides it',
      (tester) async {
    await pumpEditor(tester);
    expect(find.byType(ObjectTreePanel), findsNothing);

    await openTree(tester);
    expect(find.byType(ObjectTreePanel), findsOneWidget);
    expect(find.text('No objects yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide object tree'));
    await tester.pump();
    expect(find.byType(ObjectTreePanel), findsNothing);
  });

  testWidgets('groups objects by kind, names win over kind labels',
      (tester) async {
    await pumpEditor(tester);
    final a = FreePoint(
      id: 'a',
      position: Vec2.zero,
      attributes: const ObjectAttributes(name: 'A'),
    );
    container.read(constructionProvider).construction.add(a);
    final b = addPoint('b', const Vec2(2, 0));
    container
        .read(constructionProvider)
        .construction
        .add(Segment(id: 's', point1: a, point2: b));
    await openTree(tester);

    final tree = find.byType(ObjectTreePanel);
    expect(find.descendant(of: tree, matching: find.text('Points')),
        findsOneWidget);
    expect(find.descendant(of: tree, matching: find.text('Lines')),
        findsOneWidget);
    expect(find.descendant(of: tree, matching: find.text('Circles')),
        findsNothing, reason: 'empty groups are skipped');
    // Named point: name as title, kind as subtitle. Unnamed: kind only.
    expect(find.descendant(of: tree, matching: find.text('A')),
        findsOneWidget);
    expect(find.descendant(of: tree, matching: find.text('Segment')),
        findsOneWidget);
  });

  testWidgets('tap selects exactly that object; shift-tap toggles',
      (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = addPoint('b', const Vec2(2, 0));
    container
        .read(constructionProvider)
        .construction
        .add(Segment(id: 's', point1: a, point2: b));
    await openTree(tester);

    final tree = find.byType(ObjectTreePanel);
    await tester
        .tap(find.descendant(of: tree, matching: find.text('Segment')));
    await tester.pump();
    expect(container.read(selectionProvider), {'s'});

    // Plain tap replaces the selection...
    final pointRows = find.descendant(of: tree, matching: find.text('Point'));
    await tester.tap(pointRows.first);
    await tester.pump();
    expect(container.read(selectionProvider), {'a'});

    // ...shift-tap unions, and shift-tapping again removes.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(pointRows.last);
    await tester.pump();
    expect(container.read(selectionProvider), {'a', 'b'});
    await tester.tap(pointRows.first);
    await tester.pump();
    expect(container.read(selectionProvider), {'b'});
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });

  testWidgets('header tap selects every object of the kind, hidden included',
      (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final hidden = FreePoint(
      id: 'h',
      position: const Vec2(1, 1),
      attributes: const ObjectAttributes(visible: false),
    );
    container.read(constructionProvider).construction.add(hidden);
    container
        .read(constructionProvider)
        .construction
        .add(Segment(id: 's', point1: a, point2: hidden));
    container.read(selectionProvider.notifier).select('s');
    await openTree(tester);

    expect(find.byTooltip('Select all points'), findsOneWidget);
    final tree = find.byType(ObjectTreePanel);
    await tester
        .tap(find.descendant(of: tree, matching: find.text('Points')));
    await tester.pump();
    expect(container.read(selectionProvider), {'a', 'h'},
        reason: 'replaces the selection with exactly the kind, hidden and '
            'all — reaching hidden objects is the tree\'s raison d\'être');
  });

  testWidgets('header shift-tap and long-press union with a cross-kind '
      'selection', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = addPoint('b', const Vec2(2, 0));
    container
        .read(constructionProvider)
        .construction
        .add(Segment(id: 's', point1: a, point2: b));
    container.read(selectionProvider.notifier).select('s');
    await openTree(tester);

    final tree = find.byType(ObjectTreePanel);
    final header = find.descendant(of: tree, matching: find.text('Points'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(header);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(container.read(selectionProvider), {'s', 'a', 'b'});

    // Long-press is the touch shift: it also unions, never replaces.
    container.read(selectionProvider.notifier).select('s');
    await tester.longPress(header);
    await tester.pump();
    expect(container.read(selectionProvider), {'s', 'a', 'b'});
  });

  testWidgets('eye toggle hides as one undoable command and shows again',
      (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    await openTree(tester);

    await tester.tap(find.byTooltip('Hide'));
    await tester.pump();
    expect(a.attributes.visible, isFalse);
    expect(container.read(commandStackProvider).canUndo, isTrue);

    // The hidden object is unreachable on the canvas; the tree's eye is
    // the one-tap way back.
    await tester.tap(find.byTooltip('Show'));
    await tester.pump();
    expect(a.attributes.visible, isTrue);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(a.attributes.visible, isFalse,
        reason: 'each eye tap is its own undo step');
  });

  testWidgets('selecting a hidden object from the tree opens the inspector',
      (tester) async {
    await pumpEditor(tester);
    final hidden = FreePoint(
      id: 'h',
      position: Vec2.zero,
      attributes: const ObjectAttributes(visible: false),
    );
    container.read(constructionProvider).construction.add(hidden);
    await openTree(tester);

    final tree = find.byType(ObjectTreePanel);
    await tester
        .tap(find.descendant(of: tree, matching: find.text('Point')));
    await tester.pump();

    expect(container.read(selectionProvider), {'h'});
    // The inspector's name field only exists while something is selected.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('rows track construction changes: delete via undo removes the '
      'row', (tester) async {
    await pumpEditor(tester);
    addPoint('a', Vec2.zero);
    await openTree(tester);

    final tree = find.byType(ObjectTreePanel);
    expect(find.descendant(of: tree, matching: find.text('Point')),
        findsOneWidget);

    container.read(constructionProvider).construction.removeWithDependents('a');
    await tester.pump();
    expect(find.descendant(of: tree, matching: find.text('Point')),
        findsNothing);
    expect(find.text('No objects yet'), findsOneWidget);
  });
}
