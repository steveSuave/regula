import 'package:fgex/application/providers/construction_provider.dart';
import 'package:fgex/main.dart';
import 'package:fgex/presentation/canvas/geometry_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end tool flow: activate the point tool, tap the canvas, see
/// free points appear in the construction, undo/redo them. This is the
/// widget-level counterpart of the Phase 5 web smoke test.
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

  int objectCount() =>
      container.read(constructionProvider).construction.length;

  testWidgets('tap with no active tool adds nothing', (tester) async {
    await pumpEditor(tester);

    await tester.tapAt(tester.getCenter(find.byType(GeometryCanvas)));
    await tester.pump();

    expect(objectCount(), 0);
  });

  testWidgets('point tool: tap to add points, tap a point again is ignored, '
      'undo/redo round-trips', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(GeometryCanvas));
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 150));
    await tester.pump();
    expect(objectCount(), 2);

    // Same spot again: the hit tester reports the existing point and the
    // point tool refuses to stack a coincident one on top.
    await tester.tapAt(origin + const Offset(200, 150));
    await tester.pump();
    expect(objectCount(), 2);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 1);

    await tester.tap(find.byIcon(Icons.redo));
    await tester.pump();
    expect(objectCount(), 2);
  });

  testWidgets('deactivating the point tool stops point placement',
      (tester) async {
    await pumpEditor(tester);
    final toolButton = find.byIcon(Icons.control_point);

    await tester.tap(toolButton);
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));
    await tester.tapAt(origin + const Offset(50, 50));
    await tester.pump();
    expect(objectCount(), 1);

    await tester.tap(toolButton); // toggle off
    await tester.pump();
    await tester.tapAt(origin + const Offset(150, 50));
    await tester.pump();
    expect(objectCount(), 1);
  });
}
