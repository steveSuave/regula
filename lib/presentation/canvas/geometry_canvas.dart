import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/command_stack_provider.dart';
import '../../application/providers/construction_provider.dart';
import '../../application/providers/document_settings_provider.dart';
import '../../application/providers/selection_provider.dart';
import '../../application/providers/tool_provider.dart';
import '../../application/providers/viewport_provider.dart';
import '../../domain/commands/change_attributes_command.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/math/vec2.dart';
import '../../domain/tools/delete_tool.dart';
import '../../domain/tools/tool.dart';
import '../../domain/tools/visibility_tool.dart';
import '../panels/delete_selection.dart';
import '../theme/app_theme.dart';
import 'canvas_hit_tester.dart';
import 'canvas_viewport.dart';
import 'geometry_painter.dart';
import 'grid_layout.dart';
import 'label_layout.dart';

/// The drawing surface: hosts the [GeometryPainter] and turns taps into
/// [ToolInput]s for the active tool — or, with no tool active
/// (move/select mode), into selection changes: tap selects the hit
/// object, shift-tap toggles it — as does a long-press, the shift
/// equivalent for touch — tapping empty canvas clears, and a drag
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

  /// Hit-test radius in logical pixels, converted to world units per
  /// tap so it feels the same at every zoom level. Pointer-kind based
  /// (Phase 25): a fingertip is less precise than a cursor, so touch
  /// doubles the radius — kind-gated rather than platform-gated, so a
  /// touch-screen laptop and an iPad with a mouse both do the right
  /// thing. The converted threshold flows on into `ToolInput.snapThreshold`,
  /// the Phase 20 point ladder and the random-stamp radius.
  static const double hitThresholdPx = 8;
  static const double touchHitThresholdPx = 16;

  /// The hit radius for [kind]; null (no pointer information) reads as
  /// mouse-like.
  static double hitThresholdFor(PointerDeviceKind? kind) =>
      kind == PointerDeviceKind.touch ? touchHitThresholdPx : hitThresholdPx;

  /// How far (logical px) a dragged label's offset may stray from its
  /// object's anchor — "an appropriate place around its parent".
  static const double labelOffsetMaxPx = 40;

  /// Slack (logical px) around the label's text rect when grabbing it.
  static const double labelGrabSlackPx = 2;

  /// Exponential zoom rate per scrolled pixel: factor = e^(−dy · rate),
  /// so one mouse-wheel notch (~100 px) zooms ~22 % and scrolling is
  /// exactly reversible (+dy then −dy lands back on the same scale).
  static const double scrollZoomPerPixel = 0.002;

  @override
  ConsumerState<GeometryCanvas> createState() => _GeometryCanvasState();
}

class _GeometryCanvasState extends ConsumerState<GeometryCanvas> {
  /// Whether [tool] is the Show/Hide visibility variant, which turns on
  /// the hidden-object view: the painter dims them in and the tap hit
  /// test includes them. Tool-scoped state — it vanishes with the tool.
  static bool _revealsHidden(Tool? tool) =>
      tool is VisibilityTool && tool.revealsHidden;

  /// The snap-to-grid step in world units — the same adaptive step the
  /// Phase 36 grid draws at, so snapped points land on drawn crossings —
  /// or 0 while the document's snap toggle is off. `gridStep` lives in
  /// presentation; passing the resolved number keeps `domain/` clean of
  /// this layer (the `snapThreshold` precedent).
  double _gridSnapStep(CanvasViewport viewport) =>
      ref.read(documentSettingsProvider).snapToGrid
          ? gridStep(viewport.state.scale)
          : 0;

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

  /// Device kind of the gesture's first pointer — decides the hit
  /// threshold for drags, whose recognizer details don't carry a kind.
  PointerDeviceKind? _firstDownKind;

  /// In-progress label drag; null when none. Like the band, this is
  /// local widget state — the construction is untouched until the one
  /// [ChangeAttributesCommand] commits on release (cancel just drops it).
  _LabelDrag? _labelDrag;

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
        onTapUp: (details) =>
            _handleTap(ref, viewport, details.localPosition, details.kind),
        // Long-press = the touch shift-click: toggles the hit object in
        // the selection set (the Phase 26 convention). Registered only in
        // move/select mode — with a tool active the recognizer must not
        // enter the arena, or a slow tap mid-collection would be
        // swallowed instead of reaching onTapUp.
        onLongPressStart: tool == null
            ? (details) => _handleLongPress(viewport, details.localPosition)
            : null,
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
            previewObjectIds: tool is ToolInputPreview
                ? tool.previewObjectIds.toSet()
                : const {},
            labelDragPreview: switch (_labelDrag) {
              null => null,
              final drag => (id: drag.id, offset: drag.offset),
            },
            showHidden: _revealsHidden(tool),
            showAxes: ref.watch(documentSettingsProvider).showAxes,
            showGrid: ref.watch(documentSettingsProvider).showGrid,
            // Theme-less hosts (bare-widget tests) keep the painter's
            // built-in light colors.
            axisColor: Theme.of(context).extension<CanvasColors>()?.axis ??
                const Color(0xFF757575),
            gridColor: Theme.of(context).extension<CanvasColors>()?.grid ??
                const Color(0xFFE3E6EA),
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

  /// Figma-style pointer-signal mapping (decided in Phase 14, see PLAN):
  /// plain scroll = pan (a trackpad two-finger swipe pans naturally),
  /// pinch = zoom about the cursor (the web engine synthesizes a
  /// [PointerScaleEvent] from a browser pinch's ctrl-flagged wheel event),
  /// and a *physical* `Ctrl`/`Cmd` + scroll = zoom too, so mouse users
  /// keep a wheel zoom. Registered through the [PointerSignalResolver] so
  /// a scrollable ancestor and the canvas can't both consume one event.
  void _handlePointerSignal(PointerSignalEvent event) {
    switch (event) {
      case PointerScaleEvent():
        GestureBinding.instance.pointerSignalResolver.register(event, (
          event,
        ) {
          final pinch = event as PointerScaleEvent;
          final viewport = CanvasViewport(ref.read(viewportProvider));
          ref
              .read(viewportProvider.notifier)
              .set(viewport.zoomedAbout(pinch.localPosition, pinch.scale));
        });
      case PointerScrollEvent():
        GestureBinding.instance.pointerSignalResolver.register(event, (
          event,
        ) {
          final scroll = event as PointerScrollEvent;
          final viewport = CanvasViewport(ref.read(viewportProvider));
          final keyboard = HardwareKeyboard.instance;
          if (keyboard.isControlPressed || keyboard.isMetaPressed) {
            final factor = math.exp(
              -scroll.scrollDelta.dy * GeometryCanvas.scrollZoomPerPixel,
            );
            ref
                .read(viewportProvider.notifier)
                .set(viewport.zoomedAbout(scroll.localPosition, factor));
          } else {
            // Content moves *against* the scroll delta (pannedByScreen is
            // content-follows) — wheel-down scrolls the canvas up like a
            // document, and a natural-scrolling trackpad's content follows
            // the fingers.
            ref
                .read(viewportProvider.notifier)
                .set(viewport.pannedByScreen(-scroll.scrollDelta));
          }
        });
      default:
        return;
    }
  }

  bool get _spaceHeld => HardwareKeyboard.instance.logicalKeysPressed
      .contains(LogicalKeyboardKey.space);

  void _handlePointerDown(PointerDownEvent event) {
    _downPointers += 1;
    if (_downPointers == 1) {
      _firstDown = event.localPosition;
      _firstDownKind = event.kind;
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

  /// A drag in move/select mode: starting over a label moves the label,
  /// starting over an object moves it (the drag session lives in
  /// `toolProvider`), starting over empty canvas opens a rubber band.
  /// With a tool active the pan is ignored.
  void _panStart(CanvasViewport viewport, Offset screen) {
    if (ref.read(toolProvider).tool != null) {
      return;
    }
    final world = viewport.screenToWorld(screen);
    final construction = ref.read(constructionProvider).construction;
    // Labels first — a label deliberately floats *off* its geometry, so
    // the geometry hit test below can never reach it. Reverse insertion
    // order picks the topmost of overlapping labels, like the painter's
    // z-order.
    for (final object in construction.objects.toList().reversed) {
      final rect = labelScreenRect(object, viewport);
      if (rect == null ||
          !rect.inflate(GeometryCanvas.labelGrabSlackPx).contains(screen)) {
        continue;
      }
      setState(() {
        _labelDrag = _LabelDrag(
          id: object.id,
          grab: screen,
          startOffset: Offset(
            object.attributes.labelDx,
            object.attributes.labelDy,
          ),
        );
      });
      return;
    }
    final hit = const CanvasHitTester().hitTest(
      construction.objects,
      world,
      viewport.screenToWorldLength(
        GeometryCanvas.hitThresholdFor(_firstDownKind),
      ),
      worldPerPx: viewport.screenToWorldLength(1),
    );
    if (hit != null) {
      // May refuse (derived point): then the pan does nothing — starting
      // a band under an object the user visibly grabbed would surprise.
      ref
          .read(toolProvider.notifier)
          .startDrag(hit, world, gridSnapStep: _gridSnapStep(viewport));
      return;
    }
    setState(() {
      _bandAnchor = screen;
      _band = Rect.fromPoints(screen, screen);
    });
  }

  void _panUpdate(CanvasViewport viewport, Offset screen) {
    final labelDrag = _labelDrag;
    if (labelDrag != null) {
      setState(() => _labelDrag = labelDrag.movedTo(screen));
      return;
    }
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
    final labelDrag = _labelDrag;
    if (labelDrag != null) {
      setState(() => _labelDrag = null);
      final object = ref
          .read(constructionProvider)
          .construction
          .byId(labelDrag.id);
      final offset = labelDrag.offset;
      if (object == null || offset == labelDrag.startOffset) {
        return;
      }
      ref.read(commandStackProvider.notifier).execute(
            ChangeAttributesCommand({
              object.id: object.attributes.copyWith(
                labelDx: offset.dx,
                labelDy: offset.dy,
              ),
            }),
          );
      return;
    }
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
      _labelDrag = null;
    });
  }

  /// Long-press in move/select mode: toggles the topmost hit object in
  /// the selection — the multi-select path for pointers without a shift
  /// key. An empty-canvas long-press does nothing: clearing is the plain
  /// tap's job, and an accidental hold must not drop a built-up
  /// selection. Trade-off, documented here on purpose: while the
  /// recognizer is registered, holding still past the long-press timeout
  /// before dragging toggles instead of starting the object drag / band —
  /// drags that begin moving within the timeout are unaffected.
  void _handleLongPress(CanvasViewport viewport, Offset screen) {
    final construction = ref.read(constructionProvider).construction;
    final hit = const CanvasHitTester().hitTest(
      construction.objects,
      viewport.screenToWorld(screen),
      viewport.screenToWorldLength(
        GeometryCanvas.hitThresholdFor(_firstDownKind),
      ),
      worldPerPx: viewport.screenToWorldLength(1),
    );
    if (hit == null) {
      return;
    }
    HapticFeedback.selectionClick();
    ref.read(selectionProvider.notifier).toggle(hit.id);
  }

  /// One Delete-tool tap: ask about the cascade first, then dispatch
  /// [input] through the normal tool funnel. The guards after the
  /// async gap keep a cancelled dialog — or a construction that lost
  /// the hit while the dialog was up — from putting an empty delete
  /// on the undo stack.
  Future<void> _tapDelete(WidgetRef ref, GeoObject hit, ToolInput input) async {
    if (!await confirmCascadeDelete(context, ref, [hit.id])) {
      return;
    }
    if (!mounted ||
        !ref.read(constructionProvider).construction.contains(hit.id)) {
      return;
    }
    ref.read(toolProvider.notifier).handleInput(input);
  }

  void _handleTap(
    WidgetRef ref,
    CanvasViewport viewport,
    Offset screen,
    PointerDeviceKind? kind,
  ) {
    final world = viewport.screenToWorld(screen);
    // Read (not the build-time capture): the construction mutates between
    // rebuilds, and the hit test must see the tap-time state.
    final construction = ref.read(constructionProvider).construction;
    final tool = ref.read(toolProvider).tool;
    final threshold =
        viewport.screenToWorldLength(GeometryCanvas.hitThresholdFor(kind));
    final hits = const CanvasHitTester().hitTestAll(
      construction.objects,
      world,
      threshold,
      worldPerPx: viewport.screenToWorldLength(1),
      includeHidden: _revealsHidden(tool),
    );
    final hit = hits.firstOrNull;
    if (tool != null) {
      // An active tool owns every tap — including ones it ignores, so a
      // stray tap mid-collection can't silently retarget the selection.
      final input = ToolInput(
        world,
        hit: hit,
        extraHits: hits.length > 1 ? hits.sublist(1) : const [],
        snapThreshold: threshold,
        objects: construction.objects,
        gridSnapStep: _gridSnapStep(viewport),
      );
      if (tool is DeleteTool) {
        // Deleting cascades, and the cascade warning is a dialog — a
        // presentation concern the tool pipeline can't await. Pre-gate
        // here; the tool itself only ever emits the command.
        if (hit != null) {
          _tapDelete(ref, hit, input);
        }
        return;
      }
      ref.read(toolProvider.notifier).handleInput(input);
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

/// One label drag: which label, where it was grabbed, and the offset it
/// started from. [movedTo] carries the pointer delta over to the offset,
/// clamped radially to [GeometryCanvas.labelOffsetMaxPx] so the label
/// stays around its parent's anchor.
class _LabelDrag {
  const _LabelDrag({
    required this.id,
    required this.grab,
    required this.startOffset,
    Offset? offset,
  }) : offset = offset ?? startOffset;

  final String id;
  final Offset grab;
  final Offset startOffset;
  final Offset offset;

  _LabelDrag movedTo(Offset screen) {
    var moved = startOffset + (screen - grab);
    final distance = moved.distance;
    if (distance > GeometryCanvas.labelOffsetMaxPx) {
      moved = moved * (GeometryCanvas.labelOffsetMaxPx / distance);
    }
    return _LabelDrag(
      id: id,
      grab: grab,
      startOffset: startOffset,
      offset: moved,
    );
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
