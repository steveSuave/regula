// Intent 004, milestone 3, stage A: a polygon over points of space and a
// point on an edge of space, as the screen sees them.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/object_attributes.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/point_on_object.dart';
import 'package:regula/domain/construction/objects/polygon.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/presentation/canvas/canvas_hit_tester.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/geometry_painter.dart';
import 'package:regula/presentation/canvas/label_layout.dart';
import 'package:regula/presentation/canvas/screen_figure.dart';
import 'package:regula/presentation/canvas/space_hit_tester.dart';

const _size = Size(800, 600);

CanvasViewport _camera({double tilt = 0, double rotation = 0}) =>
    CanvasViewport(
      ViewportState(pan: const Vec2(-400, 300), tilt: tilt, rotation: rotation),
    );

void main() {
  const oblique = math.pi / 3;
  late Construction c;
  late FreePoint a;
  late FreePoint b;
  late FreePoint apex;
  late Polygon face;
  late Segment edge;

  setUp(() {
    c = Construction();
    a = FreePoint(id: 'a', position: const Vec2(-100, -50));
    b = FreePoint(id: 'b', position: const Vec2(100, -50));
    apex = FreePoint(id: 'o', position: const Vec2(0, 50), height: 120);
    face = Polygon(
      id: 'p',
      vertices: [a, b, apex],
      attributes: const ObjectAttributes(fillAlpha: 0.25, name: 'F'),
    );
    edge = Segment(id: 'e', point1: a, point2: apex);
    c
      ..add(a)
      ..add(b)
      ..add(apex)
      ..add(face)
      ..add(edge);
  });

  group('a polygon over points of space', () {
    test('is drawn from space: its outline and interior are the projected '
        'vertices', () {
      final viewport = _camera(tilt: oblique, rotation: 0.3);
      expect(drawnInSpace(face), isTrue);
      final ink = screenInkOf(c.objects, viewport, _size, face);
      final corners = [
        for (final v in face.spaceVertices!) viewport.spaceToScreen(v),
      ];
      expect(ink.fill, corners);
      expect(ink.segments, [
        (corners[0], corners[1]),
        (corners[1], corners[2]),
        (corners[2], corners[0]),
      ]);
      expect(ink.segmentDepths, hasLength(3));
    });

    test('on one sheet it is not, and its ink is what it was', () {
      c.setFreePointHeight('o', 0);
      expect(drawnInSpace(face), isFalse);
      final viewport = _camera(tilt: oblique);
      final ink = screenInkOf(c.objects, viewport, _size, face);
      expect(ink.fill, [
        for (final v in face.polygonVertices!) viewport.worldToScreen(v),
      ]);
      expect(ink.segmentDepths, isNull);
    });

    test('a tap inside it hits it, below the edge and the points, and its '
        'depth there is its own plane\'s', () {
      const tester = SpaceHitTester();
      final viewport = _camera(tilt: oblique, rotation: 0.3);
      final centroid = const Vec3(0, -50 / 3, 40);
      final inside = viewport.spaceToScreen(centroid);
      expect(tester.hitTest(c.objects, viewport, _size, inside, 8), same(face));
      final ink = screenInkOf(c.objects, viewport, _size, face);
      expect(
        ink.nearest(inside, 0).depth,
        closeTo(viewport.depthOf(centroid), 1e-9),
      );

      final onEdge = viewport.spaceToScreen(const Vec3(-50, 0, 60));
      expect(tester.hitTestAll(c.objects, viewport, _size, onEdge, 8).take(2), [
        edge,
        face,
      ]);
      final far = viewport.spaceToScreen(const Vec3(300, 300, 0));
      expect(tester.hitTest(c.objects, viewport, _size, far, 8), isNull);
    });

    test('the planar hit tester and rubber band pass over it', () {
      const planar = CanvasHitTester();
      expect(
        planar.hitTestAll(c.objects, const Vec2(0, -20), 5),
        isNot(contains(face)),
      );
      expect(
        planar.objectsContainedIn(c.objects, (_) => true),
        isNot(contains(face)),
      );
    });

    test('it hangs its label from the mean of its vertices', () {
      final viewport = _camera(tilt: oblique);
      expect(spaceLabelAnchor(face), const Vec3(0, -50 / 3, 40));
      expect(labelScreenRect(face, viewport), isNotNull);
    });

    test('the painter fills and strokes it, selected or not, at any tilt', () {
      for (final tilt in [0.0, oblique, math.pi / 2, 2.5]) {
        final recorder = PictureRecorder();
        GeometryPainter(
          construction: c,
          viewport: _camera(tilt: tilt),
          revision: 0,
          defaultColor: const Color(0xFF000000),
          selectionColor: const Color(0xFF0000FF),
          selectedIds: const {'p'},
          highlightedIds: const {'p'},
        ).paint(Canvas(recorder), _size);
        recorder.endRecording();
      }
    });
  });

  group('a line of space on the screen', () {
    test(
      'the parameter under a pointer is that of the nearest drawn point',
      () {
        final viewport = _camera(tilt: oblique, rotation: 0.3);
        final at = edge.spaceParameterFrame!;
        for (final t in [0.0, 37.5, 120.0]) {
          final on = at.origin + at.direction * t;
          final screen = viewport.spaceToScreen(on);
          expect(
            spaceLineParameterAt(viewport, edge, screen),
            closeTo(t, 1e-9),
          );
          // Off the line, across it: the same point of it is nearest.
          final axis = spaceLineScreenAxis(viewport, edge)!.perUnit;
          final across = Offset(-axis.dy, axis.dx) / axis.distance * 9;
          expect(
            spaceLineParameterAt(viewport, edge, screen + across),
            closeTo(t, 1e-9),
          );
        }
      },
    );

    test('seen end-on it names no point', () {
      // An edge straight up, seen from straight above.
      final up = FreePoint(id: 'u', position: const Vec2(-100, -50), height: 9);
      final post = Segment(id: 'post', point1: a, point2: up);
      c
        ..add(up)
        ..add(post);
      expect(spaceLineScreenAxis(_camera(), post), isNull);
      expect(spaceLineParameterAt(_camera(), post, Offset.zero), isNull);
      expect(spaceLineScreenAxis(_camera(tilt: oblique), post), isNotNull);
    });

    test('a point glued to an edge is drawn and hit on the edge', () {
      const tester = SpaceHitTester();
      final viewport = _camera(tilt: oblique, rotation: 0.3);
      final g = PointOnObject.onSpaceLine(
        id: 'g',
        curve: edge,
        parameter: edge.spaceParameterOf(const Vec3(-50, 0, 60))!,
      );
      c.add(g);
      expect(drawnInSpace(g), isTrue);
      final screen = viewport.spaceToScreen(const Vec3(-50, 0, 60));
      final dot = screenInkOf(c.objects, viewport, _size, g).dot!;
      expect((dot - screen).distance, lessThan(1e-9));
      expect(tester.hitTest(c.objects, viewport, _size, screen, 8), same(g));
    });
  });
}
