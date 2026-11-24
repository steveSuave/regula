import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/geo_object.dart';
import 'package:regula/domain/construction/object_attributes.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/space_view.dart';

void main() {
  List<GeoObject> figure() => [
    FreePoint(id: 'a', position: const Vec2(2, 1)),
    FreePoint(id: 'b', position: const Vec2(10, 5)),
    FreePoint(
      id: 'hidden',
      position: const Vec2(100, 100),
      attributes: const ObjectAttributes(visible: false),
    ),
  ];

  const start = CanvasViewport(
    ViewportState(pan: Vec2(-20, 15), scale: 12, rotation: 0.3),
  );
  const pivot = Vec3(6.0, 3.0, 0.0);

  void expectSamePlace(CanvasViewport before, ViewportState after) {
    final was = before.spaceToScreen(pivot);
    final now = CanvasViewport(after).spaceToScreen(pivot);
    expect((now - was).distance, lessThan(1e-6));
  }

  test('the pivot is the centre of what Fit would frame, else the origin', () {
    expect(figurePivot(figure()), pivot);
    expect(figurePivot(const []), Vec3(0.0, 0.0, 0.0));
  });

  test('entering tilts to the oblique view and keeps the figure in place', () {
    final entered = enterSpaceView(start, figure());
    expect(entered.tilt, obliqueTilt);
    expect(entered.rotation, 0.3);
    expect(entered.scale, 12);
    expectSamePlace(start, entered);
  });

  test('leaving looks straight down again and keeps the figure in place', () {
    for (final tilt in [obliqueTilt, math.pi / 2, 2.8]) {
      final turned = CanvasViewport(
        start.orbitedAbout(pivot, rotation: -1.1, tilt: tilt),
      );
      final left = leaveSpaceView(turned, figure());
      expect(left.tilt, 0);
      expect(left.panZ, 0);
      expect(left.rotation, -1.1);
      expect(left.scale, 12);
      expectSamePlace(turned, left);
    }
  });

  test('entering and leaving at once is where the view started', () {
    final back = leaveSpaceView(
      CanvasViewport(enterSpaceView(start, figure())),
      figure(),
    );
    expect(back.pan.x, closeTo(start.state.pan.x, 1e-9));
    expect(back.pan.y, closeTo(start.state.pan.y, 1e-9));
    expect(back.scale, start.state.scale);
    expect(back.rotation, start.state.rotation);
  });

  test('each preset sets its two angles about the figure', () {
    const expected = {
      SpaceViewPreset.top: (0.0, 0.0),
      SpaceViewPreset.front: (0.0, math.pi / 2),
      SpaceViewPreset.side: (math.pi / 2, math.pi / 2),
      SpaceViewPreset.oblique: (-math.pi / 6, math.pi / 3),
    };
    final turned = CanvasViewport(enterSpaceView(start, figure()));
    for (final preset in SpaceViewPreset.values) {
      final state = presetSpaceView(turned, figure(), preset);
      expect((state.rotation, state.tilt), expected[preset]);
      expectSamePlace(turned, state);
    }
    // Top is the planar view: nothing of the camera is left in it.
    final top = presetSpaceView(turned, figure(), SpaceViewPreset.top);
    expect(CanvasViewport(top).isTilted, isFalse);
    expect(top.panZ, 0);
  });

  test('reset is the oblique view of the origin at the canvas centre', () {
    const size = Size(800, 600);
    final state = resetSpaceView(size);
    expect(state.scale, 1);
    expect(state.tilt, obliqueTilt);
    expect(state.rotation, -math.pi / 6);
    final origin = CanvasViewport(state).worldToScreen(Vec2.zero);
    expect((origin - const Offset(400, 300)).distance, lessThan(1e-9));
  });
}
