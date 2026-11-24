import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:regula/application/providers/viewport_provider.dart';
import 'package:regula/domain/construction/construction.dart';
import 'package:regula/domain/construction/objects/fixed_radius_circle.dart';
import 'package:regula/domain/construction/objects/free_point.dart';
import 'package:regula/domain/construction/objects/midpoint.dart';
import 'package:regula/domain/math/vec2.dart';
import 'package:regula/domain/math/vec3.dart';
import 'package:regula/presentation/canvas/canvas_viewport.dart';
import 'package:regula/presentation/canvas/geometry_painter.dart';
import 'package:regula/presentation/canvas/lift_handle.dart';
import 'package:regula/presentation/canvas/lifted_point_hint.dart';
import 'package:regula/presentation/canvas/space_view.dart';

CanvasViewport _camera(double tilt, {double scale = 1}) => CanvasViewport(
  ViewportState(pan: const Vec2(-400, 300), tilt: tilt, scale: scale),
);

void main() {
  group('LiftHandle', () {
    test('points up the screen, a grip distance from the point', () {
      final p = FreePoint(id: 'p', position: const Vec2(10, 20));
      final viewport = _camera(math.pi / 3, scale: 2);
      final handle = LiftHandle.of(p, viewport)!;
      expect(handle.point, viewport.worldToScreen(const Vec2(10, 20)));
      expect(handle.axis.dx, closeTo(0, 1e-12));
      expect(handle.axis.dy, closeTo(-1, 1e-12));
      expect(handle.pixelsPerUnit, closeTo(2 * math.sin(math.pi / 3), 1e-12));
      expect(
        (handle.grip - handle.point).distance,
        closeTo(LiftHandle.gripDistance, 1e-9),
      );
      expect(handle.grabs(handle.grip + const Offset(23, 0)), isTrue);
      expect(handle.grabs(handle.grip + const Offset(25, 0)), isFalse);
    });

    test('rides a lifted point, not its foot', () {
      final p = FreePoint(id: 'p', position: const Vec2(10, 20), height: 30);
      final viewport = _camera(1.0);
      expect(
        LiftHandle.of(p, viewport)!.point,
        viewport.spaceToScreen(const Vec3(10, 20, 30)),
      );
      expect(
        LiftHandle.footOf(p, viewport),
        viewport.worldToScreen(const Vec2(10, 20)),
      );
      expect(
        LiftHandle.footOf(FreePoint(id: 'q', position: Vec2.zero), viewport),
        isNull,
      );
    });

    test('is absent while the plane is seen nearly face-on', () {
      final p = FreePoint(id: 'p', position: Vec2.zero);
      expect(LiftHandle.of(p, _camera(0)), isNull);
      expect(LiftHandle.of(p, _camera(0.19)), isNull);
      expect(LiftHandle.of(p, _camera(0.21)), isNotNull);
      expect(LiftHandle.of(p, _camera(math.pi / 2)), isNotNull);
      expect(LiftHandle.of(p, _camera(math.pi - 0.1)), isNull);
    });

    test('turns travel along the axis into height, and snaps to the plane', () {
      final p = FreePoint(id: 'p', position: Vec2.zero);
      final handle = LiftHandle.of(p, _camera(math.pi / 6, scale: 4))!;
      // 4 px/unit × sin 30° = 2 px per unit of height.
      const start = Offset(100, 100);
      double at(Offset pointer, [double from = 0]) =>
          handle.heightAt(pointer, start: start, startHeight: from);
      expect(at(const Offset(100, 60)), closeTo(20, 1e-9));
      expect(at(const Offset(170, 60)), closeTo(20, 1e-9));
      expect(at(const Offset(100, 140)), closeTo(-20, 1e-9));
      expect(at(const Offset(100, 92)), 0);
      expect(at(const Offset(100, 108)), 0);
      expect(at(const Offset(100, 91)), closeTo(4.5, 1e-9));
      // From a height: back down into the snap.
      expect(at(const Offset(100, 136), 20), 0);
      expect(at(const Offset(100, 120), 20), closeTo(10, 1e-9));
    });

    test('is offered for exactly one selected, visible free point', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      final m = Midpoint(id: 'm', point1: a, point2: b);
      c
        ..add(a)
        ..add(b)
        ..add(m);
      final viewport = _camera(1.0);
      expect(LiftHandle.forSelection(c, {'a'}, viewport)!.pointId, 'a');
      expect(LiftHandle.forSelection(c, const {}, viewport), isNull);
      expect(LiftHandle.forSelection(c, {'a', 'b'}, viewport), isNull);
      expect(LiftHandle.forSelection(c, {'m'}, viewport), isNull);
      expect(LiftHandle.forSelection(c, {'gone'}, viewport), isNull);
      a.attributes = a.attributes.copyWith(visible: false);
      expect(LiftHandle.forSelection(c, {'a'}, viewport), isNull);
    });
  });

  group('the painter', () {
    GeometryPainter painter(
      Construction c, {
      required bool handle,
      Set<String> selected = const {'o'},
    }) => GeometryPainter(
      construction: c,
      viewport: _camera(1.0),
      revision: 0,
      defaultColor: const Color(0xFF000000),
      selectionColor: const Color(0xFF0000FF),
      selectedIds: selected,
      liftHandleEnabled: handle,
    );

    Construction scene({double height = 50}) => Construction()
      ..add(FreePoint(id: 'o', position: const Vec2(10, 20), height: height));

    test('draws the grip when the handle is offered, and not otherwise', () {
      final viewport = _camera(1.0);
      final at = viewport.spaceToScreen(const Vec3(10, 20, 50));
      final grip = at + const Offset(0, -LiftHandle.gripDistance);

      final on = _Recorder();
      painter(scene(), handle: true).paint(on, const Size(800, 600));
      expect(
        on.circles.where(
          (c) => (c.$1 - grip).distance < 1e-9 && c.$2 == LiftHandle.gripRadius,
        ),
        hasLength(1),
      );

      final off = _Recorder();
      painter(scene(), handle: false).paint(off, const Size(800, 600));
      expect(off.circles.where((c) => c.$2 == LiftHandle.gripRadius), isEmpty);
    });

    test('marks the foot of a lifted, selected point either way', () {
      final viewport = _camera(1.0);
      final foot = viewport.worldToScreen(const Vec2(10, 20));
      for (final handle in [true, false]) {
        final canvas = _Recorder();
        painter(scene(), handle: handle).paint(canvas, const Size(800, 600));
        expect(
          canvas.circles.where((c) => (c.$1 - foot).distance < 1e-9),
          hasLength(1),
          reason: 'handle $handle',
        );
        // The drop line is dashed, so it is a path.
        expect(canvas.paths, isNotEmpty);
      }
      final unselected = _Recorder();
      painter(
        scene(),
        handle: true,
        selected: const {},
      ).paint(unselected, const Size(800, 600));
      expect(
        unselected.circles.where((c) => (c.$1 - foot).distance < 1e-9),
        isEmpty,
      );
    });

    test('a point in its plane has no drop line', () {
      final canvas = _Recorder();
      painter(
        scene(height: 0),
        handle: false,
      ).paint(canvas, const Size(800, 600));
      expect(canvas.paths, isEmpty);
      expect(canvas.circles, hasLength(2), reason: 'the halo and the dot');
    });

    test('the handle flag repaints', () {
      final c = scene();
      expect(
        painter(c, handle: true).shouldRepaint(painter(c, handle: false)),
        isTrue,
      );
    });
  });

  group('what a lift leaves waiting', () {
    test('counts the undefined dependents of a lifted point', () {
      final c = Construction();
      final a = FreePoint(id: 'a', position: Vec2.zero);
      final b = FreePoint(id: 'b', position: const Vec2(4, 0));
      c
        ..add(a)
        ..add(b)
        ..add(FixedRadiusCircle(id: 'k', center: a, radius: 2))
        ..add(Midpoint(id: 'm', point1: a, point2: b));
      expect(constructionsWaitingOn(c, 'a'), 0);
      expect(hasSpaceContent(c.objects), isFalse);

      c.setFreePointHeight('a', 1);
      // The circle waits; the midpoint follows the point into space.
      expect(constructionsWaitingOn(c, 'a'), 1);
      expect(constructionsWaitingOn(c, 'b'), 0);
      expect(constructionsWaitingOn(c, 'm'), 0);
      expect(constructionsWaitingOn(c, 'gone'), 0);
      expect(hasSpaceContent(c.objects), isTrue);

      // Hidden content is still content.
      a.attributes = a.attributes.copyWith(visible: false);
      expect(hasSpaceContent(c.objects), isTrue);
    });
  });
}

class _Recorder implements Canvas {
  final List<(Offset, double)> circles = [];
  final List<Path> paths = [];

  @override
  void drawCircle(Offset centre, double radius, Paint paint) =>
      circles.add((centre, radius));

  @override
  void drawPath(Path path, Paint paint) => paths.add(path);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
