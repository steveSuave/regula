import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/construction_provider.dart';
import '../../application/providers/selection_provider.dart';
import '../../application/providers/tool_provider.dart';
import '../../application/providers/viewport_provider.dart';
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
/// Object drag (one command per gesture), pinch/scroll zoom and pan land
/// later in Phases 7–8 on top of the same gesture stack.
class GeometryCanvas extends ConsumerStatefulWidget {
  const GeometryCanvas({super.key});

  /// Hit-test radius in logical pixels (PLAN: 8 px), converted to world
  /// units per tap so it feels the same at every zoom level.
  static const double hitThresholdPx = 8;

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

  @override
  Widget build(BuildContext context) {
    final constructionState = ref.watch(constructionProvider);
    final viewport = CanvasViewport(ref.watch(viewportProvider));
    // The tool revision bumps on every accepted input, so in-progress
    // markers rebuild as the user collects.
    final tool = ref.watch(toolProvider).tool;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // .down (not the default .start): the band must anchor where the
      // pointer went down, not where the drag won the gesture arena —
      // with .start a fast drag loses its first ~18 px of slop.
      dragStartBehavior: DragStartBehavior.down,
      onTapUp: (details) => _handleTap(ref, viewport, details.localPosition),
      onPanStart: (details) => _panStart(viewport, details.localPosition),
      onPanUpdate: (details) => _panUpdate(viewport, details.localPosition),
      onPanEnd: (_) => _panEnd(viewport),
      onPanCancel: _panCancel,
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
    );
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
