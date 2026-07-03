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

  /// Zoom bounds, in screen pixels per world unit. Wide enough that no
  /// reasonable construction hits them; tight enough that float precision
  /// in the transforms never becomes visible.
  static const double minScale = 0.05;
  static const double maxScale = 50;

  final ViewportState state;

  /// The state after multiplying scale by [factor] (> 1 zooms in) while
  /// keeping the world point under [focal] (screen coordinates) exactly
  /// there — the cursor pins the content. Scale is clamped to
  /// [minScale]..[maxScale]; at a bound the state returns unchanged.
  ViewportState zoomedAbout(Offset focal, double factor) {
    final newScale =
        (state.scale * factor).clamp(minScale, maxScale).toDouble();
    if (newScale == state.scale) {
      return state;
    }
    return pinning(world: screenToWorld(focal), focal: focal, scale: newScale);
  }

  /// The state with [scale] (clamped) whose pan puts the [world] point at
  /// the [focal] screen point — the shared solve behind scroll zoom and
  /// the pinch/pan gesture, where the anchor world point must track a
  /// moving focal.
  static ViewportState pinning({
    required Vec2 world,
    required Offset focal,
    required double scale,
  }) {
    final clamped = scale.clamp(minScale, maxScale).toDouble();
    // Solve screenToWorld(focal) == world for pan.
    return ViewportState(
      pan: Vec2(
        world.x - focal.dx / clamped,
        world.y + focal.dy / clamped,
      ),
      scale: clamped,
    );
  }

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
