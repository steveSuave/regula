import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/construction_provider.dart';
import '../../application/providers/tool_provider.dart';
import '../../application/providers/viewport_provider.dart';
import '../../domain/tools/tool.dart';
import 'canvas_hit_tester.dart';
import 'canvas_viewport.dart';
import 'geometry_painter.dart';

/// The drawing surface: hosts the [GeometryPainter] and turns taps into
/// [ToolInput]s for the active tool.
///
/// Phase 5 scope is taps only. Drag (move/select, one command per
/// gesture), pinch/scroll zoom and pan land in Phases 7–8 on top of the
/// same gesture stack.
class GeometryCanvas extends ConsumerWidget {
  const GeometryCanvas({super.key});

  /// Hit-test radius in logical pixels (PLAN: 8 px), converted to world
  /// units per tap so it feels the same at every zoom level.
  static const double hitThresholdPx = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final constructionState = ref.watch(constructionProvider);
    final viewport = CanvasViewport(ref.watch(viewportProvider));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(ref, viewport, details.localPosition),
      child: CustomPaint(
        painter: GeometryPainter(
          construction: constructionState.construction,
          viewport: viewport,
          revision: constructionState.revision,
          defaultColor: Theme.of(context).colorScheme.primary,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _handleTap(WidgetRef ref, CanvasViewport viewport, Offset screen) {
    final world = viewport.screenToWorld(screen);
    // Read (not the build-time capture): the construction mutates between
    // rebuilds, and the hit test must see the tap-time state.
    final construction = ref.read(constructionProvider).construction;
    final hit = const CanvasHitTester().hitTest(
      construction.objects,
      world,
      viewport.screenToWorldLength(hitThresholdPx),
    );
    ref.read(toolProvider.notifier).handleInput(ToolInput(world, hit: hit));
  }
}
