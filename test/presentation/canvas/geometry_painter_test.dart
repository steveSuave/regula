import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/object_attributes.dart';
import 'package:regula/domain/construction/objects/arc.dart';
import 'package:regula/domain/construction/objects/circle_center_point.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/construction/objects/ray.dart';
import 'package:regula/domain/construction/objects/sector.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/vertex_angle.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/geometry_painter.dart';

/// Pixel-accurate rendering is Phase 12's golden tests; here we assert
/// the painter accepts every current object kind — including undefined
/// and invisible ones — without throwing.
void main() {
  GeometryPainter painterFor(
    Construction construction, {
    int revision = 0,
    Set<String> selectedIds = const {},
    Set<String> previewObjectIds = const {},
    bool showHidden = false,
  }) =>
      GeometryPainter(
        construction: construction,
        viewport: const CanvasViewport(ViewportState()),
        revision: revision,
        defaultColor: const Color(0xFF000000),
        selectionColor: const Color(0xFF0000FF),
        selectedIds: selectedIds,
        previewObjectIds: previewObjectIds,
        showHidden: showHidden,
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
        ..add(Ray(id: 'r', origin: a, through: c))
        ..add(LineThroughTwoPoints(id: 'l', point1: a, point2: c))
        ..add(CircleCenterPoint(id: 'k', center: a, onCircle: b))
        ..add(Arc(id: 'arc', start: b, via: c, end: a))
        ..add(Sector(id: 'w', center: a, start: b, end: c))
        ..add(VertexAngle(id: 'g', arm1: b, vertex: a, arm2: c));

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

    test('paints labels on named objects without throwing', () {
      const named = ObjectAttributes(name: 'A');
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero, attributes: named);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(Segment(id: 's', point1: a, point2: b, attributes: named))
        ..add(Ray(id: 'r', origin: a, through: c, attributes: named))
        ..add(LineThroughTwoPoints(
            id: 'l', point1: a, point2: c, attributes: named))
        ..add(CircleCenterPoint(
            id: 'k', center: a, onCircle: b, attributes: named))
        ..add(Arc(id: 'arc', start: b, via: c, end: a, attributes: named))
        ..add(Sector(id: 'w', center: a, start: b, end: c, attributes: named))
        ..add(VertexAngle(
            id: 'g', arm1: b, vertex: a, arm2: c, attributes: named))
        // labelVisible off: name present but no label painted.
        ..add(FreePoint(
          id: 'q',
          position: const Vec2(1, 1),
          attributes: const ObjectAttributes(name: 'Q', labelVisible: false),
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
        selectionColor: const Color(0xFF0000FF),
        previewMarkers: const [Vec2.zero, Vec2(3, 4)],
      );

      paintOnce(painter);
    });

    test('paints selection halos on every object kind without throwing', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(Segment(id: 's', point1: a, point2: b))
        ..add(Ray(id: 'r', origin: a, through: c))
        ..add(LineThroughTwoPoints(id: 'l', point1: a, point2: c))
        ..add(CircleCenterPoint(id: 'k', center: a, onCircle: b))
        ..add(Arc(id: 'arc', start: b, via: c, end: a))
        ..add(Sector(id: 'w', center: a, start: b, end: c))
        ..add(VertexAngle(id: 'g', arm1: b, vertex: a, arm2: c));

      final everything = {
        for (final object in construction.objects) object.id,
      };
      paintOnce(painterFor(construction, selectedIds: everything));
    });

    test('paints tool-input halos without throwing', () {
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      construction
        ..add(a)
        ..add(b)
        ..add(Segment(id: 's', point1: a, point2: b));

      paintOnce(painterFor(construction, previewObjectIds: const {'s', 'a'}));
    });

    test('showHidden paints dimmed hidden objects without throwing', () {
      const hidden = ObjectAttributes(visible: false);
      const hiddenNamed = ObjectAttributes(visible: false, name: 'S');
      const hiddenFilled =
          ObjectAttributes(visible: false, fillAlpha: 0.25, name: 'W');
      final construction = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero, attributes: hidden);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final c = FreePoint(id: 'c', position: const Vec2(0, 3));
      construction
        ..add(a)
        ..add(b)
        ..add(c)
        ..add(Segment(id: 's', point1: a, point2: b, attributes: hiddenNamed))
        ..add(Sector(id: 'w', center: a, start: b, end: c,
            attributes: hiddenFilled));

      // Dimmed halo too: hiding keeps the selection.
      paintOnce(painterFor(
        construction,
        showHidden: true,
        selectedIds: const {'a', 's'},
      ));
    });

    test('shouldRepaint keys on showHidden', () {
      final construction = Construction()
        ..add(FreePoint(id: 'a', position: Vec2.zero));

      final base = painterFor(construction);
      expect(
        painterFor(construction, showHidden: true).shouldRepaint(base),
        isTrue,
        reason: 'activating Show/Hide must dim hidden objects in',
      );
      expect(painterFor(construction).shouldRepaint(base), isFalse);
    });

    test('shouldRepaint keys on preview markers', () {
      final construction = Construction();
      GeometryPainter withMarkers(List<Vec2> markers) => GeometryPainter(
            construction: construction,
            viewport: const CanvasViewport(ViewportState()),
            revision: 0,
            defaultColor: const Color(0xFF000000),
            selectionColor: const Color(0xFF0000FF),
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
        selectionColor: const Color(0xFF0000FF),
      );
      expect(panned.shouldRepaint(base), isTrue);
    });

    test('shouldRepaint keys on the preview-object-id set', () {
      final construction = Construction()
        ..add(FreePoint(id: 'a', position: Vec2.zero));

      final base = painterFor(construction, previewObjectIds: const {'a'});
      expect(
        painterFor(construction, previewObjectIds: const {'a'})
            .shouldRepaint(base),
        isFalse,
        reason: 'set equality, not identity — the canvas rebuilds sets',
      );
      expect(painterFor(construction).shouldRepaint(base), isTrue,
          reason: 'the halo must clear on commit/reset');
    });

    test('shouldRepaint keys on the selected-id set', () {
      final construction = Construction()
        ..add(FreePoint(id: 'a', position: Vec2.zero));

      final base = painterFor(construction, selectedIds: const {'a'});
      expect(
        painterFor(construction, selectedIds: const {'a'})
            .shouldRepaint(base),
        isFalse,
        reason: 'set equality, not identity — the provider rebuilds sets',
      );
      expect(painterFor(construction).shouldRepaint(base), isTrue,
          reason: 'clearing the selection must drop the halo');
      expect(
        painterFor(construction, selectedIds: const {'b'}).shouldRepaint(base),
        isTrue,
      );
    });
  });
}
