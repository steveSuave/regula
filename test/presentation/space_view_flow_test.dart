import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:regula/application/providers/command_stack_provider.dart';
import 'package:regula/application/providers/construction_provider.dart';
import 'package:regula/application/providers/space_view_provider.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/commands/add_object_command.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/main.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/fit_viewport.dart';
import 'package:regula/presentation/canvas/geometry_canvas.dart';
import 'package:regula/presentation/canvas/space_view.dart';

import '../editor_container.dart';

/// Intent 004, milestone 1: the 2D/3D button and what hangs off it, end
/// to end, at a wide window and at a phone's.
void main() {
  late ProviderContainer container;

  Future<void> pumpEditor(WidgetTester tester, Size screen) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = await editorContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditorScreen()),
      ),
    );
    final stack = container.read(commandStackProvider.notifier);
    for (final (id, position) in const [
      ('a', Vec2(100, -100)),
      ('b', Vec2(300, -100)),
      ('c', Vec2(300, -250)),
    ]) {
      stack.execute(AddObjectCommand(FreePoint(id: id, position: position)));
    }
    await tester.pump();
  }

  final barScrollable = find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(Scrollable),
  );

  /// Taps an app-bar control by tooltip, scrolling the bar to it first:
  /// on a phone the row is wider than the window.
  Future<void> tapInBar(WidgetTester tester, String tooltip) async {
    final target = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip(tooltip),
    );
    await tester.scrollUntilVisible(target, 80, scrollable: barScrollable);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  ViewportState view() => container.read(viewportProvider);
  bool spaceView() => container.read(spaceViewProvider);
  const centre = (x: 200.0, y: -175.0, z: 0.0);
  Offset centreOnScreen() => CanvasViewport(view()).spaceToScreen(centre);

  for (final (name, screen) in const [
    ('wide', Size(1280, 800)),
    ('phone', Size(400, 800)),
  ]) {
    group(name, () {
      testWidgets('launches planar, with no Views menu', (tester) async {
        await pumpEditor(tester, screen);
        expect(spaceView(), isFalse);
        expect(view().tilt, 0);
        expect(find.byTooltip('Views'), findsNothing);
        expect(find.byTooltip('3D view'), findsOneWidget);
      });

      testWidgets('the button tilts to the oblique view and back, the '
          'figure staying put', (tester) async {
        await pumpEditor(tester, screen);
        final planar = view();
        final before = centreOnScreen();

        await tapInBar(tester, '3D view');
        expect(spaceView(), isTrue);
        expect(view().tilt, obliqueTilt);
        expect(view().rotation, planar.rotation);
        expect(view().scale, planar.scale);
        expect((centreOnScreen() - before).distance, lessThan(1e-6));
        expect(find.byTooltip('Views'), findsOneWidget);

        await tapInBar(tester, '3D view: on');
        expect(spaceView(), isFalse);
        expect(view().tilt, 0);
        expect(view().panZ, 0);
        expect(view().pan.x, closeTo(planar.pan.x, 1e-9));
        expect(view().pan.y, closeTo(planar.pan.y, 1e-9));
        expect(find.byTooltip('Views'), findsNothing);
      });

      testWidgets('each preset in the Views menu sets its angles', (
        tester,
      ) async {
        await pumpEditor(tester, screen);
        await tapInBar(tester, '3D view');
        for (final preset in SpaceViewPreset.values) {
          final before = centreOnScreen();
          await tapInBar(tester, 'Views');
          await tester.tap(find.text(preset.label));
          await tester.pumpAndSettle();
          expect(view().rotation, preset.rotation, reason: preset.label);
          expect(view().tilt, preset.tilt, reason: preset.label);
          expect((centreOnScreen() - before).distance, lessThan(1e-6));
          expect(spaceView(), isTrue, reason: 'Top is still a space view');
        }
      });

      testWidgets('Fit frames the turned figure; Reset is the oblique '
          'view of the origin', (tester) async {
        await pumpEditor(tester, screen);
        await tapInBar(tester, '3D view');
        await tapInBar(tester, 'Views');
        await tester.tap(find.text('Oblique'));
        await tester.pumpAndSettle();

        await tapInBar(tester, 'Fit construction to view');
        final size = tester.getSize(find.byType(GeometryCanvas));
        expect(view().tilt, obliqueTilt);
        expect(view().rotation, -math.pi / 6);
        final fitted = CanvasViewport(view());
        for (final object
            in container
                .read(constructionProvider)
                .construction
                .objects
                .whereType<FreePoint>()) {
          final shown = fitted.worldToScreen(object.position!);
          expect(
            shown.dx,
            inInclusiveRange(
              fitMarginPx - 1e-6,
              size.width - fitMarginPx + 1e-6,
            ),
          );
          expect(
            shown.dy,
            inInclusiveRange(
              fitMarginPx - 1e-6,
              size.height - fitMarginPx + 1e-6,
            ),
          );
        }

        await tapInBar(tester, 'Reset view (origin at 100 %)');
        expect(view().scale, 1);
        expect(view().tilt, obliqueTilt);
        final origin = CanvasViewport(view()).worldToScreen(Vec2.zero);
        expect((origin - size.center(Offset.zero)).distance, lessThan(1e-6));
      });

      testWidgets('planar Fit and Reset are what they were', (tester) async {
        await pumpEditor(tester, screen);
        await tapInBar(tester, 'Fit construction to view');
        final size = tester.getSize(find.byType(GeometryCanvas));
        expect(
          view(),
          fittedViewport(
            container.read(constructionProvider).construction.objects,
            size,
          ),
        );
        await tapInBar(tester, 'Reset view (origin at 100 %)');
        expect(view(), const ViewportState());
      });

      testWidgets('File > New goes back to the planar view', (tester) async {
        await pumpEditor(tester, screen);
        await tapInBar(tester, '3D view');
        expect(view().tilt, obliqueTilt);

        await tapInBar(tester, 'File: new, open, save');
        await tester.tap(find.text('New'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        expect(spaceView(), isFalse);
        expect(view().tilt, 0);
        expect(view().panZ, 0);
        expect(find.byTooltip('Views'), findsNothing);
      });
    });
  }
}
