// Intent 004, milestone 2, stage B: how a plane is drawn and picked.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/parallel_plane.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/construction/objects/three_point_plane.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/domain/projective/space/plane_frame.dart';
import 'package:regula/presentation/canvas/canvas_hit_tester.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/fit_viewport.dart';
import 'package:regula/presentation/canvas/geometry_painter.dart';
import 'package:regula/presentation/canvas/plane_patch.dart';
import 'package:regula/presentation/canvas/screen_figure.dart';
import 'package:regula/presentation/canvas/space_hit_tester.dart';
import 'package:regula/presentation/canvas/space_view.dart';

const _size = Size(800, 600);

CanvasViewport _camera({double tilt = math.pi / 3, double rotation = 0}) =>
    CanvasViewport(
      ViewportState(pan: const Vec2(-400, 300), tilt: tilt, rotation: rotation),
    );

FreePoint _p(String id, double x, double y, [double h = 0]) =>
    FreePoint(id: id, position: Vec2(x, y), height: h);

void main() {
  late Construction c;
  late ThreePointPlane base;

  setUp(() {
    c = Construction();
    final a = _p('a', 0, 0);
    final b = _p('b', 200, 0);
    final d = _p('d', 0, 100);
    base = ThreePointPlane(id: 'base', point1: a, point2: b, point3: d);
    c
      ..add(a)
      ..add(b)
      ..add(d)
      ..add(base);
  });

  group('planePatch', () {
    test('surrounds the points on the plane, padded by a fifth of the longer '
        'side', () {
      final corners = planePatch(base, c.objects, minHalfExtent: 1)!;
      expect(corners, const [
        Vec3(-40, -40, 0),
        Vec3(240, -40, 0),
        Vec3(240, 140, 0),
        Vec3(-40, 140, 0),
      ]);
    });

    test(
      'grows to hold a point built in the plane, and ignores one off it',
      () {
        c
          ..add(_p('in', 400, 50))
          ..add(_p('off', 900, 900, 5));
        final corners = planePatch(base, c.objects, minHalfExtent: 1)!;
        expect(corners[1].x, 400 + 0.2 * 400);
        expect(corners.every((corner) => corner.x < 500), isTrue);
      },
    );

    test('is never smaller than the minimum, and exists for a plane through '
        'a single point', () {
      final through = _p('t', 10, 10, 70);
      final lid = ParallelPlane(id: 'lid', through: through, reference: base);
      c
        ..add(through)
        ..add(lid);
      final corners = planePatch(lid, c.objects, minHalfExtent: 30)!;
      expect(corners[0], const Vec3(-20, -20, 70));
      expect(corners[2], const Vec3(40, 40, 70));
    });

    test('is null for an undefined plane', () {
      c.moveFreePoint('d', const Vec2(400, 0));
      expect(base.isDefined, isFalse);
      expect(planePatch(base, c.objects, minHalfExtent: 1), isNull);
    });
  });

  group('pickPlane', () {
    test('inverts the projection of a point of the plane', () {
      final frame = PlaneFrame.throughPoints(
        const Vec3(10, 20, 30),
        const Vec3(50, 20, 60),
        const Vec3(10, 90, 10),
      )!;
      final viewport = _camera(rotation: 0.4);
      for (final p in const [Vec2(0, 0), Vec2(35, -12), Vec2(-80, 140)]) {
        final picked = viewport.pickPlane(
          viewport.spaceToScreen(frame.lift(p)),
          frame,
        )!;
        expect(picked.distanceTo(p), lessThan(1e-9));
      }
    });

    test('on the base frame agrees with pickBasePlane, with a height too', () {
      final viewport = _camera(rotation: -0.7);
      const screen = Offset(321, 234);
      final a = viewport.pickPlane(screen, PlaneFrame.base)!;
      final b = viewport.pickBasePlane(screen)!;
      expect(a.distanceTo(b), lessThan(1e-9));
      final ah = viewport.pickPlane(screen, PlaneFrame.base, height: 40)!;
      final bh = viewport.pickBasePlane(screen, height: 40)!;
      expect(ah.distanceTo(bh), lessThan(1e-9));
    });

    test('refuses a plane seen edge-on', () {
      // A vertical plane facing sideways, seen from the front.
      final frame = PlaneFrame.horizontal(Vec3.zero, const Vec3(1, 0, 0))!;
      final front = _camera(tilt: math.pi / 2);
      expect(front.pickPlane(const Offset(100, 100), frame), isNull);
      // Turned a little, it can be picked.
      final turned = _camera(tilt: math.pi / 2, rotation: 0.3);
      expect(turned.pickPlane(const Offset(100, 100), frame), isNotNull);
    });
  });

  group('a plane on screen', () {
    test('its ink is the patch: four edges and a filled interior', () {
      final viewport = _camera();
      final ink = screenInkOf(c.objects, viewport, _size, base);
      expect(ink.segments, hasLength(4));
      expect(ink.fill, hasLength(4));
      final centre = viewport.spaceToScreen(const Vec3(100, 50, 0));
      expect(ink.distanceTo(centre), 0);
      expect(
        ink.distanceTo(viewport.spaceToScreen(const Vec3(600, 50, 0))),
        greaterThan(100),
      );
      expect(drawnInSpace(base), isTrue);
      expect(spaceLabelAnchor(base), base.labelAnchor);
    });

    test('is hit anywhere inside its patch, after everything else', () {
      final a = c.byId('a')! as FreePoint;
      final b = c.byId('b')! as FreePoint;
      final edge = Segment(id: 'ab', point1: a, point2: b);
      c.add(edge);
      final viewport = _camera();
      const tester = SpaceHitTester();
      final inside = viewport.spaceToScreen(const Vec3(100, 50, 0));
      expect(tester.hitTestAll(c.objects, viewport, _size, inside, 12), [base]);
      final onEdge = viewport.spaceToScreen(const Vec3(100, 0, 0));
      expect(tester.hitTestAll(c.objects, viewport, _size, onEdge, 12), [
        edge,
        base,
      ]);
      final onPoint = viewport.spaceToScreen(Vec3.zero);
      expect(
        tester.hitTestAll(c.objects, viewport, _size, onPoint, 12).first,
        a,
      );
    });

    test('of two planes under the pointer, the nearer one comes first', () {
      final through = _p('t', 0, 0, 60);
      final lid = ParallelPlane(id: 'lid', through: through, reference: base);
      c
        ..add(through)
        ..add(lid);
      const tester = SpaceHitTester();
      // Straight down, over both patches and clear of every point.
      final above = _camera(tilt: 0);
      final pointer = above.worldToScreen(const Vec2(20, 30));
      expect(tester.hitTestAll(c.objects, above, _size, pointer, 12), [
        lid,
        base,
      ]);
      final below = _camera(tilt: math.pi);
      final under = below.worldToScreen(const Vec2(20, 30));
      expect(tester.hitTestAll(c.objects, below, _size, under, 12), [
        base,
        lid,
      ]);
    });

    test('the planar tester, fit and the pivot do not see it', () {
      expect(
        const CanvasHitTester().hitTestAll(c.objects, const Vec2(100, 50), 5),
        isEmpty,
      );
      final without = Construction()
        ..add(_p('a', 0, 0))
        ..add(_p('b', 200, 0))
        ..add(_p('d', 0, 100));
      expect(
        fittedViewport(c.objects, _size),
        fittedViewport(without.objects, _size),
      );
      expect(figurePivot(c.objects), figurePivot(without.objects));
      expect(hasSpaceContent(c.objects), isTrue);
      expect(hasSpaceContent(without.objects), isFalse);
    });
  });

  group('the painter', () {
    GeometryPainter painter(CanvasViewport viewport) => GeometryPainter(
      construction: c,
      viewport: viewport,
      revision: 0,
      defaultColor: const Color(0xFF102030),
      selectionColor: const Color(0xFF0000FF),
    );

    test('fills the patch translucently before any stroke', () {
      final viewport = _camera();
      final canvas = _Recorder();
      painter(viewport).paint(canvas, _size);
      final (kind, path, paint) = canvas.calls.first;
      expect(kind, 'path');
      expect(paint.style, PaintingStyle.fill);
      expect(paint.color.a, closeTo(patchFillAlpha, 1e-6));
      final corner = viewport.spaceToScreen(const Vec3(-40, -40, 0));
      expect(path!.getBounds().bottomLeft.dx, closeTo(corner.dx, 1e-6));
      // Its outline is four lines, among the strokes.
      expect(canvas.calls.where((call) => call.$1 == 'line'), hasLength(4));
    });

    test('paints a farther plane first', () {
      final through = _p('t', 0, 0, 60);
      final lid = ParallelPlane(id: 'lid', through: through, reference: base);
      c
        ..add(through)
        ..add(lid);
      lid.attributes = lid.attributes.copyWith(fillAlpha: 0.5);
      List<double> alphas(CanvasViewport viewport) {
        final canvas = _Recorder();
        painter(viewport).paint(canvas, _size);
        return [
          for (final (kind, _, paint) in canvas.calls.take(2))
            if (kind == 'path') paint.color.a,
        ];
      }

      // From above the lid is nearer, so the base goes down first.
      expect(alphas(_camera())[0], closeTo(patchFillAlpha, 1e-6));
      expect(alphas(_camera())[1], closeTo(0.5, 1e-6));
      // From below the order turns over.
      expect(alphas(_camera(tilt: 2.4))[0], closeTo(0.5, 1e-6));
    });

    test('a hidden plane paints nothing', () {
      base.attributes = base.attributes.copyWith(visible: false);
      final canvas = _Recorder();
      painter(_camera()).paint(canvas, _size);
      expect(canvas.calls.where((call) => call.$1 == 'path'), isEmpty);
      expect(canvas.calls.where((call) => call.$1 == 'line'), isEmpty);
    });
  });
}

class _Recorder implements Canvas {
  final List<(String, Path?, Paint)> calls = [];

  @override
  void drawPath(Path path, Paint paint) => calls.add((
    'path',
    path,
    Paint()
      ..color = paint.color
      ..style = paint.style,
  ));

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      calls.add(('line', null, paint));

  @override
  void drawCircle(Offset centre, double radius, Paint paint) =>
      calls.add(('circle', null, paint));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
