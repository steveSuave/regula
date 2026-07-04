import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/object_ids.dart';
import '../../application/providers/tool_provider.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/angle_bisector_line.dart';
import '../../domain/construction/objects/arc.dart';
import '../../domain/construction/objects/central_reflection_point.dart';
import '../../domain/construction/objects/centroid.dart';
import '../../domain/construction/objects/circle_center_point.dart';
import '../../domain/construction/objects/circumcenter.dart';
import '../../domain/construction/objects/compass_circle.dart';
import '../../domain/construction/objects/incenter.dart';
import '../../domain/construction/objects/line_angle.dart';
import '../../domain/construction/objects/line_through_two_points.dart';
import '../../domain/construction/objects/midpoint.dart';
import '../../domain/construction/objects/orthocenter.dart';
import '../../domain/construction/objects/parallel_line.dart';
import '../../domain/construction/objects/perpendicular_line.dart';
import '../../domain/construction/objects/ray.dart';
import '../../domain/construction/objects/reflected_point.dart';
import '../../domain/construction/objects/sector.dart';
import '../../domain/construction/objects/segment.dart';
import '../../domain/construction/objects/segment_ratio_point.dart';
import '../../domain/construction/objects/three_point_circle.dart';
import '../../domain/construction/objects/translated_point.dart';
import '../../domain/construction/objects/vertex_angle.dart';
import '../../domain/tools/angle_by_size_tool.dart';
import '../../domain/tools/intersection_tool.dart';
import '../../domain/tools/isosceles_trapezium_macro_tool.dart';
import '../../domain/tools/kite_macro_tool.dart';
import '../../domain/tools/parallelogram_macro_tool.dart';
import '../../domain/tools/point_and_line_tool.dart';
import '../../domain/tools/point_tool.dart';
import '../../domain/tools/rectangle_macro_tool.dart';
import '../../domain/tools/rhombus_macro_tool.dart';
import '../../domain/tools/right_trapezium_macro_tool.dart';
import '../../domain/tools/rotated_point_tool.dart';
import '../../domain/tools/square_macro_tool.dart';
import '../../domain/tools/three_point_tool.dart';
import '../../domain/tools/tool.dart';
import '../../domain/tools/trapezium_macro_tool.dart';
import '../../domain/tools/triangle_center_tool.dart';
import '../../domain/tools/two_line_tool.dart';
import '../../domain/tools/two_point_tool.dart';
import '../shortcuts/shortcut_table.dart';

/// One flyout item's payload: asynchronously produces the tool to
/// activate, or null to abort (a dialog cancelled — the current tool
/// stays untouched).
typedef ToolPick = Future<Tool?> Function();

/// One flyout row: label, tool factory, and the [AppAction] whose
/// shortcut is shown as trailing key text (null = no binding to show).
typedef ToolItem = (String, ToolPick, AppAction?);

// Builders as public top-level functions, not inline lambdas: their
// tear-offs are canonicalized (`==` across separate tear-offs), which the
// group highlights rely on — and the keyboard shortcuts in main.dart
// activate identical tools by reusing them.

GeoObject buildLine(String id, GeoPoint a, GeoPoint b) =>
    LineThroughTwoPoints(id: id, point1: a, point2: b);

GeoObject buildSegment(String id, GeoPoint a, GeoPoint b) =>
    Segment(id: id, point1: a, point2: b);

GeoObject buildRay(String id, GeoPoint a, GeoPoint b) =>
    Ray(id: id, origin: a, through: b);

GeoObject buildCircle(String id, GeoPoint a, GeoPoint b) =>
    CircleCenterPoint(id: id, center: a, onCircle: b);

GeoObject buildMidpoint(String id, GeoPoint a, GeoPoint b) =>
    Midpoint(id: id, point1: a, point2: b);

GeoObject buildAngleBisector(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    AngleBisectorLine(id: id, arm1: a, vertex: b, arm2: c);

GeoObject buildThreePointCircle(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    ThreePointCircle(id: id, point1: a, point2: b, point3: c);

GeoObject buildCompassCircle(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    CompassCircle(id: id, radiusPoint1: a, radiusPoint2: b, center: c);

GeoObject buildArc(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    Arc(id: id, start: a, via: b, end: c);

GeoObject buildSector(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    Sector(id: id, center: a, start: b, end: c);

GeoObject buildVertexAngle(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    VertexAngle(id: id, arm1: a, vertex: b, arm2: c);

GeoObject buildLineAngle(String id, GeoLine first, GeoLine second) =>
    LineAngle(id: id, line1: first, line2: second);

GeoObject buildCentralReflection(String id, GeoPoint a, GeoPoint b) =>
    CentralReflectionPoint(id: id, point: a, center: b);

GeoObject buildTranslatedPoint(String id, GeoPoint a, GeoPoint b, GeoPoint c) =>
    TranslatedPoint(id: id, point: a, vectorFrom: b, vectorTo: c);

/// Named parameters match [PointAndLineBuilder]; the point slot is the
/// point to mirror, the line slot the mirror axis.
GeoObject buildReflectedPoint({
  required String id,
  required GeoPoint through,
  required GeoLine reference,
}) =>
    ReflectedPoint(id: id, point: through, mirror: reference);

const _lineBuilders = {buildLine, buildSegment, buildRay};
const _circleBuilders = {
  buildThreePointCircle,
  buildCompassCircle,
  buildArc,
  buildSector,
};

/// The tool palette (PLAN "Toolbar / tool palette"): five flyout groups —
/// Points, Lines, Circles, Angles, Macros; Transform arrives with Phase
/// 15. The active tool's group icon is highlighted; double-clicking the
/// highlighted icon deactivates the tool (Esc and `V` also work).
class GeometryToolbar extends ConsumerWidget {
  const GeometryToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tool = ref.watch(toolProvider).tool;

    // Points is the catch-all for TwoPointTools whose builder isn't
    // claimed by Lines, Circles or Transform: that covers buildMidpoint
    // *and* the segment-ratio dialog's closure, which captures the ratio
    // and so can never be a canonicalized tear-off.
    final pointsActive =
        tool is PointTool ||
        tool is IntersectionTool ||
        tool is TriangleCenterTool ||
        (tool is TwoPointTool &&
            !_lineBuilders.contains(tool.build) &&
            tool.build != buildCircle &&
            tool.build != buildCentralReflection);
    final linesActive =
        (tool is PointAndLineTool && tool.build != buildReflectedPoint) ||
        (tool is ThreePointTool && tool.build == buildAngleBisector) ||
        (tool is TwoPointTool && _lineBuilders.contains(tool.build));
    final circlesActive =
        (tool is TwoPointTool && tool.build == buildCircle) ||
        (tool is ThreePointTool && _circleBuilders.contains(tool.build));
    final anglesActive =
        tool is TwoLineTool ||
        tool is AngleBySizeTool ||
        (tool is ThreePointTool && tool.build == buildVertexAngle);
    final transformActive =
        tool is RotatedPointTool ||
        (tool is PointAndLineTool && tool.build == buildReflectedPoint) ||
        (tool is TwoPointTool && tool.build == buildCentralReflection) ||
        (tool is ThreePointTool && tool.build == buildTranslatedPoint);
    final macrosActive =
        tool is SquareMacroTool ||
        tool is ParallelogramMacroTool ||
        tool is TrapeziumMacroTool ||
        tool is RectangleMacroTool ||
        tool is RhombusMacroTool ||
        tool is KiteMacroTool ||
        tool is IsoscelesTrapeziumMacroTool ||
        tool is RightTrapeziumMacroTool;

    Future<Tool?> ratioPick() async {
      final build = await askRatioBuilder(context);
      return build == null
          ? null
          : TwoPointTool(newId: newObjectId, build: build);
    }

    Future<Tool?> rotatePick() async {
      final angle = await askRotationAngle(context);
      return angle == null
          ? null
          : RotatedPointTool(newId: newObjectId, angle: angle);
    }

    Future<Tool?> angleSizePick() async {
      final angle = await askAngleSize(context);
      return angle == null
          ? null
          : AngleBySizeTool(newId: newObjectId, angle: angle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolGroup(
          icon: Icons.control_point,
          tooltip: 'Points: free, derived and constrained points',
          active: pointsActive,
          items: [
            (
              'Point',
              _pick(() => PointTool(newId: newObjectId)),
              AppAction.pointTool,
            ),
            (
              'Midpoint',
              _pick(() => TwoPointTool(newId: newObjectId, build: buildMidpoint)),
              AppAction.midpointTool,
            ),
            ('Segment-ratio point…', ratioPick, AppAction.segmentRatioTool),
            (
              'Intersection of two curves',
              _pick(() => IntersectionTool(newId: newObjectId)),
              AppAction.intersectionTool,
            ),
            ('Centroid', _center(Centroid.new), AppAction.centroidTool),
            ('Orthocenter', _center(Orthocenter.new), AppAction.orthocenterTool),
            ('Incenter', _center(Incenter.new), AppAction.incenterTool),
            (
              'Circumcenter',
              _center(Circumcenter.new),
              AppAction.circumcenterTool,
            ),
          ],
        ),
        _ToolGroup(
          icon: Icons.timeline,
          tooltip: 'Lines: line, segment, ray, perpendicular, parallel, '
              'bisector',
          active: linesActive,
          items: [
            ('Line', _twoPoint(buildLine), AppAction.lineTool),
            ('Segment', _twoPoint(buildSegment), AppAction.segmentTool),
            (
              'Ray (origin, then direction)',
              _twoPoint(buildRay),
              AppAction.rayTool,
            ),
            (
              'Perpendicular line',
              _pick(
                () => PointAndLineTool(
                  newId: newObjectId,
                  build: PerpendicularLine.new,
                ),
              ),
              AppAction.perpendicularTool,
            ),
            (
              'Parallel line',
              _pick(
                () =>
                    PointAndLineTool(newId: newObjectId, build: ParallelLine.new),
              ),
              AppAction.parallelTool,
            ),
            (
              'Angle bisector (arm, vertex, arm)',
              _threePoint(buildAngleBisector),
              AppAction.angleBisectorTool,
            ),
          ],
        ),
        _ToolGroup(
          icon: Icons.circle_outlined,
          tooltip: 'Circles: center + rim, three-point, compass, arc, sector',
          active: circlesActive,
          items: [
            (
              'Circle (center, then rim)',
              _twoPoint(buildCircle),
              AppAction.circleTool,
            ),
            (
              'Circle through three points',
              _threePoint(buildThreePointCircle),
              AppAction.threePointCircleTool,
            ),
            (
              'Compass (radius points, then center)',
              _threePoint(buildCompassCircle),
              AppAction.compassTool,
            ),
            ('Arc (start, via, end)', _threePoint(buildArc), AppAction.arcTool),
            (
              'Sector (center, rim, then angle)',
              _threePoint(buildSector),
              AppAction.sectorTool,
            ),
          ],
        ),
        _ToolGroup(
          icon: Icons.square_foot,
          tooltip: 'Angles: at a vertex, or between two lines',
          active: anglesActive,
          items: [
            (
              'Angle at vertex (arm, vertex, arm)',
              _threePoint(buildVertexAngle),
              AppAction.vertexAngleTool,
            ),
            (
              'Angle between two lines',
              _pick(() => TwoLineTool(newId: newObjectId, build: buildLineAngle)),
              AppAction.lineAngleTool,
            ),
            (
              'Angle by given size (arm, then vertex)…',
              angleSizePick,
              AppAction.angleBySizeTool,
            ),
          ],
        ),
        _ToolGroup(
          icon: Icons.flip,
          tooltip: 'Transform: reflect, rotate or translate a point',
          active: transformActive,
          items: [
            (
              'Reflect about line (point and line)',
              _pick(
                () => PointAndLineTool(
                  newId: newObjectId,
                  build: buildReflectedPoint,
                ),
              ),
              AppAction.reflectAboutLineTool,
            ),
            (
              'Reflect about point (point, then center)',
              _twoPoint(buildCentralReflection),
              AppAction.reflectAboutPointTool,
            ),
            (
              'Rotate around point (point, then center)…',
              rotatePick,
              AppAction.rotateAroundPointTool,
            ),
            (
              'Translate by vector (point, then tail, tip)',
              _threePoint(buildTranslatedPoint),
              AppAction.translateByVectorTool,
            ),
          ],
        ),
        _ToolGroup(
          icon: Icons.crop_square,
          tooltip: 'Shape macros: quadrilaterals',
          active: macrosActive,
          items: [
            (
              'Square (two adjacent corners)',
              _pick(() => SquareMacroTool(newId: newObjectId)),
              AppAction.squareMacroTool,
            ),
            (
              'Rectangle (two corners, then height)',
              _pick(() => RectangleMacroTool(newId: newObjectId)),
              AppAction.rectangleMacroTool,
            ),
            (
              'Parallelogram (three corners)',
              _pick(() => ParallelogramMacroTool(newId: newObjectId)),
              AppAction.parallelogramMacroTool,
            ),
            (
              'Rhombus (two corners, then direction)',
              _pick(() => RhombusMacroTool(newId: newObjectId)),
              AppAction.rhombusMacroTool,
            ),
            (
              'Trapezium (three corners, then the 4th)',
              _pick(() => TrapeziumMacroTool(newId: newObjectId)),
              AppAction.trapeziumMacroTool,
            ),
            (
              'Isosceles trapezium (base, then a top corner)',
              _pick(() => IsoscelesTrapeziumMacroTool(newId: newObjectId)),
              AppAction.isoscelesTrapeziumMacroTool,
            ),
            (
              'Right trapezium (base, then the far corner)',
              _pick(() => RightTrapeziumMacroTool(newId: newObjectId)),
              AppAction.rightTrapeziumMacroTool,
            ),
            (
              'Kite (apex, side corner, apex)',
              _pick(() => KiteMacroTool(newId: newObjectId)),
              AppAction.kiteMacroTool,
            ),
          ],
        ),
      ],
    );
  }
}

/// Wraps a synchronous tool factory as a [ToolPick].
ToolPick _pick(Tool Function() create) => () async => create();

ToolPick _twoPoint(TwoPointBuilder build) =>
    _pick(() => TwoPointTool(newId: newObjectId, build: build));

ToolPick _threePoint(ThreePointBuilder build) =>
    _pick(() => ThreePointTool(newId: newObjectId, build: build));

ToolPick _center(TriangleCenterBuilder build) =>
    _pick(() => TriangleCenterTool(newId: newObjectId, buildCenter: build));

/// One flyout group: an icon opening a popup menu of [items]. While
/// [active], the icon is tinted and a double-click deactivates the tool.
/// Each row shows its tool's shortcut as dimmed trailing text (Phase 17
/// discoverability); the group tooltip stays keys-free.
class _ToolGroup extends ConsumerWidget {
  const _ToolGroup({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.items,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final List<ToolItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = PopupMenuButton<ToolPick>(
      tooltip: active ? '$tooltip — double-click to deselect' : tooltip,
      icon: Icon(
        icon,
        color: active ? Theme.of(context).colorScheme.primary : null,
      ),
      onSelected: (pick) async {
        final tool = await pick();
        if (tool != null) {
          ref.read(toolProvider.notifier).activate(tool);
        }
      },
      itemBuilder: (context) => [
        for (final (label, pick, action) in items)
          PopupMenuItem(
            value: pick,
            child: _ItemRow(
              label: label,
              display: action == null ? null : shortcutDisplayFor(action),
            ),
          ),
      ],
    );
    if (!active) {
      return button;
    }
    // Mounted only while active, so the double-tap recognizer's timeout
    // delays the menu-opening tap only then (an ancestor double-tap must
    // lose the gesture arena before the button's own tap can win).
    return GestureDetector(
      onDoubleTap: () => ref.read(toolProvider.notifier).deactivate(),
      child: button,
    );
  }
}

/// A flyout row: label left, dimmed shortcut text right. The fixed width
/// gives the trailing text something to align against — popup menus size
/// to intrinsic width, under which `Spacer`/`Expanded` misbehave.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.label, required this.display});

  final String label;
  final String? display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label)),
          if (display != null)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                display!,
                style: theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Asks for a segment-ratio interpolation parameter and wraps it as a
/// [TwoPointBuilder] — the shared path behind the Points flyout item and
/// the `G R` shortcut. Null when cancelled; unparseable input reads as
/// cancel too, so OK on garbage quietly does nothing rather than
/// committing a bogus ratio.
Future<TwoPointBuilder?> askRatioBuilder(BuildContext context) async {
  final ratio = await showDialog<double>(
    context: context,
    builder: (context) => const _RatioDialog(),
  );
  if (ratio == null) {
    return null;
  }
  GeoObject build(String id, GeoPoint a, GeoPoint b) =>
      SegmentRatioPoint(id: id, point1: a, point2: b, ratio: ratio);
  return build;
}

/// Asks for a rotation angle in degrees (counter-clockwise; negative =
/// clockwise) and returns it in *radians* — the shared path behind the
/// Transform flyout item and the `G T` shortcut. Null when cancelled or
/// unparseable, mirroring [askRatioBuilder].
Future<double?> askRotationAngle(BuildContext context) =>
    _askDegrees(context, 'Rotation angle');

/// The angle-by-size twin of [askRotationAngle], behind the Angles flyout
/// item and the `G D` shortcut. Same convention: degrees in, radians out,
/// negative = clockwise.
Future<double?> askAngleSize(BuildContext context) =>
    _askDegrees(context, 'Angle size');

Future<double?> _askDegrees(BuildContext context, String title) async {
  final degrees = await showDialog<double>(
    context: context,
    builder: (context) => _AngleDialog(title: title),
  );
  return degrees == null ? null : degrees * math.pi / 180;
}

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

/// Degree twin of [_RatioDialog] (same controller-lifetime reasoning).
class _AngleDialog extends StatefulWidget {
  const _AngleDialog({required this.title});

  final String title;

  @override
  State<_AngleDialog> createState() => _AngleDialogState();
}

class _AngleDialogState extends State<_AngleDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'degrees, counter-clockwise — e.g. 45 or -30',
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
