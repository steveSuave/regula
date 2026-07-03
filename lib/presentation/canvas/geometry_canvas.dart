import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/construction_provider.dart';
import '../../application/providers/selection_provider.dart';
import '../../application/providers/tool_provider.dart';
import '../../application/providers/viewport_provider.dart';
import '../../domain/math/vec2.dart';
import '../../domain/tools/tool.dart';
import 'canvas_hit_tester.dart';
import 'canvas_viewport.dart';
import 'geometry_painter.dart';

/// The drawing surface: hosts the [GeometryPainter] and turns taps into
/// [ToolInput]s for the active tool — or, with no tool active
/// (move/select mode), into selection changes: tap selects the hit
/// object, shift-tap toggles it, tapping empty canvas clears, and a drag
/// from empty canvas rubber-bands everything wholly inside (shift adds
/// to the selection instead of replacing it).
///
/// Viewport navigation works with any tool: scroll wheel / trackpad
/// scroll zooms about the cursor, pinch zooms about the fingers'
/// focal point, and a two-finger or space-held drag pans. Once a
/// gesture navigates the viewport it stays navigation until every
/// pointer lifts, so lifting one pinch finger keeps panning instead of
/// suddenly rubber-banding.
class GeometryCanvas extends ConsumerStatefulWidget {
  const GeometryCanvas({super.key});

  /// Hit-test radius in logical pixels (PLAN: 8 px), converted to world
  /// units per tap so it feels the same at every zoom level.
  static const double hitThresholdPx = 8;

  /// Exponential zoom rate per scrolled pixel: factor = e^(−dy · rate),
  /// so one mouse-wheel notch (~100 px) zooms ~22 % and scrolling is
  /// exactly reversible (+dy then −dy lands back on the same scale).
  static const double scrollZoomPerPixel = 0.002;

  @override
  ConsumerState<GeometryCanvas> createState() => _GeometryCanvasState();
}

class _GeometryCanvasState extends ConsumerState<GeometryCanvas> {
  /// In-progress rubber band, in screen coordinates; null when no band
  /// is being dragged. Local widget state — nothing outside the canvas
  /// cares until the band commits to the selection on release.
  /// [_bandAnchor] is the drag's start corner: a `Rect` normalizes its
  /// corners away, so it can't serve as the fixed one on its own.
  Rect? _band;
  Offset? _bandAnchor;

  /// Baseline of an in-progress viewport-navigation gesture (pinch,
  /// two-finger pan, space-drag); null while the gesture is a tap, band
  /// or object drag instead. Updates are computed *from the baseline*
  /// (not incrementally), so per-frame float error can't accumulate.
  _NavBaseline? _nav;

  /// True from the first navigation start until every pointer lifts:
  /// the recognizer restarts on finger add/remove, and a latched gesture
  /// must resume navigating, not fall back to band/drag.
  bool _navLatched = false;

  /// Where the gesture's first pointer went down, recorded by the
  /// [Listener]. The scale recognizer only reports the focal point at
  /// *acceptance* (past the ~18 px slop), but the band must anchor and
  /// the object-drag must hit-test where the pointer actually landed.
  Offset? _firstDown;
  int _downPointers = 0;

  @override
  Widget build(BuildContext context) {
    final constructionState = ref.watch(constructionProvider);
    final viewport = CanvasViewport(ref.watch(viewportProvider));
    // The tool revision bumps on every accepted input, so in-progress
    // markers rebuild as the user collects.
    final tool = ref.watch(toolProvider).tool;

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerLift,
      onPointerCancel: _handlePointerCancelled,
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Default .start drag behavior: the band/drag anchor comes from
        // the Listener's _firstDown (the recognizer never reports the
        // pre-slop down position), and .start keeps details.scale
        // baselined at acceptance so a pinch can't open with a jump.
        onTapUp: (details) => _handleTap(ref, viewport, details.localPosition),
        onScaleStart: (details) => _scaleStart(viewport, details),
        onScaleUpdate: (details) => _scaleUpdate(viewport, details),
        onScaleEnd: (details) => _scaleEnd(viewport, details),
        child: CustomPaint(
          painter: GeometryPainter(
            construction: constructionState.construction,
            viewport: viewport,
            revision: constructionState.revision,
            defaultColor: Theme.of(context).colorScheme.primary,
            selectionColor: Theme.of(context).colorScheme.tertiary,
            selectedIds: ref.watch(selectionProvider),
            previewMarkers:
                tool is ToolInputPreview ? tool.previewPositions : const [],
          ),
          foregroundPainter: _MarqueePainter(
            band: _band,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  /// Scroll = zoom about the cursor, on any tool (per PLAN's shortcut
  /// table; panning is space-drag / two-finger, never scroll). Registered
  /// through the [PointerSignalResolver] so a scrollable ancestor and the
  /// canvas can't both consume one event.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      final viewport = CanvasViewport(ref.read(viewportProvider));
      final factor = math.exp(
        -scroll.scrollDelta.dy * GeometryCanvas.scrollZoomPerPixel,
      );
      ref
          .read(viewportProvider.notifier)
          .set(viewport.zoomedAbout(scroll.localPosition, factor));
    });
  }

  bool get _spaceHeld => HardwareKeyboard.instance.logicalKeysPressed
      .contains(LogicalKeyboardKey.space);

  void _handlePointerDown(PointerDownEvent event) {
    _downPointers += 1;
    if (_downPointers == 1) {
      _firstDown = event.localPosition;
    }
  }

  void _handlePointerLift(PointerUpEvent event) {
    _downPointers = math.max(0, _downPointers - 1);
    if (_downPointers == 0) {
      _firstDown = null;
    }
  }

  /// The system revoked the pointer (palm rejection, an OS gesture, a
  /// route change). The scale recognizer folds this into a plain end,
  /// so the rollback has to happen here: a cancelled gesture must never
  /// commit its band or drag. The recognizer's trailing onEnd then finds
  /// nothing left to commit, which is exactly right.
  void _handlePointerCancelled(PointerCancelEvent event) {
    _downPointers = math.max(0, _downPointers - 1);
    if (_downPointers == 0) {
      _firstDown = null;
    }
    _panCancel();
  }

  /// One scale gesture per pointer configuration: the recognizer ends and
  /// restarts whenever a finger is added or removed, so [details] has a
  /// stable pointerCount. Two fingers or a held space bar navigate the
  /// viewport; a plain single pointer is the Phase 7 band/drag.
  void _scaleStart(CanvasViewport viewport, ScaleStartDetails details) {
    if (details.pointerCount >= 2 || _navLatched || _spaceHeld) {
      _navLatched = true;
      final current = CanvasViewport(ref.read(viewportProvider));
      _nav = _NavBaseline(
        startScale: current.state.scale,
        fixedWorld: current.screenToWorld(details.localFocalPoint),
      );
      return;
    }
    // Anchor at the recorded down position, not the acceptance focal —
    // otherwise the band's fixed corner (and the drag's hit test) sit
    // ~18 px of slop away from where the user grabbed.
    _panStart(viewport, _firstDown ?? details.localFocalPoint);
  }

  void _scaleUpdate(CanvasViewport viewport, ScaleUpdateDetails details) {
    final nav = _nav;
    if (nav == null) {
      _panUpdate(viewport, details.localFocalPoint);
      return;
    }
    // Zoom and pan in one solve: the world point under the baseline focal
    // stays glued to the (possibly moving) focal. details.scale == 1 for
    // a single-pointer space-drag, which reduces this to a pure pan.
    ref.read(viewportProvider.notifier).set(
          CanvasViewport.pinning(
            world: nav.fixedWorld,
            focal: details.localFocalPoint,
            scale: nav.startScale * details.scale,
          ),
        );
  }

  /// pointerCount > 0 means fingers are still down — the recognizer is
  /// reconfiguring (a finger joined or left), not finishing. A band or
  /// drag interrupted that way is cancelled, never committed: the user
  /// pivoted to navigation, and committing a half-band would surprise.
  void _scaleEnd(CanvasViewport viewport, ScaleEndDetails details) {
    if (_nav != null) {
      _nav = null;
      if (details.pointerCount == 0) {
        _navLatched = false;
      }
      return;
    }
    if (details.pointerCount > 0) {
      _panCancel();
      return;
    }
    _panEnd(viewport);
  }

  /// A drag in move/select mode: starting over an object moves it (the
  /// drag session lives in `toolProvider`), starting over empty canvas
  /// opens a rubber band. With a tool active the pan is ignored.
  void _panStart(CanvasViewport viewport, Offset screen) {
    if (ref.read(toolProvider).tool != null) {
      return;
    }
    final world = viewport.screenToWorld(screen);
    final construction = ref.read(constructionProvider).construction;
    final hit = const CanvasHitTester().hitTest(
      construction.objects,
      world,
      viewport.screenToWorldLength(GeometryCanvas.hitThresholdPx),
    );
    if (hit != null) {
      // May refuse (derived point): then the pan does nothing — starting
      // a band under an object the user visibly grabbed would surprise.
      ref.read(toolProvider.notifier).startDrag(hit, world);
      return;
    }
    setState(() {
      _bandAnchor = screen;
      _band = Rect.fromPoints(screen, screen);
    });
  }

  void _panUpdate(CanvasViewport viewport, Offset screen) {
    final anchor = _bandAnchor;
    if (anchor != null) {
      setState(() => _band = Rect.fromPoints(anchor, screen));
      return;
    }
    ref
        .read(toolProvider.notifier)
        .updateDrag(viewport.screenToWorld(screen));
  }

  void _panEnd(CanvasViewport viewport) {
    final band = _band;
    if (band == null) {
      ref.read(toolProvider.notifier).endDrag();
      return;
    }
    setState(() {
      _band = null;
      _bandAnchor = null;
    });
    final construction = ref.read(constructionProvider).construction;
    final banded = const CanvasHitTester().objectsInRect(
      construction.objects,
      viewport.screenToWorld(band.topLeft),
      viewport.screenToWorld(band.bottomRight),
    );
    ref.read(selectionProvider.notifier).selectMany(
          [for (final object in banded) object.id],
          additive: HardwareKeyboard.instance.isShiftPressed,
        );
  }

  void _panCancel() {
    ref.read(toolProvider.notifier).cancelDrag();
    setState(() {
      _band = null;
      _bandAnchor = null;
    });
  }

  void _handleTap(WidgetRef ref, CanvasViewport viewport, Offset screen) {
    final world = viewport.screenToWorld(screen);
    // Read (not the build-time capture): the construction mutates between
    // rebuilds, and the hit test must see the tap-time state.
    final construction = ref.read(constructionProvider).construction;
    final hit = const CanvasHitTester().hitTest(
      construction.objects,
      world,
      viewport.screenToWorldLength(GeometryCanvas.hitThresholdPx),
    );
    if (ref.read(toolProvider).tool != null) {
      // An active tool owns every tap — including ones it ignores, so a
      // stray tap mid-collection can't silently retarget the selection.
      ref.read(toolProvider.notifier).handleInput(ToolInput(world, hit: hit));
      return;
    }
    final selection = ref.read(selectionProvider.notifier);
    if (hit == null) {
      selection.clear();
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      selection.toggle(hit.id);
    } else {
      selection.select(hit.id);
    }
  }
}

/// Fixed reference frame of one viewport-navigation gesture: the scale
/// at gesture start and the world point under the starting focal point.
class _NavBaseline {
  const _NavBaseline({required this.startScale, required this.fixedWorld});

  final double startScale;
  final Vec2 fixedWorld;
}

/// The in-progress rubber band: a hairline outline over a translucent
/// fill, in screen coordinates (no viewport transform).
class _MarqueePainter extends CustomPainter {
  _MarqueePainter({required this.band, required this.color});

  final Rect? band;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final band = this.band;
    if (band == null) {
      return;
    }
    canvas.drawRect(band, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawRect(
      band,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_MarqueePainter oldDelegate) =>
      oldDelegate.band != band || oldDelegate.color != color;
}
