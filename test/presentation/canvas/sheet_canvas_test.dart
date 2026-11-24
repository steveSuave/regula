import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/dash_path.dart';
import 'package:regula/presentation/canvas/sheet_canvas.dart';

void main() {
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  group('SheetCanvas at the identity', () {
    const viewport = CanvasViewport(
      ViewportState(pan: Vec2(-3, 2), scale: 20, rotation: 0.4),
    );

    test('forwards every call to the canvas unchanged', () {
      final canvas = _RecordingCanvas();
      final sheet = SheetCanvas(canvas, viewport);
      expect(sheet.isIdentity, isTrue);

      const rect = Rect.fromLTWH(10, 20, 80, 60);
      final path = Path()
        ..moveTo(1, 2)
        ..lineTo(30, 40);
      sheet
        ..drawLine(const Offset(1, 2), const Offset(3, 4), stroke)
        ..drawCircle(const Offset(50, 60), 25, stroke)
        ..drawDot(const Offset(7, 8), 4, stroke)
        ..drawArc(rect, 0.3, 1.1, true, stroke)
        ..drawPath(path, stroke)
        ..drawRect(rect, stroke);

      expect(canvas.calls, [
        ['drawLine', const Offset(1, 2), const Offset(3, 4), stroke],
        ['drawCircle', const Offset(50, 60), 25.0, stroke],
        ['drawCircle', const Offset(7, 8), 4.0, stroke],
        ['drawArc', rect, 0.3, 1.1, true, stroke],
        ['drawPath', path, stroke],
        ['drawRect', rect, stroke],
      ]);
      expect(identical(sheet.mapPath(path), path), isTrue);
      expect(sheet.toScreen(const Offset(5, 6)), const Offset(5, 6));
    });

    test('a dashed path is dashed exactly as the painter used to', () {
      final canvas = _RecordingCanvas();
      final path = Path()
        ..addOval(Rect.fromCircle(center: const Offset(100, 100), radius: 40));
      SheetCanvas(canvas, viewport).drawPath(path, stroke, dashPeriod: 12);

      final drawn = canvas.calls.single[1]! as Path;
      final expected = dashPath(path, 12);
      final drawnLengths = [
        for (final metric in drawn.computeMetrics()) metric.length,
      ];
      final expectedLengths = [
        for (final metric in expected.computeMetrics()) metric.length,
      ];
      expect(drawnLengths, expectedLengths);
      expect(drawn.getBounds(), expected.getBounds());
    });
  });

  group('SheetCanvas under a tilted camera', () {
    const tilt = 1.0;
    const viewport = CanvasViewport(
      ViewportState(pan: Vec2(-3, 2), scale: 20, tilt: tilt),
    );
    final squash = math.cos(tilt);

    test('a circle in the plane is drawn as an ellipse with its stroke '
        'width kept', () {
      final canvas = _RecordingCanvas();
      SheetCanvas(
        canvas,
        viewport,
      ).drawCircle(const Offset(200, 100), 50, stroke);

      final call = canvas.calls.single;
      expect(call[0], 'drawPath');
      final bounds = (call[1]! as Path).getBounds();
      expect(bounds.width, closeTo(100, 1e-3));
      expect(bounds.height, closeTo(100 * squash, 1e-3));
      expect(bounds.center.dx, closeTo(200, 1e-3));
      expect(bounds.center.dy, closeTo(100 * squash, 1e-3));
      expect((call[2]! as Paint).strokeWidth, 3);
    });

    test('a dot moves with its anchor and stays round', () {
      final canvas = _RecordingCanvas();
      SheetCanvas(canvas, viewport).drawDot(const Offset(200, 100), 6, stroke);

      final call = canvas.calls.single;
      expect(call[0], 'drawCircle');
      expect(call[1], viewport.sheetToScreen(const Offset(200, 100)));
      expect(call[2], 6.0);
    });

    test('a line stays a line between the mapped endpoints', () {
      final canvas = _RecordingCanvas();
      SheetCanvas(
        canvas,
        viewport,
      ).drawLine(const Offset(10, 20), const Offset(300, 400), stroke);

      final call = canvas.calls.single;
      expect(call[0], 'drawLine');
      expect(call[1], viewport.sheetToScreen(const Offset(10, 20)));
      expect(call[2], viewport.sheetToScreen(const Offset(300, 400)));
    });

    test('a wedge is one closed outline through its centre', () {
      final canvas = _RecordingCanvas();
      const rect = Rect.fromLTWH(100, 100, 80, 80);
      SheetCanvas(canvas, viewport).drawArc(rect, 0, math.pi / 2, true, stroke);

      final path = canvas.calls.single[1]! as Path;
      expect(path.computeMetrics().single.isClosed, isTrue);
      final centre = viewport.sheetToScreen(rect.center);
      expect(path.getBounds().left, closeTo(centre.dx, 1e-3));

      final open = _RecordingCanvas();
      SheetCanvas(open, viewport).drawArc(rect, 0, math.pi / 2, false, stroke);
      expect(
        (open.calls.single[1]! as Path).computeMetrics().single.isClosed,
        isFalse,
      );
    });

    test('dashes are cut on screen, so each keeps its full length', () {
      final canvas = _RecordingCanvas();
      final path = Path()
        ..addOval(Rect.fromCircle(center: const Offset(300, 300), radius: 200));
      SheetCanvas(canvas, viewport).drawPath(path, stroke, dashPeriod: 16);

      final lengths = [
        for (final metric in (canvas.calls.single[1]! as Path).computeMetrics())
          metric.length,
      ];
      expect(lengths.length, greaterThan(20));
      // Every dash but the last, which the contour's end may cut short.
      // Cut before the map instead, the dashes along the squashed side
      // would be 8·cos(tilt) ≈ 4.3 long; the slack is the arc-length
      // error of a flattened conic.
      for (final length in lengths.take(lengths.length - 1)) {
        expect(length, closeTo(8, 0.3));
      }
    });

    test('a rectangle is mapped as a path', () {
      final canvas = _RecordingCanvas();
      const rect = Rect.fromLTWH(0, 100, 50, 100);
      SheetCanvas(canvas, viewport).drawRect(rect, stroke);
      final bounds = (canvas.calls.single[1]! as Path).getBounds();
      expect(bounds.top, closeTo(100 * squash, 1e-3));
      expect(bounds.height, closeTo(100 * squash, 1e-3));
    });
  });
}

class _RecordingCanvas implements Canvas {
  final List<List<Object?>> calls = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      calls.add(['drawLine', p1, p2, paint]);

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      calls.add(['drawCircle', c, radius, paint]);

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) => calls.add(['drawArc', rect, startAngle, sweepAngle, useCenter, paint]);

  @override
  void drawPath(Path path, Paint paint) => calls.add(['drawPath', path, paint]);

  @override
  void drawRect(Rect rect, Paint paint) => calls.add(['drawRect', rect, paint]);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
