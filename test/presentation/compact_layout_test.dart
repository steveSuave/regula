import 'package:fgex/application/providers/tool_provider.dart';
import 'package:fgex/domain/tools/point_tool.dart';
import 'package:fgex/main.dart';
import 'package:fgex/presentation/panels/object_tree_panel.dart';
import 'package:fgex/presentation/panels/toolbar.dart';
import 'package:fgex/presentation/shortcuts/cheat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 25 compact chrome: below the 600-px shortest-side breakpoint the
/// toolbar becomes a scrollable strip under the app bar and the loose
/// icon buttons collapse into one overflow menu; at desktop sizes the
/// wide layout must be exactly as before.
void main() {
  late ProviderContainer container;

  Future<void> pumpEditor(WidgetTester tester, {required Size screen}) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditorScreen()),
      ),
    );
  }

  Finder inAppBar(Finder finder) =>
      find.descendant(of: find.byType(AppBar), matching: finder);

  group('compact (phone-sized screen)', () {
    const phone = Size(400, 800);

    testWidgets('toolbar moves to a strip under the app bar and the loose '
        'icons collapse into one overflow menu', (tester) async {
      await pumpEditor(tester, screen: phone);

      // The strip: the toolbar lives in a horizontal scroll view inside
      // the app bar's bottom, not among the actions.
      expect(
        find.ancestor(
          of: find.byType(GeometryToolbar),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );

      // App bar keeps File + undo/redo + overflow; the five loose icon
      // buttons and the object-tree leading toggle are gone.
      expect(inAppBar(find.byIcon(Icons.folder_outlined)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.undo)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.redo)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.more_vert)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.fit_screen)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.filter_center_focus)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.keyboard_outlined)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.light_mode_outlined)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.dark_mode_outlined)), findsNothing);
      expect(
        inAppBar(find.byIcon(Icons.account_tree_outlined)),
        findsNothing,
      );
    });

    testWidgets('strip flyouts still activate tools', (tester) async {
      await pumpEditor(tester, screen: phone);

      await tester.tap(find.byIcon(Icons.control_point));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Point'));
      await tester.pumpAndSettle();

      expect(container.read(toolProvider).tool, isA<PointTool>());
    });

    testWidgets('the strip scrolls when the groups overflow the screen',
        (tester) async {
      // Narrow enough that six 48-px groups (288 px) cannot fit.
      await pumpEditor(tester, screen: const Size(250, 600));

      final scrollable = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      // All six groups stay reachable by scrolling to the end.
      await tester.drag(scrollable, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
    });

    testWidgets('overflow menu drives the absorbed actions — object tree '
        'toggles and the cheat sheet opens', (tester) async {
      await pumpEditor(tester, screen: phone);
      expect(find.byType(ObjectTreePanel), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show object tree'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectTreePanel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keyboard shortcuts'));
      await tester.pumpAndSettle();
      expect(find.byType(ShortcutCheatSheet), findsOneWidget);
    });
  });

  group('wide (desktop-sized screen)', () {
    testWidgets('layout is unchanged: toolbar among the actions, all loose '
        'icons present, no strip, no overflow', (tester) async {
      await pumpEditor(tester, screen: const Size(1024, 768));

      // Toolbar sits directly in the actions row — not inside a scroll
      // view.
      expect(find.byType(GeometryToolbar), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(GeometryToolbar),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );

      expect(inAppBar(find.byIcon(Icons.account_tree_outlined)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.folder_outlined)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.fit_screen)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.filter_center_focus)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.keyboard_outlined)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.undo)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.redo)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.more_vert)), findsNothing);
    });
  });
}
