import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/object_ids.dart';
import 'application/providers/command_stack_provider.dart';
import 'application/providers/tool_provider.dart';
import 'domain/construction/objects/centroid.dart';
import 'domain/construction/objects/circle_center_point.dart';
import 'domain/construction/objects/circumcenter.dart';
import 'domain/construction/objects/incenter.dart';
import 'domain/construction/objects/line_through_two_points.dart';
import 'domain/construction/objects/midpoint.dart';
import 'domain/construction/objects/orthocenter.dart';
import 'domain/construction/objects/segment.dart';
import 'domain/tools/point_on_object_tool.dart';
import 'domain/tools/point_tool.dart';
import 'domain/tools/triangle_center_tool.dart';
import 'domain/tools/two_point_tool.dart';
import 'presentation/canvas/geometry_canvas.dart';

void main() {
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fgex',
      theme: ThemeData.light(),
      home: const EditorScreen(),
    );
  }
}

/// Canvas plus a bare-bones app bar: point tool toggle and undo/redo.
///
/// The real toolbar/tool palette belongs in `presentation/panels/` and
/// arrives with the wider tool coverage (Phases 6–7); this is just enough
/// chrome to exercise Phase 5's canvas end to end.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTool = ref.watch(toolProvider).tool;
    final pointToolActive = activeTool is PointTool;
    final centerToolActive = activeTool is TriangleCenterTool;
    final twoPointToolActive = activeTool is TwoPointTool;
    final pointOnObjectActive = activeTool is PointOnObjectTool;
    final undoRedo = ref.watch(commandStackProvider);
    final highlight = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('fgex'),
        actions: [
          IconButton(
            tooltip: pointToolActive
                ? 'Leave point tool (back to move/select)'
                : 'Point tool: tap the canvas to place points',
            isSelected: pointToolActive,
            icon: const Icon(Icons.control_point),
            onPressed: () {
              final notifier = ref.read(toolProvider.notifier);
              if (pointToolActive) {
                notifier.deactivate();
              } else {
                notifier.activate(PointTool(newId: newObjectId));
              }
            },
          ),
          PopupMenuButton<TwoPointBuilder>(
            tooltip: 'Two-point objects: pick one, then tap two points',
            icon: Icon(
              Icons.timeline,
              color: twoPointToolActive ? highlight : null,
            ),
            onSelected: (builder) => ref.read(toolProvider.notifier).activate(
                  TwoPointTool(newId: newObjectId, build: builder),
                ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: (id, a, b) =>
                    LineThroughTwoPoints(id: id, point1: a, point2: b),
                child: const Text('Line'),
              ),
              PopupMenuItem(
                value: (id, a, b) => Segment(id: id, point1: a, point2: b),
                child: const Text('Segment'),
              ),
              PopupMenuItem(
                value: (id, a, b) =>
                    CircleCenterPoint(id: id, center: a, onCircle: b),
                child: const Text('Circle (center, then rim)'),
              ),
              PopupMenuItem(
                value: (id, a, b) => Midpoint(id: id, point1: a, point2: b),
                child: const Text('Midpoint'),
              ),
            ],
          ),
          IconButton(
            tooltip: pointOnObjectActive
                ? 'Leave point-on-object tool'
                : 'Point on object: tap a line or circle',
            isSelected: pointOnObjectActive,
            icon: const Icon(Icons.gps_fixed),
            onPressed: () {
              final notifier = ref.read(toolProvider.notifier);
              if (pointOnObjectActive) {
                notifier.deactivate();
              } else {
                notifier.activate(PointOnObjectTool(newId: newObjectId));
              }
            },
          ),
          PopupMenuButton<TriangleCenterBuilder>(
            tooltip: 'Triangle centers: pick one, then tap three points',
            icon: Icon(
              Icons.change_history,
              color: centerToolActive ? highlight : null,
            ),
            onSelected: (builder) => ref.read(toolProvider.notifier).activate(
                  TriangleCenterTool(newId: newObjectId, buildCenter: builder),
                ),
            itemBuilder: (context) => const [
              PopupMenuItem(value: Centroid.new, child: Text('Centroid')),
              PopupMenuItem(
                value: Orthocenter.new,
                child: Text('Orthocenter'),
              ),
              PopupMenuItem(value: Incenter.new, child: Text('Incenter')),
              PopupMenuItem(
                value: Circumcenter.new,
                child: Text('Circumcenter'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Undo',
            icon: const Icon(Icons.undo),
            onPressed: undoRedo.canUndo
                ? () => ref.read(commandStackProvider.notifier).undo()
                : null,
          ),
          IconButton(
            tooltip: 'Redo',
            icon: const Icon(Icons.redo),
            onPressed: undoRedo.canRedo
                ? () => ref.read(commandStackProvider.notifier).redo()
                : null,
          ),
        ],
      ),
      body: const GeometryCanvas(),
    );
  }
}
