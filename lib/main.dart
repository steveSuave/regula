import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/object_ids.dart';
import 'application/providers/command_stack_provider.dart';
import 'application/providers/tool_provider.dart';
import 'domain/construction/geo_object.dart';
import 'domain/construction/objects/angle_bisector_line.dart';
import 'domain/construction/objects/arc.dart';
import 'domain/construction/objects/centroid.dart';
import 'domain/construction/objects/circle_center_point.dart';
import 'domain/construction/objects/circumcenter.dart';
import 'domain/construction/objects/compass_circle.dart';
import 'domain/construction/objects/incenter.dart';
import 'domain/construction/objects/line_angle.dart';
import 'domain/construction/objects/line_through_two_points.dart';
import 'domain/construction/objects/midpoint.dart';
import 'domain/construction/objects/orthocenter.dart';
import 'domain/construction/objects/parallel_line.dart';
import 'domain/construction/objects/perpendicular_line.dart';
import 'domain/construction/objects/ray.dart';
import 'domain/construction/objects/sector.dart';
import 'domain/construction/objects/segment.dart';
import 'domain/construction/objects/segment_ratio_point.dart';
import 'domain/construction/objects/three_point_circle.dart';
import 'domain/construction/objects/vertex_angle.dart';
import 'domain/tools/point_and_line_tool.dart';
import 'domain/tools/point_on_object_tool.dart';
import 'domain/tools/point_tool.dart';
import 'domain/tools/three_point_tool.dart';
import 'domain/tools/tool.dart';
import 'domain/tools/triangle_center_tool.dart';
import 'domain/tools/two_line_tool.dart';
import 'domain/tools/two_point_tool.dart';
import 'presentation/canvas/geometry_canvas.dart';
import 'presentation/panels/attributes_inspector.dart';

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

/// A two-point-menu item's payload: asynchronously produces the builder
/// for the picked object, or null to abort (ratio dialog cancelled).
typedef TwoPointPick = Future<TwoPointBuilder?> Function();

// ThreePointTool builders as top-level functions, not inline lambdas:
// their tear-offs are canonicalized, so the app bar can tell which menu
// the active ThreePointTool came from and highlight the right icon.
GeoObject _buildAngleBisector(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    AngleBisectorLine(id: id, arm1: a, vertex: b, arm2: c);

GeoObject _buildThreePointCircle(
        String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    ThreePointCircle(id: id, point1: a, point2: b, point3: c);

GeoObject _buildCompassCircle(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    CompassCircle(id: id, radiusPoint1: a, radiusPoint2: b, center: c);

GeoObject _buildArc(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    Arc(id: id, start: a, via: b, end: c);

GeoObject _buildSector(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    Sector(id: id, center: a, start: b, end: c);

GeoObject _buildVertexAngle(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    VertexAngle(id: id, arm1: a, vertex: b, arm2: c);

GeoObject _buildLineAngle(String id, GeoLine first, GeoLine second) =>
    LineAngle(id: id, line1: first, line2: second);

/// Wraps a ready [TwoPointBuilder] as a trivial [TwoPointPick]; also
/// gives the builder lambda's parameters their types (a bare async
/// closure's `FutureOr` return context doesn't reach them).
TwoPointPick _pick(TwoPointBuilder builder) => () async => builder;

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
    // ThreePointTool serves two menus, so the highlights key on which
    // top-level builder function the active tool carries.
    final lineConstructionActive = activeTool is PointAndLineTool ||
        (activeTool is ThreePointTool &&
            activeTool.build == _buildAngleBisector);
    final circleConstructionActive = activeTool is ThreePointTool &&
        const {_buildThreePointCircle, _buildCompassCircle, _buildArc,
            _buildSector}.contains(activeTool.build);
    final angleConstructionActive = activeTool is TwoLineTool ||
        (activeTool is ThreePointTool &&
            activeTool.build == _buildVertexAngle);
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
          // Values are async so an item can collect extra input (the
          // segment-ratio dialog) before the tool exists; returning null
          // (dialog cancelled) leaves the current tool untouched.
          PopupMenuButton<TwoPointPick>(
            tooltip: 'Two-point objects: pick one, then tap two points',
            icon: Icon(
              Icons.timeline,
              color: twoPointToolActive ? highlight : null,
            ),
            onSelected: (pick) async {
              final builder = await pick();
              if (builder == null) return;
              ref.read(toolProvider.notifier).activate(
                    TwoPointTool(newId: newObjectId, build: builder),
                  );
            },
            itemBuilder: (context) => [
              PopupMenuItem<TwoPointPick>(
                value: _pick((id, a, b) =>
                    LineThroughTwoPoints(id: id, point1: a, point2: b)),
                child: const Text('Line'),
              ),
              PopupMenuItem<TwoPointPick>(
                value:
                    _pick((id, a, b) => Segment(id: id, point1: a, point2: b)),
                child: const Text('Segment'),
              ),
              PopupMenuItem<TwoPointPick>(
                value: _pick((id, a, b) => Ray(id: id, origin: a, through: b)),
                child: const Text('Ray (origin, then direction)'),
              ),
              PopupMenuItem<TwoPointPick>(
                value: _pick((id, a, b) =>
                    CircleCenterPoint(id: id, center: a, onCircle: b)),
                child: const Text('Circle (center, then rim)'),
              ),
              PopupMenuItem<TwoPointPick>(
                value:
                    _pick((id, a, b) => Midpoint(id: id, point1: a, point2: b)),
                child: const Text('Midpoint'),
              ),
              PopupMenuItem<TwoPointPick>(
                value: () async {
                  final ratio = await _askRatio(context);
                  if (ratio == null) return null;
                  GeoObject build(String id, GeoPoint a, GeoPoint b) =>
                      SegmentRatioPoint(
                        id: id,
                        point1: a,
                        point2: b,
                        ratio: ratio,
                      );
                  return build;
                },
                child: const Text('Segment-ratio point…'),
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
          PopupMenuButton<Tool Function()>(
            tooltip: 'Line constructions: perpendicular, parallel, bisector',
            icon: Icon(
              Icons.line_axis,
              color: lineConstructionActive ? highlight : null,
            ),
            onSelected: (createTool) =>
                ref.read(toolProvider.notifier).activate(createTool()),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: () => PointAndLineTool(
                  newId: newObjectId,
                  build: PerpendicularLine.new,
                ),
                child: const Text('Perpendicular line'),
              ),
              PopupMenuItem(
                value: () => PointAndLineTool(
                  newId: newObjectId,
                  build: ParallelLine.new,
                ),
                child: const Text('Parallel line'),
              ),
              PopupMenuItem(
                value: () => ThreePointTool(
                  newId: newObjectId,
                  build: _buildAngleBisector,
                ),
                child: const Text('Angle bisector (arm, vertex, arm)'),
              ),
            ],
          ),
          PopupMenuButton<Tool Function()>(
            tooltip: 'Circle constructions: three-point circle, compass, '
                'arc, sector',
            icon: Icon(
              Icons.circle_outlined,
              color: circleConstructionActive ? highlight : null,
            ),
            onSelected: (createTool) =>
                ref.read(toolProvider.notifier).activate(createTool()),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: () => ThreePointTool(
                  newId: newObjectId,
                  build: _buildThreePointCircle,
                ),
                child: const Text('Circle through three points'),
              ),
              PopupMenuItem(
                value: () => ThreePointTool(
                  newId: newObjectId,
                  build: _buildCompassCircle,
                ),
                child: const Text('Compass (radius points, then center)'),
              ),
              PopupMenuItem(
                value: () => ThreePointTool(
                  newId: newObjectId,
                  build: _buildArc,
                ),
                child: const Text('Arc (start, via, end)'),
              ),
              PopupMenuItem(
                value: () => ThreePointTool(
                  newId: newObjectId,
                  build: _buildSector,
                ),
                child: const Text('Sector (center, rim, then angle)'),
              ),
            ],
          ),
          PopupMenuButton<Tool Function()>(
            tooltip: 'Angles: at a vertex, or between two lines',
            icon: Icon(
              Icons.square_foot,
              color: angleConstructionActive ? highlight : null,
            ),
            onSelected: (createTool) =>
                ref.read(toolProvider.notifier).activate(createTool()),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: () => ThreePointTool(
                  newId: newObjectId,
                  build: _buildVertexAngle,
                ),
                child: const Text('Angle at vertex (arm, vertex, arm)'),
              ),
              PopupMenuItem(
                value: () => TwoLineTool(
                  newId: newObjectId,
                  build: _buildLineAngle,
                ),
                child: const Text('Angle between two lines'),
              ),
            ],
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
      body: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: GeometryCanvas()),
          AttributesInspector(),
        ],
      ),
    );
  }
}

/// Asks for a segment-ratio interpolation parameter. Returns null when
/// cancelled — unparseable input reads as cancel too, so OK on garbage
/// quietly does nothing rather than committing a bogus ratio.
Future<double?> _askRatio(BuildContext context) => showDialog<double>(
      context: context,
      builder: (context) => const _RatioDialog(),
    );

/// The dialog owns its [TextEditingController] so it outlives the exit
/// animation (disposing right after `showDialog` returns crashes the
/// still-rendering `TextField`).
class _RatioDialog extends StatefulWidget {
  const _RatioDialog();

  @override
  State<_RatioDialog> createState() => _RatioDialogState();
}

class _RatioDialogState extends State<_RatioDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Segment ratio'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '0 = first point, 1 = second — e.g. 0.25 or 1/4',
        ),
        onSubmitted: (text) => Navigator.pop(context, _parseRatio(text)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _parseRatio(_controller.text)),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Parses "0.25", "-1", or a fraction "1/4". Null when unparseable.
double? _parseRatio(String text) {
  final parts = text.split('/');
  if (parts.length == 2) {
    final numerator = double.tryParse(parts[0].trim());
    final denominator = double.tryParse(parts[1].trim());
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    return numerator / denominator;
  }
  return double.tryParse(text.trim());
}
