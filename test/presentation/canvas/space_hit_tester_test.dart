// Intent 004, milestone 2: objects as screen ink, and the hit test that
// measures against it.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/fixed_radius_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/line_through_two_points.dart';
import 'package:regula/domain/construction/objects/polygon.dart';
import 'package:regula/domain/construction/objects/segment.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/presentation/canvas/canvas_hit_tester.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/fit_viewport.dart';
import 'package:regula/presentation/canvas/label_obstacles.dart';
import 'package:regula/presentation/canvas/screen_figure.dart';
import 'package:regula/presentation/canvas/space_hit_tester.dart';
import 'package:regula/presentation/canvas/space_view.dart';

const _size = Size(800, 600);

CanvasViewport _camera({double tilt = 0, double rotation = 0}) =>
    CanvasViewport(
      ViewportState(pan: const Vec2(-400, 300), tilt: tilt, rotation: rotation),
    );

void main() {
  const tester = SpaceHitTester();
  const oblique = math.pi / 3;

  group('screen ink', () {
    test('a planar point is a dot at its screen position, at any tilt', () {
      final c = Construction();
      final p = FreePoint(id: 'p', position: const Vec2(30, 40));
      c.add(p);
      for (final tilt in [0.0, oblique, 2.5]) {
        final viewport = _camera(tilt: tilt);
        final ink = screenInkOf(c.objects, viewport, _size, p);
        expect(ink.dot, viewport.worldToScreen(const Vec2(30, 40)));
        expect(ink.segments, isEmpty);
      }
    });

    test('a circle under tilt is the polygon of its ellipse', () {
      final c = Construction();
      final o = FreePoint(id: 'o', position: Vec2.zero);
      final k = FixedRadiusCircle(id: 'k', center: o, radius: 100);
      c
        ..add(o)
        ..add(k);
      final viewport = _camera(tilt: oblique);
      final ink = screenInkOf(c.objects, viewport, _size, k);
      final xs = [for (final (a, _) in ink.segments) a.dx];
      final ys = [for (final (a, _) in ink.segments) a.dy];
      final centre = viewport.worldToScreen(Vec2.zero);
      expect(xs.reduce(math.max) - centre.dx, closeTo(100, 0.5));
      expect(ys.reduce(math.max) - centre.dy, closeTo(50, 0.5));
      expect(ink.distanceTo(centre + const Offset(100, 0)), lessThan(0.5));
      expect(ink.distanceTo(centre + const Offset(0, 50)), lessThan(0.5));
      expect(ink.distanceTo(centre), closeTo(50, 1));
    });

    test('a lifted point and a segment to it are drawn from space', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(60, 0), height: 80);
      final s = Segment(id: 's', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(s);
      final viewport = _camera(tilt: oblique, rotation: 0.4);
      expect(drawnInSpace(a), isFalse);
      expect(drawnInSpace(b), isTrue);
      expect(drawnInSpace(s), isTrue);

      final apex = viewport.spaceToScreen(const Vec3(60, 0, 80));
      expect(screenInkOf(c.objects, viewport, _size, b).dot, apex);
      final ink = screenInkOf(c.objects, viewport, _size, s);
      expect(ink.segments.single, (viewport.spaceToScreen(Vec3.zero), apex));
      expect(spaceLabelAnchor(s), const Vec3(30, 0, 40));
    });

    test('a space line runs right across the canvas', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(60, 0), height: 80);
      final l = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(l);
      final viewport = _camera(tilt: oblique);
      final (from, to) = screenInkOf(
        c.objects,
        viewport,
        _size,
        l,
      ).segments.single;
      expect((to - from).distance, greaterThan(2 * (800 + 600)));
      final ink = screenInkOf(c.objects, viewport, _size, l);
      expect(
        ink.distanceTo(viewport.spaceToScreen(const Vec3(120, 0, 160))),
        lessThan(1e-6),
      );
    });

    test('the declutter scene sees a lifted point where it is drawn', () {
      final c = Construction();
      final b = FreePoint(id: 'b', position: const Vec2(60, 0), height: 80);
      c.add(b);
      final viewport = _camera(tilt: oblique);
      final scene = buildDeclutterScene(c, viewport, _size);
      expect(
        scene.rects.single.rect.center,
        viewport.spaceToScreen(const Vec3(60, 0, 80)),
      );
    });
  });

  group('SpaceHitTester', () {
    test('measures in pixels along both screen axes under tilt', () {
      final c = Construction();
      final p = FreePoint(id: 'p', position: const Vec2(100, 100));
      c.add(p);
      final viewport = _camera(tilt: oblique);
      final at = viewport.worldToScreen(const Vec2(100, 100));
      for (final direction in const [Offset(1, 0), Offset(0, 1)]) {
        expect(
          tester.hitTest(c.objects, viewport, _size, at + direction * 11, 12),
          p,
        );
        expect(
          tester.hitTest(c.objects, viewport, _size, at + direction * 13, 12),
          isNull,
        );
      }
    });

    test('tells apart two points the foreshortening brings together', () {
      final c = Construction();
      final near = FreePoint(id: 'near', position: const Vec2(0, 0));
      final far = FreePoint(id: 'far', position: const Vec2(0, 36));
      c
        ..add(near)
        ..add(far);
      final viewport = _camera(tilt: oblique);
      // 36 world units apart, 18 px apart on screen.
      final atFar = viewport.worldToScreen(const Vec2(0, 36));
      final hits = tester.hitTestAll(
        c.objects,
        viewport,
        _size,
        atFar + const Offset(0, -4),
        12,
      );
      expect(hits, [far]);
    });

    test('picks a lifted point where it is drawn, not at its foot', () {
      final c = Construction();
      final p = FreePoint(id: 'p', position: const Vec2(50, 50), height: 120);
      c.add(p);
      final viewport = _camera(tilt: oblique);
      final drawn = viewport.spaceToScreen(const Vec3(50, 50, 120));
      final foot = viewport.worldToScreen(const Vec2(50, 50));
      expect((drawn - foot).distance, greaterThan(50));
      expect(tester.hitTest(c.objects, viewport, _size, drawn, 12), p);
      expect(tester.hitTest(c.objects, viewport, _size, foot, 12), isNull);
    });

    test('of two segments crossing on screen, the nearer one wins', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: const Vec2(-50, 0));
      final b = FreePoint(id: 'b', position: const Vec2(50, 0));
      final low = Segment(id: 'low', point1: a, point2: b);
      final d = FreePoint(id: 'd', position: const Vec2(0, -50), height: 40);
      final e = FreePoint(id: 'e', position: const Vec2(0, 50), height: 40);
      final high = Segment(id: 'high', point1: d, point2: e);
      c
        ..add(a)
        ..add(b)
        ..add(low)
        ..add(d)
        ..add(e)
        ..add(high);
      // From straight above the two cross at the origin's image; the
      // pointer is a pixel nearer the lower one.
      final above = _camera();
      final crossing = above.worldToScreen(Vec2.zero);
      final pointer = crossing + const Offset(2, 1);
      expect(tester.hitTestAll(c.objects, above, _size, pointer, 12), [
        high,
        low,
      ]);
      // From straight below, the same pointer finds the other one first.
      final below = _camera(tilt: math.pi);
      final under = below.worldToScreen(Vec2.zero) + const Offset(2, 1);
      expect(tester.hitTestAll(c.objects, below, _size, under, 12), [
        low,
        high,
      ]);
    });

    test('keeps the planar order: point, then curve, then line, then '
        'polygon interior', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(100, 0));
      final d = FreePoint(id: 'd', position: const Vec2(0, 100));
      final line = LineThroughTwoPoints(id: 'l', point1: a, point2: b);
      final circle = FixedRadiusCircle(id: 'k', center: b, radius: 100);
      final polygon = Polygon(id: 'g', vertices: [a, b, d]);
      c
        ..add(a)
        ..add(b)
        ..add(d)
        ..add(line)
        ..add(circle)
        ..add(polygon);
      final viewport = _camera(tilt: oblique);
      final hits = tester.hitTestAll(
        c.objects,
        viewport,
        _size,
        viewport.worldToScreen(Vec2.zero) + const Offset(3, 0),
        12,
      );
      expect(hits, [a, circle, line, polygon]);
    });

    test('skips hidden objects unless asked', () {
      final c = Construction();
      final p = FreePoint(id: 'p', position: Vec2.zero);
      c.add(p);
      p.attributes = p.attributes.copyWith(visible: false);
      final viewport = _camera(tilt: oblique);
      final at = viewport.worldToScreen(Vec2.zero);
      expect(tester.hitTest(c.objects, viewport, _size, at, 12), isNull);
      expect(
        tester.hitTest(c.objects, viewport, _size, at, 12, includeHidden: true),
        p,
      );
    });
  });

  group('the planar tester and a lifted point', () {
    test('it is not hit on the plane and not banded', () {
      final c = Construction();
      final p = FreePoint(id: 'p', position: Vec2.zero, height: 5);
      final q = FreePoint(id: 'q', position: const Vec2(10, 0));
      final s = Segment(id: 's', point1: p, point2: q);
      c
        ..add(p)
        ..add(q)
        ..add(s);
      const planar = CanvasHitTester();
      expect(planar.hitTestAll(c.objects, Vec2.zero, 3), isEmpty);
      expect(planar.objectsContainedIn(c.objects, (_) => true), [q]);
    });
  });

  group('fit and pivot with a lifted point', () {
    final c = Construction();
    final points = [
      FreePoint(id: 'a', position: const Vec2(-100, -100)),
      FreePoint(id: 'b', position: const Vec2(100, 100)),
      FreePoint(id: 'o', position: Vec2.zero, height: 300),
    ];
    points.forEach(c.add);

    test('the pivot is the centre of the box in space', () {
      expect(figurePivot(c.objects), const Vec3(0, 0, 150));
      expect(liftedPositions(c.objects), [const Vec3(0, 0, 300)]);
    });

    test('fit keeps every point inside the canvas at an oblique camera', () {
      final state = fittedViewport(
        c.objects,
        _size,
        rotation: -math.pi / 6,
        tilt: oblique,
      )!;
      final viewport = CanvasViewport(state);
      final inner = (Offset.zero & _size).deflate(fitMarginPx - 0.5);
      for (final p in points) {
        expect(
          inner.contains(viewport.spaceToScreen(p.spacePosition!)),
          isTrue,
        );
      }
      // And it is a fit, not just a containment: what is framed — the
      // planar bounds' corners and the lifted point — reaches the margin
      // on one axis.
      final images = [
        for (final corner in const [
          Vec3(-100, -100, 0),
          Vec3(-100, 100, 0),
          Vec3(100, -100, 0),
          Vec3(100, 100, 0),
          Vec3(0, 0, 300),
        ])
          viewport.spaceToScreen(corner),
      ];
      double span(double Function(Offset) of) =>
          images.map(of).reduce(math.max) - images.map(of).reduce(math.min);
      final fill = math.max(
        span((i) => i.dx) / (_size.width - 2 * fitMarginPx),
        span((i) => i.dy) / (_size.height - 2 * fitMarginPx),
      );
      expect(fill, closeTo(1, 1e-9));
    });

    test('a planar figure is fitted exactly as before', () {
      final planar = Construction()
        ..add(FreePoint(id: 'a', position: const Vec2(-100, -100)))
        ..add(FreePoint(id: 'b', position: const Vec2(100, 100)));
      expect(liftedPositions(planar.objects), isEmpty);
      expect(figurePivot(planar.objects), Vec3.zero);
    });
  });
}
