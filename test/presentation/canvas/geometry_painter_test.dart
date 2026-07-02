import 'dart:ui';

import 'package:fgex/application/providers/viewport_provider.dart';
import 'package:fgex/domain/construction/construction.dart';
import 'package:fgex/domain/construction/object_attributes.dart';
import 'package:fgex/domain/construction/objects/circle_center_point.dart';
import 'package:fgex/domain/construction/objects/free_point.dart';
import 'package:fgex/domain/construction/objects/line_through_two_points.dart';
import 'package:fgex/domain/construction/objects/midpoint.dart';
import 'package:fgex/domain/construction/objects/segment.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/presentation/canvas/canvas_viewport.dart';
import 'package:fgex/presentation/canvas/geometry_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel-accurate rendering is Phase 12's golden tests; here we assert
/// the painter accepts every current object kind — including undefined
/// and invisible ones — without throwing.
void main() {
  GeometryPainter painterFor(Construction construction, {int revision = 0}) =>
      GeometryPainter(
        construction: construction,
        viewport: const CanvasViewport(ViewportState()),
        revision: revision,
        defaultColor: const Color(0xFF000000),
      );

  void paintOnce(GeometryPainter painter) {
    final recorder = PictureRecorder();
    painter.paint(Canvas(recorder), const Size(800, 600));
    recorder.endRecording();
  }

  group('GeometryPainter', () {
    test('paints every object kind without throwing', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(Midpoint(id: 'm', point1: a, point2: b))
        ..add(Segment(id: 's', point1: a, point2: b))
        ..add(LineThroughTwoPoints(id: 'l', point1: a, point2: c))
        ..add(CircleCenterPoint(id: 'k', center: a, onCircle: b));

      paintOnce(painterFor(construction));
    });

    test('skips undefined and invisible objects without throwing', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: Vec2.zero); // coincident
      construction
        ..add(a)
        ..add(b)
        // Undefined: line through coincident points.
        ..add(LineThroughTwoPoints(id: 'l', point1: a, point2: b))
        ..add(FreePoint(
          id: 'h',
          position: const Vec2(1, 1),
          attributes: const ObjectAttributes(visible: false),
        ));

      paintOnce(painterFor(construction));
    });

    test('paints preview markers without throwing', () {
      final construction = Construction()
        ..add(FreePoint(id: 'a', position: Vec2.zero));
      final painter = GeometryPainter(
        construction: construction,
        viewport: const CanvasViewport(ViewportState()),
        revision: 0,
        defaultColor: const Color(0xFF000000),
        previewMarkers: const [Vec2.zero, Vec2(3, 4)],
      );

      paintOnce(painter);
    });

    test('shouldRepaint keys on preview markers', () {
      final construction = Construction();
      GeometryPainter withMarkers(List<Vec2> markers) => GeometryPainter(
            construction: construction,
            viewport: const CanvasViewport(ViewportState()),
            revision: 0,
            defaultColor: const Color(0xFF000000),
            previewMarkers: markers,
          );

      final base = withMarkers(const [Vec2(1, 1)]);
      expect(withMarkers(const [Vec2(1, 1)]).shouldRepaint(base), isFalse);
      expect(
        withMarkers(const [Vec2(1, 1), Vec2(2, 2)]).shouldRepaint(base),
        isTrue,
      );
      expect(withMarkers(const []).shouldRepaint(base), isTrue,
          reason: 'markers must clear on commit/reset');
    });

    test(
        'shouldRepaint keys on construction instance, revision and '
        'viewport state', () {
      final construction = Construction()
        ..add(FreePoint(id: 'a', position: Vec2.zero));

      final base = painterFor(construction);
      expect(base.shouldRepaint(painterFor(construction)), isFalse);
      expect(
        painterFor(construction, revision: 1).shouldRepaint(base),
        isTrue,
      );
      expect(
        painterFor(Construction()).shouldRepaint(base),
        isTrue,
        reason: 'replace() swaps the construction but resets the revision '
            'to 0 — the instance change alone must trigger a repaint',
      );

      final panned = GeometryPainter(
        construction: construction,
        viewport: const CanvasViewport(ViewportState(pan: Vec2(1, 0))),
        revision: 0,
        defaultColor: const Color(0xFF000000),
      );
      expect(panned.shouldRepaint(base), isTrue);
    });
  });
}
