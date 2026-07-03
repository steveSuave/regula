import 'dart:math' as math;

import 'package:fgex/application/providers/construction_provider.dart';
import 'package:fgex/application/providers/selection_provider.dart';
import 'package:fgex/application/providers/tool_provider.dart';
import 'package:fgex/domain/construction/objects/arc.dart';
import 'package:fgex/domain/construction/objects/compass_circle.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_angle.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/construction/objects/sector.dart';
import 'package:fgex/domain/construction/objects/segment_ratio_point.dart';
import 'package:fgex/domain/construction/objects/three_point_circle.dart';
import 'package:fgex/domain/construction/objects/vertex_angle.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/main.dart';
import 'package:fgex/presentation/canvas/geometry_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets(
      'three-point circle via the circles menu: three taps, one undo unit, '
      'and the circles icon (not the lines one) is highlighted',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Circle through three points'));
    await tester.pumpAndSettle();

    // Both menus activate a ThreePointTool; the highlight must follow
    // the builder, so only the circles icon lights up.
    final theme = Theme.of(tester.element(find.byType(AppBar)));
    Color? iconColor(IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color;
    expect(iconColor(Icons.circle_outlined), theme.colorScheme.primary);
    expect(iconColor(Icons.line_axis), isNot(theme.colorScheme.primary));

    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(300, 100));
    await tester.pump();
    expect(objectCount(), 0, reason: 'no commit until the third point');
    await tester.tapAt(origin + const Offset(100, 300));
    await tester.pump();
    expect(objectCount(), 4, reason: '3 free points + the circle');

    // Right angle at the first tap, so the circumcircle is centered on
    // the hypotenuse midpoint (world is y-up: taps sit at y < 0).
    final circle = container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<ThreePointCircle>()
        .single;
    expect(circle.circle!.center.closeTo(const Vec2(200, -200)), isTrue);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);
  });

  testWidgets(
      'compass via the circles menu: radius from the first two taps, '
      'centered on the third', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compass (radius points, then center)'));
    await tester.pumpAndSettle();

    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(150, 100));
    await tester.pump();
    expect(objectCount(), 0, reason: 'no commit until the center lands');
    await tester.tapAt(origin + const Offset(300, 300));
    await tester.pump();
    expect(objectCount(), 4, reason: '3 free points + the circle');

    final circle = container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<CompassCircle>()
        .single;
    expect(circle.circle!.center.closeTo(const Vec2(300, -300)), isTrue);
    expect(circle.circle!.radius, closeTo(50, 1e-9));

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);
  });

  testWidgets('ray via the two-point menu: two taps, one undo unit',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.timeline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ray (origin, then direction)'));
    await tester.pumpAndSettle();

    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 200));
    await tester.pump();
    expect(objectCount(), 3, reason: '2 free points + the ray');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);
  });

  testWidgets('arc via the circles menu: three taps, one undo unit',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arc (start, via, end)'));
    await tester.pumpAndSettle();

    await tester.tapAt(origin + const Offset(100, 100)); // start
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 180)); // via
    await tester.pump();
    expect(objectCount(), 0, reason: 'no commit until the end point');
    await tester.tapAt(origin + const Offset(300, 100)); // end
    await tester.pump();
    expect(objectCount(), 4, reason: '3 free points + the arc');

    final arc = container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<Arc>()
        .single;
    expect(arc.isDefined, isTrue);
    expect(arc.circle!.center.closeTo(const Vec2(200, -77.5)), isTrue);
    expect(arc.containsAngle(arc.circle!.angleAt(const Vec2(200, -180))),
        isTrue,
        reason: 'the drawn branch passes the via point');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);
  });

  testWidgets(
      'sector via the circles menu: center, rim (radius + start), '
      'then the angle point', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sector (center, rim, then angle)'));
    await tester.pumpAndSettle();

    await tester.tapAt(origin + const Offset(200, 200)); // center
    await tester.pump();
    await tester.tapAt(origin + const Offset(300, 200)); // rim
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 100)); // angle point
    await tester.pump();
    expect(objectCount(), 4, reason: '3 free points + the sector');

    final sector = container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<Sector>()
        .single;
    expect(sector.circle!.center.closeTo(const Vec2(200, -200)), isTrue);
    expect(sector.circle!.radius, closeTo(100, 1e-9));
    expect(sector.startAngle, closeTo(0, 1e-9));
    expect(sector.sweep, closeTo(math.pi / 2, 1e-9),
        reason: 'the third tap is straight up from the center (world '
            'is y-up), a quarter turn CCW from the rim');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);
  });

  testWidgets(
      'vertex angle via the angles menu: three taps, one undo unit, '
      'and the angles icon is highlighted', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.square_foot));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Angle at vertex (arm, vertex, arm)'));
    await tester.pumpAndSettle();

    // A ThreePointTool again — the angles icon must light up, not the
    // lines or circles ones.
    final theme = Theme.of(tester.element(find.byType(AppBar)));
    Color? iconColor(IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color;
    expect(iconColor(Icons.square_foot), theme.colorScheme.primary);
    expect(iconColor(Icons.circle_outlined), isNot(theme.colorScheme.primary));
    expect(iconColor(Icons.line_axis), isNot(theme.colorScheme.primary));

    await tester.tapAt(origin + const Offset(300, 100)); // arm
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100)); // vertex
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 10)); // arm
    await tester.pump();
    expect(objectCount(), 4, reason: '3 free points + the angle');

    final angle = container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<VertexAngle>()
        .single;
    expect(angle.angle!.vertex.closeTo(const Vec2(100, -100)), isTrue);
    expect(angle.angle!.measure, closeTo(math.pi / 2, 1e-9),
        reason: 'CCW from the +x arm to the +y arm (world is y-up)');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 0);
  });

  testWidgets(
      'line angle via the angles menu: tap two existing lines, '
      'marks the acute angle at their crossing', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    Future<void> makeLine(Offset from, Offset to) async {
      await tester.tap(find.byIcon(Icons.timeline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Line'));
      await tester.pumpAndSettle();
      await tester.tapAt(origin + from);
      await tester.pump();
      await tester.tapAt(origin + to);
      await tester.pump();
    }

    await makeLine(const Offset(100, 100), const Offset(300, 100));
    await makeLine(const Offset(100, 100), const Offset(100, 300));
    expect(objectCount(), 5,
        reason: 'the second line reuses the shared corner point');

    await tester.tap(find.byIcon(Icons.square_foot));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Angle between two lines'));
    await tester.pumpAndSettle();

    await tester.tapAt(origin + const Offset(200, 100)); // horizontal line
    await tester.pump();
    expect(objectCount(), 5, reason: 'no commit until the second line');
    await tester.tapAt(origin + const Offset(100, 200)); // vertical line
    await tester.pump();
    expect(objectCount(), 6);

    final angle = container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<LineAngle>()
        .single;
    expect(angle.angle!.vertex.closeTo(const Vec2(100, -100)), isTrue);
    expect(angle.angle!.measure, closeTo(math.pi / 2, 1e-9));

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(objectCount(), 5, reason: 'only the angle is one undo unit');
  });

  testWidgets(
      'move/select mode: tap selects, shift-tap toggles, empty tap clears',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    // Two points, then back to move/select mode.
    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 100));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.control_point)); // toggle off
    await tester.pump();

    final ids = [
      for (final object
          in container.read(constructionProvider).construction.objects)
        object.id,
    ];
    Set<String> selection() => container.read(selectionProvider);

    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(selection(), {ids[0]});

    // A plain click moves the selection rather than growing it.
    await tester.tapAt(origin + const Offset(200, 100));
    await tester.pump();
    expect(selection(), {ids[1]});

    // Shift-click adds…
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(selection(), {ids[0], ids[1]});

    // …and removes.
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(selection(), {ids[1]});
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    // Empty canvas clears (even a shift-click keeps nothing to toggle).
    await tester.tapAt(origin + const Offset(400, 300));
    await tester.pump();
    expect(selection(), isEmpty);
  });

  testWidgets('taps while a tool is active never touch the selection',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    // A point, selected in move/select mode.
    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.control_point)); // toggle off
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    final selected = container.read(selectionProvider);
    expect(selected, hasLength(1));

    // Back in the point tool: a tap the tool ignores (the existing
    // point) and one it commits (empty canvas) both leave the
    // selection alone.
    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 200));
    await tester.pump();
    expect(objectCount(), 2);
    expect(container.read(selectionProvider), selected);
  });

  testWidgets(
      'rubber band from empty canvas selects what it encloses; a band '
      'over nothing clears', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(200, 100));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.control_point)); // toggle off
    await tester.pump();

    final ids = [
      for (final object
          in container.read(constructionProvider).construction.objects)
        object.id,
    ];
    Set<String> selection() => container.read(selectionProvider);

    // Drag up-left from empty canvas across both points.
    final band = await tester.startGesture(origin + const Offset(350, 250));
    await band.moveTo(origin + const Offset(80, 60));
    await tester.pump();
    await band.up();
    await tester.pump();
    expect(selection(), {ids[0], ids[1]});

    // A band over empty space replaces the selection with nothing.
    final empty = await tester.startGesture(origin + const Offset(400, 300));
    await empty.moveTo(origin + const Offset(500, 400));
    await tester.pump();
    await empty.up();
    await tester.pump();
    expect(selection(), isEmpty);
  });

  testWidgets('shift rubber band adds to the selection instead of replacing',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(300, 100));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.control_point)); // toggle off
    await tester.pump();

    final ids = [
      for (final object
          in container.read(constructionProvider).construction.objects)
        object.id,
    ];

    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    expect(container.read(selectionProvider), {ids[0]});

    // Shift-band around only the second point keeps the first selected.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final band = await tester.startGesture(origin + const Offset(390, 160));
    await band.moveTo(origin + const Offset(260, 60));
    await tester.pump();
    await band.up();
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(container.read(selectionProvider), {ids[0], ids[1]});
  });

  testWidgets(
      'drags starting on an object, or with a tool active, do not '
      'rubber band', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();

    // Point tool still active: a drag across the point selects nothing.
    final toolDrag = await tester.startGesture(origin + const Offset(50, 50));
    await toolDrag.moveTo(origin + const Offset(300, 300));
    await tester.pump();
    await toolDrag.up();
    await tester.pump();
    expect(container.read(selectionProvider), isEmpty);

    await tester.tap(find.byIcon(Icons.control_point)); // toggle off
    await tester.pump();

    // Move/select mode, but the drag starts on the point itself: that is
    // a future move-drag, not a band.
    final onObject =
        await tester.startGesture(origin + const Offset(100, 100));
    await onObject.moveTo(origin + const Offset(300, 300));
    await tester.pump();
    await onObject.up();
    await tester.pump();
    expect(container.read(selectionProvider), isEmpty);
  });

  testWidgets('dragging a free point moves it; one undo restores it',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.control_point));
    await tester.pump();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.control_point)); // toggle off
    await tester.pump();

    FreePoint point() => container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<FreePoint>()
        .single;

    final drag = await tester.startGesture(origin + const Offset(100, 100));
    await drag.moveTo(origin + const Offset(250, 180));
    await tester.pump();
    expect(point().position, const Vec2(250, -180),
        reason: 'the preview tracks the pointer frame by frame');
    await drag.up();
    await tester.pump();
    expect(point().position, const Vec2(250, -180));

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(point().position, const Vec2(100, -100),
        reason: 'the whole gesture is one undo unit');
  });

  testWidgets(
      'dragging a segment rigidly translates its endpoints, one undo unit',
      (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.timeline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segment'));
    await tester.pumpAndSettle();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(300, 100));
    await tester.pump();
    container.read(toolProvider.notifier).deactivate(); // move/select mode
    await tester.pump();

    List<Vec2> endpoints() => [
          for (final object in container
              .read(constructionProvider)
              .construction
              .objects
              .whereType<FreePoint>())
            object.position,
        ];

    // Grab the segment between its endpoints and drag.
    final drag = await tester.startGesture(origin + const Offset(200, 100));
    await drag.moveTo(origin + const Offset(220, 160));
    await tester.pump();
    await drag.up();
    await tester.pump();
    expect(endpoints(), [const Vec2(120, -160), const Vec2(320, -160)],
        reason: 'both defining points shift by the drag delta');

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(endpoints(), [const Vec2(100, -100), const Vec2(300, -100)]);
  });

  testWidgets('a derived point refuses to drag', (tester) async {
    await pumpEditor(tester);
    final origin = tester.getTopLeft(find.byType(GeometryCanvas));

    await tester.tap(find.byIcon(Icons.timeline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Midpoint'));
    await tester.pumpAndSettle();
    await tester.tapAt(origin + const Offset(100, 100));
    await tester.pump();
    await tester.tapAt(origin + const Offset(300, 100));
    await tester.pump();
    container.read(toolProvider.notifier).deactivate(); // move/select mode
    await tester.pump();

    // The midpoint sits at (200, 100) on screen; dragging it does nothing
    // (and must not open a rubber band underneath it either).
    final drag = await tester.startGesture(origin + const Offset(200, 100));
    await drag.moveTo(origin + const Offset(300, 250));
    await tester.pump();
    await drag.up();
    await tester.pump();

    final midpoint = container
        .read(constructionProvider)
        .construction
        .objects
        .whereType<Midpoint>()
        .single;
    expect(midpoint.position, const Vec2(200, -100));
    expect(container.read(selectionProvider), isEmpty);
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
