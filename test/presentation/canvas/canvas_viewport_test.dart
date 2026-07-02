import 'dart:ui';

import 'package:fgex/application/providers/viewport_provider.dart';
import 'package:fgex/domain/math/vec2.dart';
import 'package:fgex/presentation/canvas/canvas_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

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
