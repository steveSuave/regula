import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/construction_provider.dart';
import 'package:regula/application/providers/selection_provider.dart';
import 'package:regula/application/providers/tool_provider.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/tools/point_tool.dart';
import 'package:regula/main.dart';
import 'package:regula/presentation/panels/attributes_inspector.dart';
import 'package:regula/presentation/panels/object_tree_panel.dart';
import 'package:regula/presentation/panels/toolbar.dart';
import 'package:regula/presentation/shortcuts/cheat_sheet.dart';

/// Phase 25 compact chrome (single-row revision) + Phase 42 responsive
/// split: panel placement (drawers vs docked) follows the 600-px
/// shortest-side breakpoint, app-bar density follows the window width —
/// below ~980 px the bar is one slim 48-px row with the toolbar
/// scrolling in the title slot and File + the loose icon buttons in one
/// overflow menu. The tree toggle is an explicit leading icon in every
/// layout (never Material's auto-hamburger); iPad portrait gets compact
/// chrome over docked panels; at desktop sizes the wide layout must be
/// exactly as before.
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

    testWidgets('app bar is one slim row: the toolbar scrolls in the title '
        'slot, File and the loose icons collapse into one overflow menu',
        (tester) async {
      await pumpEditor(tester, screen: phone);

      // The toolbar lives in a horizontal scroll view inside the app bar,
      // not among the actions.
      expect(
        find.ancestor(
          of: find.byType(GeometryToolbar),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );

      // Single row, slimmer than the 56-px Material default — no second
      // strip below.
      expect(tester.getSize(find.byType(AppBar)).height, 48);

      // App bar keeps undo/redo + overflow; File and the loose icon
      // buttons are gone. The leading slot holds the explicit tree
      // icon — not Material's auto-hamburger.
      expect(inAppBar(find.byIcon(Icons.undo)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.redo)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.more_vert)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.folder_outlined)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.fit_screen)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.filter_center_focus)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.keyboard_outlined)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.light_mode_outlined)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.dark_mode_outlined)), findsNothing);
      expect(
        inAppBar(find.byIcon(Icons.account_tree_outlined)),
        findsOneWidget,
      );
      expect(inAppBar(find.byType(DrawerButton)), findsNothing);
      expect(inAppBar(find.byIcon(Icons.menu)), findsNothing);

      // The absorbed File actions live in the overflow menu.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Open…'), findsOneWidget);
      expect(find.text('Save…'), findsOneWidget);
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
      // Narrow enough that seven 48-px groups (336 px) cannot fit.
      await pumpEditor(tester, screen: const Size(250, 600));

      final scrollable = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      // All seven groups stay reachable by scrolling to the end.
      await tester.drag(scrollable, const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(find.byIcon(Icons.straighten), findsOneWidget);
    });

    testWidgets('overflow menu drives the absorbed actions — the object '
        'tree opens as a drawer and the cheat sheet opens', (tester) async {
      await pumpEditor(tester, screen: phone);
      expect(find.byType(ObjectTreePanel), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show object tree'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(ObjectTreePanel),
        ),
        findsOneWidget,
      );

      // Close the drawer before reaching for the overflow menu again.
      await tester.tapAt(const Offset(350, 400));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keyboard shortcuts'));
      await tester.pumpAndSettle();
      expect(find.byType(ShortcutCheatSheet), findsOneWidget);
    });

    testWidgets('the leading tree icon opens the object-tree drawer',
        (tester) async {
      await pumpEditor(tester, screen: phone);
      expect(find.byType(ObjectTreePanel), findsNothing);

      await tester.tap(inAppBar(find.byIcon(Icons.account_tree_outlined)));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(ObjectTreePanel),
        ),
        findsOneWidget,
      );
    });

    testWidgets('style button appears with the selection and opens the '
        'inspector drawer — never auto-opens', (tester) async {
      await pumpEditor(tester, screen: phone);
      expect(find.byIcon(Icons.palette_outlined), findsNothing);

      container
          .read(constructionProvider)
          .construction
          .add(FreePoint(id: 'a', position: Vec2.zero));
      container.read(selectionProvider.notifier).select('a');
      await tester.pump();

      // Selection made: the button is there, but no drawer opened itself.
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);

      await tester.tap(find.byIcon(Icons.palette_outlined));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(AttributesInspector),
        ),
        findsOneWidget,
      );
      expect(find.text('Point'), findsOneWidget);
    });
  });

  group('tablet portrait (compact chrome over docked panels)', () {
    // iPad-portrait-ish: shortestSide ≥ 600 keeps the panels docked,
    // but the width can't fit the wide action cluster — before the
    // Phase 42 split, NavigationToolbar painted the trailing cluster
    // over the leading tree icon here.
    const tabletPortrait = Size(810, 1080);

    testWidgets('app bar is the compact row, panels stay docked — '
        'no drawers', (tester) async {
      await pumpEditor(tester, screen: tabletPortrait);

      // Compact chrome: slim row, toolbar scrolls in the title slot,
      // loose icons collapsed into the overflow menu.
      expect(tester.getSize(find.byType(AppBar)).height, 48);
      expect(
        find.ancestor(
          of: find.byType(GeometryToolbar),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(inAppBar(find.byIcon(Icons.more_vert)), findsOneWidget);
      expect(inAppBar(find.byIcon(Icons.folder_outlined)), findsNothing);

      // Docked panels: no drawers at this size.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNull);
      expect(scaffold.endDrawer, isNull);
    });

    testWidgets('the leading tree icon is hit-testable and toggles the '
        'docked panel — no overlap, no drawer', (tester) async {
      await pumpEditor(tester, screen: tabletPortrait);
      expect(find.byType(ObjectTreePanel), findsNothing);

      // The tap proves nothing paints over the leading icon: a covered
      // button would receive no hit.
      await tester.tap(inAppBar(find.byIcon(Icons.account_tree_outlined)));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectTreePanel), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);

      await tester.tap(inAppBar(find.byIcon(Icons.account_tree_outlined)));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectTreePanel), findsNothing);
    });

    testWidgets('overflow "Show object tree" toggles the docked panel '
        'and relabels to Hide', (tester) async {
      await pumpEditor(tester, screen: tabletPortrait);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show object tree'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectTreePanel), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide object tree'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectTreePanel), findsNothing);
    });

    testWidgets('no style button with a selection — the docked inspector '
        'is already visible', (tester) async {
      await pumpEditor(tester, screen: tabletPortrait);

      container
          .read(constructionProvider)
          .construction
          .add(FreePoint(id: 'a', position: Vec2.zero));
      container.read(selectionProvider.notifier).select('a');
      await tester.pump();

      expect(find.byIcon(Icons.palette_outlined), findsNothing);
      expect(find.byType(AttributesInspector), findsOneWidget);
    });
  });

  group('wide (desktop-sized screen)', () {
    testWidgets('the cluster fits at the wide-chrome floor — the leading '
        'icon stays hit-testable with the Measure group aboard (Phase 38 '
        're-measure of the 980 px constant)', (tester) async {
      // Exactly the gate: any narrower flips to compact chrome. If the
      // wide action cluster ever outgrows this width again, the trailing
      // cluster paints over the leading icon and this tap goes dead —
      // widen the constant, not this test.
      await pumpEditor(tester, screen: const Size(980, 700));

      expect(inAppBar(find.byIcon(Icons.more_vert)), findsNothing,
          reason: 'wide chrome at the gate width');
      await tester.tap(inAppBar(find.byIcon(Icons.account_tree_outlined)));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectTreePanel), findsOneWidget);
    });

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

      // Panels stay inline: no drawers on desktop.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNull);
      expect(scaffold.endDrawer, isNull);
    });
  });
}
