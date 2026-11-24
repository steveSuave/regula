import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';

void main() {
  group('CanvasViewport', () {
    test('identity state maps world origin to screen origin, y flipped', () {
      const viewport = CanvasViewport(ViewportState());

      expect(viewport.worldToScreen(Vec2.zero), Offset.zero);
      expect(
        viewport.worldToScreen(const Vec2(3, 2)),
        const Offset(3, -2),
        reason:
            'world y-up: positive world y is above the origin, i.e. '
            'negative screen y',
      );
    });

    test('pan places its world point at the canvas origin', () {
      const viewport = CanvasViewport(ViewportState(pan: Vec2(10, 20)));

      expect(viewport.worldToScreen(const Vec2(10, 20)), Offset.zero);
      expect(viewport.worldToScreen(const Vec2(11, 19)), const Offset(1, 1));
    });

    test('scale multiplies screen distances', () {
      const viewport = CanvasViewport(ViewportState(scale: 2));

      expect(viewport.worldToScreen(const Vec2(1, -1)), const Offset(2, 2));
      expect(viewport.worldToScreenLength(3), 6);
      expect(viewport.screenToWorldLength(8), 4);
    });

    test('zoomedAbout scales while pinning the focal world point', () {
      const viewport = CanvasViewport(
        ViewportState(pan: Vec2(-4, 7.5), scale: 2.5),
      );
      const focal = Offset(320, 240);
      final fixedWorld = viewport.screenToWorld(focal);

      for (final factor in [2.0, 0.5, 1.25, 0.9]) {
        final zoomed = CanvasViewport(viewport.zoomedAbout(focal, factor));
        expect(zoomed.state.scale, closeTo(2.5 * factor, 1e-12));
        final focalAfter = zoomed.worldToScreen(fixedWorld);
        expect(
          focalAfter.dx,
          closeTo(focal.dx, 1e-9),
          reason: 'factor $factor moved the focal point',
        );
        expect(
          focalAfter.dy,
          closeTo(focal.dy, 1e-9),
          reason: 'factor $factor moved the focal point',
        );
      }
    });

    test('zoomedAbout in then out restores the original state', () {
      const viewport = CanvasViewport(
        ViewportState(pan: Vec2(3, -2), scale: 1.5),
      );
      const focal = Offset(100, 50);

      final there = CanvasViewport(viewport.zoomedAbout(focal, 2));
      final back = there.zoomedAbout(focal, 0.5);
      expect(back.scale, closeTo(1.5, 1e-12));
      expect(
        back.pan.closeTo(viewport.state.pan),
        isTrue,
        reason: 'round trip drifted the pan: ${back.pan}',
      );
    });

    test('zoomedAbout clamps the scale and no-ops at the bounds', () {
      const viewport = CanvasViewport(ViewportState(scale: 1));
      const focal = Offset(50, 50);

      final floored = viewport.zoomedAbout(focal, 1e-9);
      expect(floored.scale, CanvasViewport.minScale);
      final ceiled = viewport.zoomedAbout(focal, 1e9);
      expect(ceiled.scale, CanvasViewport.maxScale);

      // Already at a bound: further zoom out must not creep the pan.
      final atFloor = CanvasViewport(floored);
      expect(
        atFloor.zoomedAbout(focal, 0.5),
        floored,
        reason: 'clamped zoom must return the state unchanged',
      );
    });

    test('pannedByScreen shifts content with the pointer, scale untouched', () {
      const viewport = CanvasViewport(
        ViewportState(pan: Vec2(10, -5), scale: 2),
      );
      const world = Vec2(12, -8);
      final before = viewport.worldToScreen(world);

      final panned = CanvasViewport(
        viewport.pannedByScreen(const Offset(30, -14)),
      );
      expect(panned.state.scale, 2);
      final after = panned.worldToScreen(world);
      expect(
        after - before,
        const Offset(30, -14),
        reason: 'every world point moves by exactly the screen delta',
      );
    });

    test('screenToWorld inverts worldToScreen', () {
      const viewport = CanvasViewport(
        ViewportState(pan: Vec2(-4, 7.5), scale: 2.5),
      );
      const points = [Vec2.zero, Vec2(1, 1), Vec2(-3.25, 12), Vec2(100, -0.5)];

      for (final world in points) {
        final roundTrip = viewport.screenToWorld(viewport.worldToScreen(world));
        expect(
          roundTrip.closeTo(world),
          isTrue,
          reason: '$world did not survive the round trip: $roundTrip',
        );
      }
    });
  });

  group('CanvasViewport rotation', () {
    test('positive rotation turns content counterclockwise on screen', () {
      // A quarter turn about the canvas origin (pan = world origin):
      // "right of origin" must land "above origin" — screen y negative.
      final viewport = CanvasViewport(ViewportState(rotation: math.pi / 2));

      final right = viewport.worldToScreen(const Vec2(1, 0));
      expect(right.dx, closeTo(0, 1e-12));
      expect(right.dy, closeTo(-1, 1e-12));

      final up = viewport.worldToScreen(const Vec2(0, 1));
      expect(up.dx, closeTo(-1, 1e-12));
      expect(up.dy, closeTo(0, 1e-12));
    });

    test('pan stays the world point at the canvas origin at any angle', () {
      for (final rotation in [0.3, -1.2, math.pi, 5.0]) {
        final viewport = CanvasViewport(
          ViewportState(pan: const Vec2(10, 20), scale: 2, rotation: rotation),
        );
        final origin = viewport.worldToScreen(const Vec2(10, 20));
        expect(
          origin.dx,
          closeTo(0, 1e-12),
          reason: 'rotation $rotation moved the origin',
        );
        expect(
          origin.dy,
          closeTo(0, 1e-12),
          reason: 'rotation $rotation moved the origin',
        );
      }
    });

    test('screenToWorld inverts worldToScreen at non-zero rotation', () {
      const points = [Vec2.zero, Vec2(1, 1), Vec2(-3.25, 12), Vec2(100, -0.5)];
      for (final rotation in [0.1, -0.7, math.pi / 3, 2.9, -math.pi]) {
        final viewport = CanvasViewport(
          ViewportState(
            pan: const Vec2(-4, 7.5),
            scale: 2.5,
            rotation: rotation,
          ),
        );
        for (final world in points) {
          final roundTrip = viewport.screenToWorld(
            viewport.worldToScreen(world),
          );
          expect(
            roundTrip.closeTo(world),
            isTrue,
            reason:
                '$world at rotation $rotation did not survive the '
                'round trip: $roundTrip',
          );
        }
      }
    });

    test('rotation preserves screen distances, so length helpers hold', () {
      final viewport = CanvasViewport(
        const ViewportState(pan: Vec2(3, -2), scale: 2.5, rotation: 0.8),
      );
      const a = Vec2(1, 4);
      const b = Vec2(-2, 0);

      final screenDistance =
          (viewport.worldToScreen(a) - viewport.worldToScreen(b)).distance;
      expect(
        screenDistance,
        closeTo(viewport.worldToScreenLength((a - b).norm), 1e-9),
        reason: 'a rotated view must not change on-screen lengths',
      );
    });

    test('pinning honours rotation and still pins the world point', () {
      const world = Vec2(6, -3);
      const focal = Offset(200, 150);
      for (final rotation in [0.0, 0.4, -2.1, math.pi / 2]) {
        final state = CanvasViewport.pinning(
          world: world,
          focal: focal,
          scale: 2,
          rotation: rotation,
        );
        expect(state.rotation, rotation);
        final pinned = CanvasViewport(state).screenToWorld(focal);
        expect(
          pinned.closeTo(world),
          isTrue,
          reason:
              'rotation $rotation: focal resolves to $pinned, '
              'not $world',
        );
      }
    });

    test('zoomedAbout preserves rotation and the focal pin', () {
      final viewport = CanvasViewport(
        const ViewportState(pan: Vec2(-4, 7.5), scale: 2.5, rotation: 1.1),
      );
      const focal = Offset(320, 240);
      final fixedWorld = viewport.screenToWorld(focal);

      final zoomed = CanvasViewport(viewport.zoomedAbout(focal, 1.5));
      expect(zoomed.state.rotation, 1.1);
      expect(zoomed.state.scale, closeTo(3.75, 1e-12));
      final focalAfter = zoomed.worldToScreen(fixedWorld);
      expect(focalAfter.dx, closeTo(focal.dx, 1e-9));
      expect(focalAfter.dy, closeTo(focal.dy, 1e-9));
    });

    test('worldToScreenAngle matches where worldToScreen puts rim points', () {
      final viewport = CanvasViewport(
        const ViewportState(pan: Vec2(2, 1), scale: 3, rotation: 0.9),
      );
      const center = Vec2(5, -1);
      const radius = 2.0;
      final centerScreen = viewport.worldToScreen(center);
      for (final worldAngle in [0.0, 1.0, -2.4, math.pi]) {
        final rim = viewport.worldToScreen(
          center + Vec2(math.cos(worldAngle), math.sin(worldAngle)) * radius,
        );
        final screenAngle = viewport.worldToScreenAngle(worldAngle);
        final expected =
            centerScreen +
            Offset(math.cos(screenAngle), math.sin(screenAngle)) *
                viewport.worldToScreenLength(radius);
        expect(
          (rim - expected).distance,
          lessThan(1e-9),
          reason:
              'world angle $worldAngle: rim point and screen angle '
              'disagree',
        );
      }
    });

    test('worldToScreenDirection rotates and flips, preserving length', () {
      final viewport = CanvasViewport(
        const ViewportState(scale: 4, rotation: math.pi / 2),
      );
      // At a quarter turn CCW, world +x shows as screen up, world +y as
      // screen left; scale never applies to directions.
      final xImage = viewport.worldToScreenDirection(const Vec2(1, 0));
      expect(xImage.dx, closeTo(0, 1e-12));
      expect(xImage.dy, closeTo(-1, 1e-12));
      final yImage = viewport.worldToScreenDirection(const Vec2(0, 1));
      expect(yImage.dx, closeTo(-1, 1e-12));
      expect(yImage.dy, closeTo(0, 1e-12));
    });

    test('pannedByScreen shifts content by the delta at non-zero rotation', () {
      final viewport = CanvasViewport(
        const ViewportState(pan: Vec2(10, -5), scale: 2, rotation: -0.6),
      );
      const world = Vec2(12, -8);
      final before = viewport.worldToScreen(world);

      final panned = CanvasViewport(
        viewport.pannedByScreen(const Offset(30, -14)),
      );
      expect(panned.state.scale, 2);
      expect(panned.state.rotation, -0.6);
      final after = panned.worldToScreen(world);
      expect(
        after.dx - before.dx,
        closeTo(30, 1e-9),
        reason: 'content must follow the screen delta at any angle',
      );
      expect(
        after.dy - before.dy,
        closeTo(-14, 1e-9),
        reason: 'content must follow the screen delta at any angle',
      );
    });
  });

  group('visibleWorldBox', () {
    const size = Size(800, 600);

    test('unrotated, it is exactly the canvas in world units', () {
      const viewport = CanvasViewport(ViewportState(pan: Vec2(-400, 300)));
      final box = viewport.visibleWorldBox(size);
      expect(box.min.x, closeTo(-400, 1e-9));
      expect(box.max.x, closeTo(400, 1e-9));
      expect(box.min.y, closeTo(-300, 1e-9));
      expect(box.max.y, closeTo(300, 1e-9));
    });

    test('scale shrinks the world it covers', () {
      const viewport = CanvasViewport(
        ViewportState(pan: Vec2(-40, 30), scale: 10),
      );
      final box = viewport.visibleWorldBox(size);
      expect(box.max.x - box.min.x, closeTo(80, 1e-9));
      expect(box.max.y - box.min.y, closeTo(60, 1e-9));
    });

    test('the margin grows it by that many screen pixels', () {
      const viewport = CanvasViewport(ViewportState(scale: 2));
      final plain = viewport.visibleWorldBox(size);
      final grown = viewport.visibleWorldBox(size, margin: 8);
      expect(grown.min.x, closeTo(plain.min.x - 4, 1e-9));
      expect(grown.max.x, closeTo(plain.max.x + 4, 1e-9));
      expect(grown.min.y, closeTo(plain.min.y - 4, 1e-9));
      expect(grown.max.y, closeTo(plain.max.y + 4, 1e-9));
    });

    test('under rotation it encloses every visible point', () {
      const viewport = CanvasViewport(
        ViewportState(pan: Vec2(-400, 300), rotation: 0.7),
      );
      final box = viewport.visibleWorldBox(size);
      // A rotated view is not axis-aligned, so the box is a superset —
      // which is what a clip bound for an unbounded curve needs to be.
      for (var i = 0; i <= 20; i++) {
        for (var j = 0; j <= 20; j++) {
          final world = viewport.screenToWorld(
            Offset(size.width * i / 20, size.height * j / 20),
          );
          expect(world.x, inInclusiveRange(box.min.x, box.max.x));
          expect(world.y, inInclusiveRange(box.min.y, box.max.y));
        }
      }
      expect(
        (box.max.x - box.min.x) * (box.max.y - box.min.y),
        greaterThan(size.width * size.height),
        reason: 'strictly a superset at a nonzero angle',
      );
    });
  });

  // Intent 004, milestone 1: the space view's camera.
  group('the planar view is untouched by the camera', () {
    // Today's formulas, copied here so that the comparison is against
    // what the planar app computed and not against the code under test.
    Offset planarWorldToScreen(ViewportState state, Vec2 world) {
      final dx = world.x - state.pan.x;
      final dy = world.y - state.pan.y;
      final c = math.cos(state.rotation);
      final s = math.sin(state.rotation);
      return Offset(
        (dx * c - dy * s) * state.scale,
        -(dx * s + dy * c) * state.scale,
      );
    }

    Vec2 planarScreenToWorld(ViewportState state, Offset screen) {
      final rx = screen.dx / state.scale;
      final ry = -screen.dy / state.scale;
      final c = math.cos(state.rotation);
      final s = math.sin(state.rotation);
      return Vec2(state.pan.x + rx * c + ry * s, state.pan.y + ry * c - rx * s);
    }

    test('at tilt 0 every transform is the planar one, to the bit', () {
      final random = math.Random(4);
      double spread(double extent) => (random.nextDouble() * 2 - 1) * extent;
      for (var i = 0; i < 500; i++) {
        final state = ViewportState(
          pan: Vec2(spread(500), spread(500)),
          scale: 0.1 + random.nextDouble() * 80,
          rotation: i.isEven ? 0 : spread(math.pi),
        );
        final viewport = CanvasViewport(state);
        final world = Vec2(spread(300), spread(300));
        final screen = Offset(spread(900), spread(900));

        expect(viewport.isTilted, isFalse);
        expect(identical(viewport.flat, viewport), isTrue);
        expect(
          viewport.worldToScreen(world),
          planarWorldToScreen(state, world),
        );
        expect(
          viewport.screenToWorld(screen),
          planarScreenToWorld(state, screen),
        );
        expect(viewport.pickBasePlane(screen), viewport.screenToWorld(screen));
        expect(viewport.sheetToScreen(screen), screen);
        expect(
          viewport.pannedByScreen(screen),
          ViewportState(
            pan: planarScreenToWorld(state, -screen),
            scale: state.scale,
            rotation: state.rotation,
          ),
        );
        const size = Size(800, 600);
        expect(viewport.flatFrame(size), Offset.zero & size);
        final box = viewport.visibleWorldBox(size, margin: 8);
        final boxOfFrame = viewport.worldBoxOf(
          viewport.flatFrame(size, margin: 8),
        );
        expect(boxOfFrame.min, box.min);
        expect(boxOfFrame.max, box.max);
      }
    });

    test('a default state has no tilt and no height', () {
      const state = ViewportState();
      expect(state.tilt, 0);
      expect(state.panZ, 0);
      expect(state, const ViewportState(tilt: 0, panZ: 0));
      expect(state == const ViewportState(tilt: 0.1), isFalse);
      expect(state == const ViewportState(panZ: 1), isFalse);
    });
  });

  group('the tilted camera', () {
    const size = Size(800, 600);
    final random = math.Random(7);
    double spread(double extent) => (random.nextDouble() * 2 - 1) * extent;

    ViewportState randomState({required double tilt, double panZ = 0}) =>
        ViewportState(
          pan: Vec2(spread(200), spread(200)),
          scale: 0.5 + random.nextDouble() * 40,
          rotation: spread(math.pi),
          tilt: tilt,
          panZ: panZ,
        );

    void expectOffset(Offset actual, Offset expected, {double within = 1e-7}) {
      expect(actual.dx, closeTo(expected.dx, within));
      expect(actual.dy, closeTo(expected.dy, within));
    }

    test('the base plane is the planar picture through the sheet map', () {
      for (var i = 0; i < 200; i++) {
        final viewport = CanvasViewport(
          randomState(tilt: random.nextDouble() * math.pi, panZ: spread(50)),
        );
        final world = Vec2(spread(300), spread(300));
        final flatScreen = viewport.flat.worldToScreen(world);
        expectOffset(
          viewport.worldToScreen(world),
          viewport.sheetToScreen(flatScreen),
        );
        expectOffset(
          viewport.worldToScreen(world),
          viewport.spaceToScreen((x: world.x, y: world.y, z: 0)),
        );
        // x never moves; y is squashed by cos tilt.
        expect(viewport.worldToScreen(world).dx, flatScreen.dx);
        final matrix = viewport.sheetMatrix;
        expectOffset(
          Offset(flatScreen.dx, matrix[5] * flatScreen.dy + matrix[13]),
          viewport.worldToScreen(world),
        );
      }
    });

    test('a pick inverts the projection outside the edge-on band', () {
      for (var i = 0; i < 300; i++) {
        var tilt = random.nextDouble() * math.pi;
        if (math.cos(tilt).abs() < 0.1) {
          tilt = 0.4;
        }
        final viewport = CanvasViewport(randomState(tilt: tilt));
        expect(viewport.basePlanePickable, isTrue);
        final world = Vec2(spread(300), spread(300));
        final picked = viewport.pickBasePlane(viewport.worldToScreen(world))!;
        expect(picked.x, closeTo(world.x, 1e-6));
        expect(picked.y, closeTo(world.y, 1e-6));
      }
    });

    test('inside the edge-on band nothing is picked, and bounds stay '
        'finite', () {
      for (final tilt in [
        math.pi / 2,
        math.pi / 2 - 0.04,
        math.pi / 2 + 0.04,
        math.acos(0.049),
      ]) {
        final viewport = CanvasViewport(
          ViewportState(pan: const Vec2(3, -2), scale: 20, tilt: tilt),
        );
        expect(viewport.basePlanePickable, isFalse, reason: 'tilt $tilt');
        expect(viewport.pickBasePlane(const Offset(100, 100)), isNull);
        final frame = viewport.flatFrame(size, margin: 8);
        expect(frame.isFinite, isTrue);
        expect(
          frame.height,
          lessThanOrEqualTo((size.height + 16) / CanvasViewport.pickFloor + 1),
        );
        final box = viewport.visibleWorldBox(size, margin: 8);
        for (final value in [box.min.x, box.min.y, box.max.x, box.max.y]) {
          expect(value.isFinite, isTrue);
        }
      }
      // Just outside the band the plane is pickable again.
      expect(
        CanvasViewport(ViewportState(tilt: math.acos(0.051))).basePlanePickable,
        isTrue,
      );
    });

    test('the flat frame is exactly what the canvas can see of the '
        'plane', () {
      final viewport = CanvasViewport(
        const ViewportState(pan: Vec2(-10, 4), scale: 12, tilt: 1.0),
      );
      final frame = viewport.flatFrame(size);
      expectOffset(viewport.sheetToScreen(frame.topLeft), Offset.zero);
      expectOffset(
        viewport.sheetToScreen(frame.bottomRight),
        Offset(size.width, size.height),
      );
      // From below the pull-back flips, and the frame is still a
      // well-formed rectangle over the same canvas.
      final below = CanvasViewport(
        const ViewportState(pan: Vec2(-10, 4), scale: 12, tilt: 2.4),
      );
      final flipped = below.flatFrame(size);
      expect(flipped.top, lessThan(flipped.bottom));
      expectOffset(below.sheetToScreen(flipped.bottomLeft), Offset.zero);
    });

    test('an orbit keeps its pivot where it was on screen, edge-on '
        'included', () {
      for (var i = 0; i < 200; i++) {
        final from = CanvasViewport(
          randomState(tilt: i.isEven ? 0 : random.nextDouble() * math.pi),
        );
        final pivot = (
          x: spread(100),
          y: spread(100),
          z: i % 3 == 0 ? 0.0 : spread(40),
        );
        final before = from.spaceToScreen(pivot);
        for (final tilt in [
          0.0,
          0.7,
          math.pi / 2,
          math.pi / 2 + 0.01,
          2.5,
          math.pi,
        ]) {
          final rotation = spread(math.pi);
          final to = CanvasViewport(
            from.orbitedAbout(pivot, rotation: rotation, tilt: tilt),
          );
          expect(to.state.tilt, tilt);
          expect(to.state.rotation, rotation);
          expect(to.state.scale, from.state.scale);
          expectOffset(to.spaceToScreen(pivot), before, within: 1e-6);
        }
      }
    });

    test('an orbit clamps the tilt to straight down … straight up', () {
      const viewport = CanvasViewport(ViewportState(scale: 10, tilt: 0.3));
      const pivot = (x: 1.0, y: 2.0, z: 0.0);
      expect(viewport.orbitedAbout(pivot, rotation: 0, tilt: 4).tilt, math.pi);
      final level = viewport.orbitedAbout(pivot, rotation: 0, tilt: -0.2);
      expect(level.tilt, 0);
      expect(level.panZ, 0);
    });

    test('away from edge-on the pan stays on the base plane', () {
      for (var i = 0; i < 100; i++) {
        final viewport = CanvasViewport(randomState(tilt: 1.1));
        final panned = viewport.pannedByScreen(
          Offset(spread(300), spread(300)),
        );
        expect(panned.panZ, 0);
        final zoomed = viewport.zoomedAbout(const Offset(120, 340), 1.7);
        expect(zoomed.panZ, 0);
        // …so the pan is still the base-plane point at the canvas origin.
        expectOffset(
          CanvasViewport(panned).worldToScreen(panned.pan),
          Offset.zero,
        );
      }
    });

    test('a pan moves the picture by exactly its screen delta, edge-on '
        'included', () {
      for (final tilt in [0.6, math.pi / 2, math.pi / 2 - 0.02, 2.9]) {
        final viewport = CanvasViewport(randomState(tilt: tilt));
        final points = [
          (x: 0.0, y: 0.0, z: 0.0),
          (x: 7.0, y: -3.0, z: 0.0),
          (x: -2.0, y: 5.0, z: 4.0),
        ];
        const delta = Offset(31, -17);
        final panned = CanvasViewport(viewport.pannedByScreen(delta));
        expect(panned.state.tilt, tilt);
        for (final point in points) {
          expectOffset(
            panned.spaceToScreen(point),
            viewport.spaceToScreen(point) + delta,
            within: 1e-6,
          );
        }
      }
    });

    test('a zoom pins what is under the focal, edge-on included', () {
      for (final tilt in [0.6, math.pi / 2, 2.9]) {
        final viewport = CanvasViewport(randomState(tilt: tilt));
        const focal = Offset(260, 410);
        final under = viewport.spaceUnder(focal);
        expectOffset(viewport.spaceToScreen(under), focal, within: 1e-6);
        final zoomed = CanvasViewport(viewport.zoomedAbout(focal, 1.5));
        expect(zoomed.state.scale, closeTo(viewport.state.scale * 1.5, 1e-9));
        expect(zoomed.state.tilt, tilt);
        expectOffset(zoomed.spaceToScreen(under), focal, within: 1e-6);
      }
    });

    test('the visible world box encloses every pickable canvas point', () {
      final viewport = CanvasViewport(
        const ViewportState(
          pan: Vec2(-30, 20),
          scale: 8,
          rotation: 0.5,
          tilt: 1.2,
        ),
      );
      final box = viewport.visibleWorldBox(size);
      for (var i = 0; i <= 10; i++) {
        for (var j = 0; j <= 10; j++) {
          final world = viewport.pickBasePlane(
            Offset(size.width * i / 10, size.height * j / 10),
          )!;
          expect(world.x, inInclusiveRange(box.min.x - 1e-9, box.max.x + 1e-9));
          expect(world.y, inInclusiveRange(box.min.y - 1e-9, box.max.y + 1e-9));
        }
      }
    });
  });
}
