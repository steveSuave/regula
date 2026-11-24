// Intent 004, milestone 2, stage C: a camera as it sees one plane, and
// the painter, the hit test and the fit on a plane's sheet.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/objects/chart_point.dart';
import 'package:regula/domain/construction/objects/fixed_radius_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/plane_frame.dart';
import 'package:regula/presentation/canvas/canvas_hit_tester.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/fit_viewport.dart';
import 'package:regula/presentation/canvas/geometry_painter.dart';
import 'package:regula/presentation/canvas/label_layout.dart';
import 'package:regula/presentation/canvas/label_obstacles.dart';
import 'package:regula/presentation/canvas/lift_handle.dart';
import 'package:regula/presentation/canvas/screen_figure.dart';
import 'package:regula/presentation/canvas/space_hit_tester.dart';

const _size = Size(800, 600);

CanvasViewport _camera({double tilt = 1.0, double rotation = 0.3}) =>
    CanvasViewport(
      ViewportState(
        pan: const Vec2(-400, 300),
        tilt: tilt,
        rotation: rotation,
        scale: 1.5,
      ),
    );

/// A face through A, B and a lifted apex; a point, a circle and a line on
/// its sheet; an adapter for the apex.
class _Scene {
  _Scene() {
    for (final object in [a, b, apex, face, f, g, circle, line, adapter]) {
      c.add(object);
    }
  }

  final c = Construction();
  final a = FreePoint(id: 'a', position: const Vec2(0, 0));
  final b = FreePoint(id: 'b', position: const Vec2(200, 0));
  final apex = FreePoint(id: 'o', position: const Vec2(100, 100), height: 120);
  late final face = ThreePointPlane(
    id: 'face',
    point1: a,
    point2: b,
    point3: apex,
  );
  late final f = FreePoint(id: 'f', position: const Vec2(100, 60), plane: face);
  late final g = FreePoint(id: 'g', position: const Vec2(40, 30), plane: face);
  late final circle = FixedRadiusCircle(id: 'k', center: f, radius: 40);
  late final line = LineThroughTwoPoints(id: 'l', point1: f, point2: g);
  late final adapter = ChartPoint(id: 'co', source: apex, plane: face);
}

void main() {
  late _Scene s;
  late PlaneFrame frame;
  setUp(() {
    s = _Scene();
    frame = s.face.frame!;
  });

  group('PlaneViewport', () {
    test('sends a point of the plane to where the camera sees it', () {
      final camera = _camera();
      final view = PlaneViewport(camera, frame);
      for (final p in const [Vec2(0, 0), Vec2(100, 60), Vec2(-35, 210)]) {
        final seen = view.worldToScreen(p);
        final truth = camera.spaceToScreen(frame.lift(p));
        expect((seen - truth).distance, lessThan(1e-9));
        expect(view.screenToWorld(truth).distanceTo(p), lessThan(1e-9));
        expect(view.pickBasePlane(truth)!.distanceTo(p), lessThan(1e-9));
      }
      expect(view.isTilted, isTrue);
      expect(view.forObject(s.a), same(view));
      expect(view.flat.state.rotation, 0);
    });

    test('its sheet matrix is its sheet map', () {
      final view = PlaneViewport(_camera(), frame);
      final m = view.sheetMatrix;
      const flat = Offset(37, -52);
      final mapped = Offset(
        m[0] * flat.dx + m[4] * flat.dy + m[12],
        m[1] * flat.dx + m[5] * flat.dy + m[13],
      );
      expect((mapped - view.sheetToScreen(flat)).distance, lessThan(1e-12));
    });

    test('the camera hands it out for an object on that sheet, and itself '
        'for the base sheet and for no sheet', () {
      final camera = _camera();
      expect(camera.forObject(s.a), same(camera));
      expect(camera.forObject(s.face), same(camera));
      final view = camera.forObject(s.f);
      expect(view, isA<PlaneViewport>());
      expect((view as PlaneViewport).frame, frame);
    });

    test('the pulled-back frame contains what is on the canvas', () {
      final view = PlaneViewport(_camera(), frame);
      final region = view.flatFrame(_size, margin: 10);
      for (final corner in const [
        Offset(0, 0),
        Offset(800, 0),
        Offset(0, 600),
        Offset(800, 600),
        Offset(400, 300),
      ]) {
        final world = view.screenToWorld(corner);
        expect(
          region.inflate(1e-6).contains(view.flat.worldToScreen(world)),
          isTrue,
        );
      }
    });

    test('says when its plane is edge-on, and stays bounded there', () {
      // A vertical plane facing sideways, seen from the front.
      final wall = PlaneFrame.horizontal(Vec3.zero, const Vec3(1, 0, 0))!;
      final front = PlaneViewport(
        _camera(tilt: math.pi / 2, rotation: 0),
        wall,
      );
      expect(front.basePlanePickable, isFalse);
      expect(front.pickBasePlane(const Offset(100, 100)), isNull);
      expect(front.flatFrame(_size).isFinite, isTrue);
      expect(front.sheetShrink, CanvasViewport.pickFloor);
      final turned = PlaneViewport(
        _camera(tilt: math.pi / 2, rotation: 0.6),
        wall,
      );
      expect(turned.basePlanePickable, isTrue);
      expect(turned.sheetShrink, closeTo(math.sin(0.6), 1e-9));
    });

    test('the base camera\'s shrink is its old margin divisor', () {
      expect(_camera(tilt: 0).sheetShrink, 1);
      expect(_camera(tilt: 1.0).sheetShrink, math.cos(1.0));
      expect(_camera(tilt: math.pi / 2).sheetShrink, CanvasViewport.pickFloor);
    });

    test('the sheet depth under a pointer is the plane\'s there', () {
      final camera = _camera();
      final view = PlaneViewport(camera, frame);
      final at = frame.lift(const Vec2(70, 20));
      expect(
        view.sheetDepthAt(camera.spaceToScreen(at)),
        closeTo(camera.depthOf(at), 1e-9),
      );
    });
  });

  group('objects on a plane\'s sheet', () {
    test('their ink is where space puts them', () {
      final camera = _camera();
      expect(drawnInSpace(s.f), isFalse);
      final dot = screenInkOf(s.c.objects, camera, _size, s.f).dot!;
      expect(
        (dot - camera.spaceToScreen(s.f.spacePosition!)).distance,
        lessThan(1e-9),
      );

      // The circle of radius 40 about F: every chord end is 40 from F, in
      // space.
      final ink = screenInkOf(s.c.objects, camera, _size, s.circle);
      final view = PlaneViewport(camera, frame);
      for (final (from, _) in ink.segments) {
        final onPlane = frame.lift(view.screenToWorld(from));
        expect(onPlane.distanceTo(s.f.spacePosition!), closeTo(40, 1e-6));
      }
    });

    test('their labels hang where they are drawn', () {
      final camera = _camera();
      final at = labelBaseTopLeft(s.g, camera, const Size(10, 10));
      expect(
        (at - camera.spaceToScreen(s.g.spacePosition!)).distance,
        lessThan(1e-9),
      );
    });

    test('the lift handle rides a plane point along its plane\'s normal', () {
      final camera = _camera();
      final handle = LiftHandle.of(s.f, camera)!;
      final up =
          camera.spaceToScreen(s.f.spacePosition! + frame.normal) -
          camera.spaceToScreen(s.f.spacePosition!);
      expect((handle.axis - up / up.distance).distance, lessThan(1e-9));
      expect(handle.pixelsPerUnit, closeTo(up.distance, 1e-9));
    });

    test(
      'the painter draws them through their plane, and never an adapter',
      () {
        final camera = _camera();
        final canvas = _Recorder();
        GeometryPainter(
          construction: s.c,
          viewport: camera,
          revision: 0,
          defaultColor: const Color(0xFF000000),
          selectionColor: const Color(0xFF0000FF),
          showHidden: true,
        ).paint(canvas, _size);
        bool dotAt(Vec3 where) => canvas.circles.any(
          (c) => (c - camera.spaceToScreen(where)).distance < 1e-6,
        );
        expect(dotAt(s.f.spacePosition!), isTrue);
        expect(dotAt(s.g.spacePosition!), isTrue);
        expect(dotAt(s.a.spacePosition!), isTrue);
        // Five points are drawn: A, B, the apex, F and G. The adapter for
        // the apex is hidden scaffolding even with hidden objects shown.
        expect(canvas.circles, hasLength(5));
      },
    );

    test('the active plane gets an outline, and holds the preview markers', () {
      final camera = _camera();
      GeometryPainter painter(String? active) => GeometryPainter(
        construction: s.c,
        viewport: camera,
        revision: 0,
        defaultColor: const Color(0xFF000000),
        selectionColor: const Color(0xFF0000FF),
        activePlaneId: active,
        previewMarkers: const [Vec2(10, 20)],
      );
      final inFace = _Recorder();
      painter('face').paint(inFace, _size);
      final onBase = _Recorder();
      painter(null).paint(onBase, _size);

      expect(inFace.strokes.where((w) => w == 2.5), hasLength(1));
      expect(onBase.strokes.where((w) => w == 2.5), isEmpty);
      final marker = camera.spaceToScreen(frame.lift(const Vec2(10, 20)));
      expect(inFace.circles.any((c) => (c - marker).distance < 1e-6), isTrue);
      final baseMarker = camera.worldToScreen(const Vec2(10, 20));
      expect(
        onBase.circles.any((c) => (c - baseMarker).distance < 1e-6),
        isTrue,
      );
      expect(
        inFace.circles.any((c) => (c - baseMarker).distance < 1e-6),
        isFalse,
      );
      expect(painter('face').shouldRepaint(painter(null)), isTrue);
    });

    test('the hit test finds them where they are drawn, and no adapter', () {
      final camera = _camera();
      const tester = SpaceHitTester();
      final onF = camera.spaceToScreen(s.f.spacePosition!);
      final hits = tester.hitTestAll(s.c.objects, camera, _size, onF, 12);
      expect(hits.first, s.f);
      expect(hits, contains(s.line));
      expect(hits.last, s.face);
      // On the apex: the apex, never its adapter, even hidden ones shown.
      final onApex = camera.spaceToScreen(s.apex.spacePosition!);
      final atApex = tester.hitTestAll(
        s.c.objects,
        camera,
        _size,
        onApex,
        12,
        includeHidden: true,
      );
      expect(atApex.first, s.apex);
      expect(atApex.any((o) => o.isInternal), isFalse);
    });

    test('the planar tester, the declutter and the base bounds leave them '
        'to their sheet', () {
      expect(
        const CanvasHitTester().hitTestAll(s.c.objects, const Vec2(100, 60), 5),
        isEmpty,
        reason: 'F\'s coordinates are the face\'s, not the base plane\'s',
      );
      final bounds = visibleWorldBounds(s.c.objects)!;
      expect(bounds.max, const Vec2(200, 0));
      final inFace = visibleWorldBounds(s.c.objects, sheet: Sheet.of(s.face))!;
      expect(inFace.min, const Vec2(40, 20));
      expect(inFace.max, const Vec2(140, 100));
      expect(liftedPositions(s.c.objects), [
        s.apex.spacePosition,
        s.f.spacePosition,
        s.g.spacePosition,
      ]);
      final scene = buildDeclutterScene(s.c, _camera(), _size);
      expect(scene.rects.map((r) => r.ownerId), isNot(contains('co')));
      expect(scene.rects.map((r) => r.ownerId), contains('f'));
    });

    test('fit keeps a plane\'s points on the canvas', () {
      final state = fittedViewport(
        s.c.objects,
        _size,
        rotation: 0.3,
        tilt: 1.0,
      )!;
      final camera = CanvasViewport(state);
      final inner = (Offset.zero & _size).deflate(fitMarginPx - 0.5);
      for (final point in [s.a, s.b, s.apex, s.f, s.g]) {
        expect(
          inner.contains(camera.spaceToScreen(point.spacePosition!)),
          isTrue,
        );
      }
    });
  });
}

class _Recorder implements Canvas {
  final List<Offset> circles = [];
  final List<double> strokes = [];

  @override
  void drawCircle(Offset centre, double radius, Paint paint) {
    if (paint.style == PaintingStyle.fill || radius < 10) {
      circles.add(centre);
    }
  }

  @override
  void drawPath(Path path, Paint paint) {
    if (paint.style == PaintingStyle.stroke) {
      strokes.add(paint.strokeWidth);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
