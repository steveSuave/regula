import 'package:fgex/application/providers/tool_provider.dart';
import 'package:fgex/domain/tools/intersection_tool.dart';
import 'package:fgex/domain/tools/isosceles_trapezium_macro_tool.dart';
import 'package:fgex/domain/tools/kite_macro_tool.dart';
import 'package:fgex/domain/tools/rectangle_macro_tool.dart';
import 'package:fgex/domain/tools/rhombus_macro_tool.dart';
import 'package:fgex/domain/tools/right_trapezium_macro_tool.dart';
import 'package:fgex/domain/tools/two_point_tool.dart';
import 'package:fgex/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the toolbar's group flyouts: activation, the active-group
/// highlight (including the segment-ratio closure that no canonicalized
/// tear-off can claim), and the deselect affordances. The double-click
/// deactivation flow itself is covered in `geometry_canvas_test.dart`.
void main() {
  late ProviderContainer container;

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

  Color? iconColor(WidgetTester tester, IconData icon) =>
      tester.widget<Icon>(find.byIcon(icon)).color;

  testWidgets('picking a flyout item activates its tool and highlights '
      'only that group', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intersection of two curves'));
    await tester.pumpAndSettle();

    expect(container.read(toolProvider).tool, isA<IntersectionTool>());
    final theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(iconColor(tester, Icons.control_point), theme.colorScheme.primary);
    expect(
      iconColor(tester, Icons.timeline),
      isNot(theme.colorScheme.primary),
    );
    expect(
      iconColor(tester, Icons.circle_outlined),
      isNot(theme.colorScheme.primary),
    );
  });

  testWidgets('the segment-ratio closure highlights Points, not Lines — '
      'the catch-all for non-tear-off builders', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segment-ratio point…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1/2');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(container.read(toolProvider).tool, isA<TwoPointTool>());
    final theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(iconColor(tester, Icons.control_point), theme.colorScheme.primary);
    expect(
      iconColor(tester, Icons.timeline),
      isNot(theme.colorScheme.primary),
    );
  });

  testWidgets('a single tap on the active group icon still opens its menu',
      (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Point'));
    await tester.pumpAndSettle();

    // While active, the ancestor double-tap recognizer holds the tap for
    // its timeout; only after it expires does the tap win and the flyout
    // open (with the tool still active).
    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(find.text('Midpoint'), findsOneWidget);
    expect(container.read(toolProvider).tool, isNotNull);
  });

  testWidgets('the active group tooltip advertises double-click to deselect',
      (tester) async {
    await pumpEditor(tester);
    // Shortcut keys live next to the flyout rows, not in the tooltip.
    const idleTooltip = 'Points: free, derived and constrained points';

    expect(find.byTooltip(idleTooltip), findsOneWidget);

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Point'));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('$idleTooltip — double-click to deselect'),
      findsOneWidget,
    );
    expect(find.byTooltip(idleTooltip), findsNothing);
  });

  testWidgets('every quadrilateral macro activates from the Macros flyout '
      'and highlights the group', (tester) async {
    await pumpEditor(tester);
    final rows = {
      'Rectangle (two corners, then height)': RectangleMacroTool,
      'Rhombus (two corners, then direction)': RhombusMacroTool,
      'Isosceles trapezium (base, then a top corner)':
          IsoscelesTrapeziumMacroTool,
      'Right trapezium (base, then the far corner)': RightTrapeziumMacroTool,
      'Kite (apex, side corner, apex)': KiteMacroTool,
    };
    final theme = Theme.of(tester.element(find.byType(AppBar)));

    for (final MapEntry(key: label, value: toolType) in rows.entries) {
      container.read(toolProvider.notifier).deactivate();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.crop_square));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(container.read(toolProvider).tool.runtimeType, toolType);
      expect(
        iconColor(tester, Icons.crop_square),
        theme.colorScheme.primary,
        reason: '$label must highlight the Macros group',
      );
    }
  });

  testWidgets('flyout rows show their shortcut as trailing text',
      (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.timeline));
    await tester.pumpAndSettle();

    // Each Lines row pairs its label with the table's display string.
    expect(find.text('Segment'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('Perpendicular line'), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
    expect(find.text('Angle bisector (arm, vertex, arm)'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
