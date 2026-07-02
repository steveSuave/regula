import 'package:fgex/application/providers/construction_provider.dart';
import 'package:fgex/domain/construction/objects/segment_ratio_point.dart';
import 'package:fgex/domain/math/vec2.dart';
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

  testWidgets(
      'centroid tool via the centers menu: three taps commit one undo unit',
      (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.change_history));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centroid'));
    await tester.pumpAndSettle();

    final origin = tester.getTopLeft(find.byType(GeometryCanvas));
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 100));
    await tester.pump();
    expect(objectCount(), 0,
        reason: 'nothing is committed until the third vertex lands');

    await tester.tapAt(origin + const Offset(150, 200));
    await tester.pump();
    expect(objectCount(), 4, reason: '3 free points + the centroid');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0,
        reason: 'the whole construction step is one undo unit');

    await tester.tap(find.byIcon(Icons.redo));
    await tester.pump();
    expect(objectCount(), 4);
  });

  testWidgets('undo mid-collection clears collected input, not an exception',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    // Place a point with the point tool.
    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(objectCount(), 1);

    // Collect it as a centroid vertex, then undo it away.
    await tester.tap(find.byIcon(Icons.change_history));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centroid'));
    await tester.pumpAndSettle();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);

    // Three fresh taps still work and count from scratch.
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(150, 200));
    await tester.pump();
    expect(objectCount(), 4);
  });

  testWidgets(
      'segment via the two-point menu, then a point constrained onto it',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.timeline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segment'));
    await tester.pumpAndSettle();

    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(objectCount(), 0,
        reason: 'first endpoint is only collected, not committed');
    await tester.tapAt(origin + const Offset(300, 100));
    await tester.pump();
    expect(objectCount(), 3, reason: '2 free points + the segment');

    // Constrain a point onto the segment: tap between the endpoints.
    await tester.tap(find.byIcon(Icons.gps_fixed));
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 103));
    await tester.pump();
    expect(objectCount(), 4);

    // Empty canvas is ignored by the point-on-object tool.
    await tester.tapAt(origin + const Offset(200, 300));
    await tester.pump();
    expect(objectCount(), 4);
  });

  testWidgets(
      'perpendicular via the menu: tap the line, tap empty canvas, one '
      'undo unit', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    // A horizontal line to be perpendicular to.
    await tester.tap(find.byIcon(Icons.timeline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Line'));
    await tester.pumpAndSettle();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(300, 100));
    await tester.pump();
    expect(objectCount(), 3, reason: '2 free points + the line');

    await tester.tap(find.byIcon(Icons.line_axis));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perpendicular line'));
    await tester.pumpAndSettle();

    // Tap the line away from its endpoints, then a spot off the line.
    await tester.tapAt(origin + const Offset(200, 102));
    await tester.pump();
    expect(objectCount(), 3, reason: 'the line fills a slot, no commit yet');
    await tester.tapAt(origin + const Offset(150, 250));
    await tester.pump();
    expect(objectCount(), 5, reason: 'new free point + the perpendicular');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 3, reason: 'point + perpendicular undo together');
  });

  testWidgets('angle bisector via the menu: three taps, one undo unit',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.line_axis));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Angle bisector (arm, vertex, arm)'));
    await tester.pumpAndSettle();

    await tester.tapAt(origin + const Offset(300, 100)); // arm
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100)); // vertex
    await tester.pump();
    expect(objectCount(), 0, reason: 'no commit until the second arm');
    await tester.tapAt(origin + const Offset(100, 300)); // arm
    await tester.pump();
    expect(objectCount(), 4, reason: '3 free points + the bisector');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);
  });

  testWidgets(
      'segment-ratio point via the menu: cancel does nothing, "1/4" builds '
      'the interpolated point', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    // Cancelling the ratio dialog activates nothing.
    await tester.tap(find.byIcon(Icons.timeline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segment-ratio point…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(objectCount(), 0);

    // Fraction input works; two taps commit one undo unit.
    await tester.tap(find.byIcon(Icons.timeline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segment-ratio point…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1/4');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(objectCount(), 0,
        reason: 'first endpoint is only collected, not committed');
    await tester.tapAt(origin + const Offset(300, 100));
    await tester.pump();
    expect(objectCount(), 3, reason: '2 free points + the ratio point');

    // World is y-up with the origin at the canvas top-left, so the taps
    // sit at (100, -100) and (300, -100); t = 1/4 lands at (150, -100).
    final ratioPoint = container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<SegmentRatioPoint>()
        .single;
    expect(ratioPoint.ratio, 0.25);
    expect(ratioPoint.position, const Vec2(150, -100));

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);
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
