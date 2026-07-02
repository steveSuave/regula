import 'dart:ui';

import '../../application/providers/viewport_provider.dart';
import '../../domain/math/vec2.dart';

/// World↔screen transforms for the canvas, built from a [ViewportState]
/// (never duplicating its data — see the Phase 4 STATUS note).
///
/// Named `CanvasViewport` because Flutter already ships a `Viewport`
/// widget and the two would collide in every file importing
/// `flutter/widgets.dart`.
///
/// Conventions:
/// - World coordinates are y-up (the geometry convention); screen
///   coordinates are y-down (the Flutter convention). This class is the
///   only place the flip happens — painter and hit tester stay flip-free.
/// - `state.pan` is the world-space point at the canvas origin (top-left);
///   `state.scale` is screen pixels per world unit.
class CanvasViewport {
  const CanvasViewport(this.state);

  final ViewportState state;

  Offset worldToScreen(Vec2 world) => Offset(
        (world.x - state.pan.x) * state.scale,
        (state.pan.y - world.y) * state.scale,
      );

  Vec2 screenToWorld(Offset screen) => Vec2(
        state.pan.x + screen.dx / state.scale,
        state.pan.y - screen.dy / state.scale,
      );

  /// Screen pixels covered by [worldLength] world units.
  double worldToScreenLength(double worldLength) =>
      worldLength * state.scale;

  /// World units covered by [screenLength] screen pixels — e.g. the 8 px
  /// hit-test threshold expressed in world units.
  double screenToWorldLength(double screenLength) =>
      screenLength / state.scale;
}
