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
        reason: 'world y-up: positive world y is above the origin, i.e. '
            'negative screen y',
      );
    });

    test('pan places its world point at the canvas origin', () {
      const viewport =
          CanvasViewport(ViewportState(pan: Vec2(10, 20)));

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
        expect(focalAfter.dx, closeTo(focal.dx, 1e-9),
            reason: 'factor $factor moved the focal point');
        expect(focalAfter.dy, closeTo(focal.dy, 1e-9),
            reason: 'factor $factor moved the focal point');
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
      expect(back.pan.closeTo(viewport.state.pan), isTrue,
          reason: 'round trip drifted the pan: ${back.pan}');
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
      expect(atFloor.zoomedAbout(focal, 0.5), floored,
          reason: 'clamped zoom must return the state unchanged');
    });

    test('pannedByScreen shifts content with the pointer, scale untouched',
        () {
      const viewport = CanvasViewport(
        ViewportState(pan: Vec2(10, -5), scale: 2),
      );
      const world = Vec2(12, -8);
      final before = viewport.worldToScreen(world);

      final panned =
          CanvasViewport(viewport.pannedByScreen(const Offset(30, -14)));
      expect(panned.state.scale, 2);
      final after = panned.worldToScreen(world);
      expect(after - before, const Offset(30, -14),
          reason: 'every world point moves by exactly the screen delta');
    });

    test('screenToWorld inverts worldToScreen', () {
      const viewport = CanvasViewport(
        ViewportState(pan: Vec2(-4, 7.5), scale: 2.5),
      );
      const points = [Vec2.zero, Vec2(1, 1), Vec2(-3.25, 12), Vec2(100, -0.5)];

      for (final world in points) {
        final roundTrip = viewport.screenToWorld(viewport.worldToScreen(world));
        expect(roundTrip.closeTo(world), isTrue,
            reason: '$world did not survive the round trip: $roundTrip');
      }
    });
  });
}
