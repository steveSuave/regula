import 'package:fgex/application/providers/command_stack_provider.dart';
import 'package:fgex/application/providers/construction_provider.dart';
import 'package:fgex/application/providers/selection_provider.dart';
import 'package:fgex/domain/construction/object_attributes.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/sector.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/construction/objects/vertex_angle.dart';
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

  testWidgets('single selection of a named object shows name + kind',
      (tester) async {
    await pumpEditor(tester);
    final point = FreePoint(
      id: 'a',
      position: Vec2.zero,
      attributes: const ObjectAttributes(name: 'A'),
    );
    container.read(constructionProvider).construction.add(point);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    expect(find.text('A — Point'), findsOneWidget);
    expect(find.text('Point'), findsNothing,
        reason: 'the kind-only header appears only for unnamed objects');
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

  testWidgets('color swatches: explicit color and back to Auto, one '
      'command each', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    await tester.tap(find.byTooltip('Red'));
    await tester.pump();
    expect(a.attributes.colorArgb, 0xFFE53935);

    await tester.tap(find.byTooltip('Auto'));
    await tester.pump();
    expect(a.attributes.colorArgb, isNull,
        reason: 'Auto must set the color back to the theme-default null, '
            'not leave the previous explicit color in place');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(a.attributes.colorArgb, 0xFFE53935,
        reason: 'each swatch tap is its own undo step');
  });

  testWidgets('re-tapping the color the whole selection already has adds '
      'nothing to the undo stack', (tester) async {
    await pumpEditor(tester);
    addPoint('a', Vec2.zero);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    await tester.tap(find.byTooltip('Auto'));
    await tester.pump();
    expect(container.read(commandStackProvider).canUndo, isFalse);
  });

  testWidgets('point size selector: points get it, strokes do not',
      (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    final pointSize = find.byKey(const ValueKey('point-size'));
    expect(pointSize, findsOneWidget);
    expect(find.byKey(const ValueKey('stroke-width')), findsNothing,
        reason: 'stroke width means nothing for a point-only selection');

    await tester
        .tap(find.descendant(of: pointSize, matching: find.text('8')));
    await tester.pump();
    expect(a.attributes.pointSize, 8.0);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(a.attributes.pointSize, 4.0);
  });

  testWidgets('mixed-kind selection: stroke width touches only the '
      'non-points', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = addPoint('b', const Vec2(4, 0));
    final s = Segment(id: 's', point1: a, point2: b);
    container.read(constructionProvider).construction.add(s);
    container.read(selectionProvider.notifier).selectMany(['a', 'b', 's']);
    await tester.pump();

    final strokeWidth = find.byKey(const ValueKey('stroke-width'));
    expect(strokeWidth, findsOneWidget);
    expect(find.byKey(const ValueKey('point-size')), findsOneWidget);

    await tester
        .tap(find.descendant(of: strokeWidth, matching: find.text('6')));
    await tester.pump();
    expect(s.attributes.strokeWidth, 6.0);
    expect(a.attributes.strokeWidth, 2.0,
        reason: 'points keep their (unused) stroke width — the command '
            'covers only the slice the control targets');
    expect(a.attributes.pointSize, 4.0);
  });

  testWidgets('dash selector: strokes only, one command per tap, undo '
      'restores solid', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = addPoint('b', const Vec2(4, 0));
    final s = Segment(id: 's', point1: a, point2: b);
    container.read(constructionProvider).construction.add(s);

    container.read(selectionProvider.notifier).select('a');
    await tester.pump();
    expect(find.byKey(const ValueKey('dash-style')), findsNothing,
        reason: 'dashing means nothing for a point-only selection');

    container.read(selectionProvider.notifier).select('s');
    await tester.pump();
    final dashStyle = find.byKey(const ValueKey('dash-style'));
    expect(dashStyle, findsOneWidget);
    final segments = find.descendant(
      of: dashStyle,
      matching: find.byType(SegmentedButton<double>),
    );
    expect(
      tester.getSize(segments).width,
      lessThanOrEqualTo(AttributesInspector.panelWidth - 32),
      reason: 'single-letter segments fit the panel inside its padding',
    );

    // Single-letter labels (Phase 25): 'M' is Medium, tooltip carries
    // the word.
    await tester
        .tap(find.descendant(of: dashStyle, matching: find.text('M')));
    await tester.pump();
    expect(s.attributes.dashPeriod, 8.0);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(s.attributes.dashPeriod, 0.0);
  });

  testWidgets('marker-radius selector: angles only, one command over the '
      'angle slice, undo restores the default', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', const Vec2(4, 0));
    final v = addPoint('v', Vec2.zero);
    final b = addPoint('b', const Vec2(1, 3));
    final s = Segment(id: 's', point1: a, point2: b);
    final angle = VertexAngle(id: 'ang', arm1: a, vertex: v, arm2: b);
    container.read(constructionProvider).construction
      ..add(s)
      ..add(angle);

    container.read(selectionProvider.notifier).select('s');
    await tester.pump();
    expect(find.byKey(const ValueKey('marker-radius')), findsNothing,
        reason: 'a marker radius means nothing without an angle selected');

    container.read(selectionProvider.notifier).select('ang');
    await tester.pump();
    expect(find.byKey(const ValueKey('dash-style')), findsNothing,
        reason: 'angle markers never dash — no silent no-op row');
    expect(find.byKey(const ValueKey('stroke-width')), findsOneWidget,
        reason: 'stroke width does apply to the marker outline');

    container.read(selectionProvider.notifier).selectMany(['s', 'ang']);
    await tester.pump();
    final markerRadius = find.byKey(const ValueKey('marker-radius'));
    await tester.scrollUntilVisible(
      markerRadius,
      100,
      scrollable: find.descendant(
        of: find.byType(AttributesInspector),
        matching: find.byType(Scrollable),
      ),
    );

    // 'L' also labels a dash preset — scope the tap to the radius row.
    await tester
        .tap(find.descendant(of: markerRadius, matching: find.text('L')));
    await tester.pump();
    expect(angle.attributes.angleMarkerRadius, 28.0);
    expect(s.attributes.angleMarkerRadius, 20.0,
        reason: 'the command covers only the angle slice');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(angle.attributes.angleMarkerRadius, 20.0);
  });

  testWidgets('fill checkbox: angles + sectors, tristate over a mixed '
      'selection, toggles fillAlpha null ↔ 0.25', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', const Vec2(4, 0));
    final v = addPoint('v', Vec2.zero);
    final b = addPoint('b', const Vec2(1, 3));
    final angle = VertexAngle(id: 'ang', arm1: a, vertex: v, arm2: b);
    final sector = Sector(
      id: 'sec',
      center: v,
      start: a,
      end: b,
      attributes: const ObjectAttributes(fillAlpha: 0.25),
    );
    container.read(constructionProvider).construction
      ..add(angle)
      ..add(sector);

    container.read(selectionProvider.notifier).select('a');
    await tester.pump();
    expect(find.widgetWithText(CheckboxListTile, 'Fill'), findsNothing,
        reason: 'points have no filled form');

    container.read(selectionProvider.notifier).selectMany(['ang', 'sec']);
    await tester.pump();
    final fill = find.widgetWithText(CheckboxListTile, 'Fill');
    await tester.scrollUntilVisible(
      fill,
      100,
      scrollable: find.descendant(
        of: find.byType(AttributesInspector),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.widget<CheckboxListTile>(fill).value, isNull,
        reason: 'one filled, one unfilled — the tristate dash');

    // Anything but all-on turns everything on…
    await tester.tap(fill);
    await tester.pump();
    expect(angle.attributes.fillAlpha, 0.25);
    expect(sector.attributes.fillAlpha, 0.25);
    expect(tester.widget<CheckboxListTile>(fill).value, isTrue);

    // …and all-on turns everything off.
    await tester.tap(fill);
    await tester.pump();
    expect(angle.attributes.fillAlpha, isNull);
    expect(sector.attributes.fillAlpha, isNull);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(angle.attributes.fillAlpha, 0.25,
        reason: 'the all-off toggle was one command over both kinds');
    expect(sector.attributes.fillAlpha, 0.25);
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
    // The dash selector pushed the read-only list below the lazy
    // ListView's fold — scroll it into existence first.
    await tester.scrollUntilVisible(
      find.text('Segment'),
      100,
      scrollable: find.descendant(
        of: find.byType(AttributesInspector),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Point'), findsNWidgets(2));
    expect(find.text('Segment'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('delete without dependents: no dialog, one undoable command, '
      'panel collapses', (tester) async {
    await pumpEditor(tester);
    addPoint('a', Vec2.zero);
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('delete-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'nothing beyond the selection is affected — no dialog');
    expect(
      container.read(constructionProvider).construction.contains('a'),
      isFalse,
    );
    expect(find.text('Point'), findsNothing,
        reason: 'the pruned selection collapses the panel');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(
      container.read(constructionProvider).construction.contains('a'),
      isTrue,
    );
  });

  testWidgets('delete with unselected dependents asks first; Cancel leaves '
      'everything in place', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = addPoint('b', const Vec2(4, 0));
    container.read(constructionProvider).construction.add(
          Segment(
            id: 's',
            point1: a,
            point2: b,
            attributes: const ObjectAttributes(name: 'base'),
          ),
        );
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('delete-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('base'), findsOneWidget,
        reason: 'the dialog lists the casualties by name');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      container.read(constructionProvider).construction.contains('s'),
      isTrue,
    );
    expect(container.read(commandStackProvider).canUndo, isFalse,
        reason: 'a cancelled delete must not touch the undo stack');
  });

  testWidgets('confirming a cascading delete removes the dependents in the '
      'same undo step', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = addPoint('b', const Vec2(4, 0));
    container
        .read(constructionProvider)
        .construction
        .add(Segment(id: 's', point1: a, point2: b));
    container.read(selectionProvider.notifier).select('a');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await tester.pumpAndSettle();

    final construction = container.read(constructionProvider).construction;
    expect(construction.contains('a'), isFalse);
    expect(construction.contains('s'), isFalse);
    expect(construction.contains('b'), isTrue,
        reason: 'the other endpoint does not depend on a');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(construction.contains('a'), isTrue);
    expect(construction.contains('s'), isTrue);
  });

  testWidgets('a selection already containing all its dependents deletes '
      'without asking', (tester) async {
    await pumpEditor(tester);
    final a = addPoint('a', Vec2.zero);
    final b = addPoint('b', const Vec2(4, 0));
    container
        .read(constructionProvider)
        .construction
        .add(Segment(id: 's', point1: a, point2: b));
    container.read(selectionProvider.notifier).selectMany(['a', 'b', 's']);
    await tester.pump();

    // The multi-selection list pushes the button below the fold.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('delete-button')),
      100,
      scrollable: find.descendant(
        of: find.byType(AttributesInspector),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('delete-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'the cascade reaches nothing beyond the selection');
    expect(container.read(constructionProvider).construction.isEmpty, isTrue);
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
