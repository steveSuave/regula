import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/object_ids.dart';
import 'application/persistence/file_io.dart';
import 'application/providers/command_stack_provider.dart';
import 'application/providers/construction_provider.dart';
import 'application/providers/preferences_provider.dart';
import 'application/providers/selection_provider.dart';
import 'application/providers/theme_provider.dart';
import 'application/providers/tool_provider.dart';
import 'application/providers/viewport_provider.dart';
import 'domain/commands/change_attributes_command.dart';
import 'domain/construction/construction.dart';
import 'domain/construction/geo_object.dart';
import 'domain/construction/object_attributes.dart';
import 'domain/construction/objects/centroid.dart';
import 'domain/construction/objects/circumcenter.dart';
import 'domain/construction/objects/incenter.dart';
import 'domain/construction/objects/orthocenter.dart';
import 'domain/construction/objects/parallel_line.dart';
import 'domain/construction/objects/perpendicular_line.dart';
import 'domain/math/vec2.dart';
import 'domain/tools/angle_by_size_tool.dart';
import 'domain/tools/equilateral_triangle_macro_tool.dart';
import 'domain/tools/intersection_tool.dart';
import 'domain/tools/isosceles_trapezium_macro_tool.dart';
import 'domain/tools/isosceles_triangle_macro_tool.dart';
import 'domain/tools/kite_macro_tool.dart';
import 'domain/tools/parallelogram_macro_tool.dart';
import 'domain/tools/point_and_line_tool.dart';
import 'domain/tools/point_tool.dart';
import 'domain/tools/random_shape_stamp_tool.dart';
import 'domain/tools/rectangle_macro_tool.dart';
import 'domain/tools/regular_polygon_macro_tool.dart';
import 'domain/tools/rhombus_macro_tool.dart';
import 'domain/tools/right_trapezium_macro_tool.dart';
import 'domain/tools/right_triangle_macro_tool.dart';
import 'domain/tools/rotated_point_tool.dart';
import 'domain/tools/square_macro_tool.dart';
import 'domain/tools/three_point_tool.dart';
import 'domain/tools/trapezium_macro_tool.dart';
import 'domain/tools/triangle_center_tool.dart';
import 'domain/tools/two_line_tool.dart';
import 'domain/tools/two_point_tool.dart';
import 'presentation/canvas/canvas_viewport.dart';
import 'presentation/canvas/fit_viewport.dart';
import 'presentation/canvas/geometry_canvas.dart';
import 'presentation/panels/attributes_inspector.dart';
import 'presentation/panels/delete_selection.dart';
import 'presentation/panels/object_tree_panel.dart';
import 'presentation/panels/toolbar.dart';
import 'presentation/shortcuts/app_shortcuts.dart';
import 'presentation/shortcuts/cheat_sheet.dart';
import 'presentation/shortcuts/shortcut_table.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loaded once here so settings providers can read stored values
  // synchronously (see preferences_provider.dart).
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const MainApp(),
    ),
  );
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'fgex',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: const EditorScreen(),
    );
  }
}

/// Canvas plus the app chrome: object tree, file menu, the
/// [GeometryToolbar] flyout groups, viewport buttons, theme toggle and
/// undo/redo. Tool builders live in `presentation/panels/toolbar.dart`;
/// the keyboard switch below reuses them so shortcuts and menu items
/// activate identical tools.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  /// Object-tree visibility is ephemeral UI state (not undoable, not
  /// persisted), so it lives here rather than in a provider. Hidden by
  /// default: the tree is a secondary surface next to the canvas.
  bool _showObjectTree = false;

  /// Whether the `?` cheat-sheet overlay is up. Same ephemeral-UI
  /// reasoning as [_showObjectTree].
  bool _showCheatSheet = false;

  /// Fit-to-viewport needs the canvas's laid-out size at tap time; the
  /// key reads it without threading sizes through providers.
  final GlobalKey _canvasKey = GlobalKey();

  /// World origin at the canvas center, 100 % — where File > New puts the
  /// view. (The app still *launches* with the origin at the top-left; the
  /// canvas has no laid-out size before the first frame. Revisit with the
  /// Phase 11 shortcuts if it grates.)
  ViewportState _centeredViewport() {
    final size = _canvasKey.currentContext?.size;
    if (size == null) {
      return const ViewportState();
    }
    return CanvasViewport.pinning(
      world: Vec2.zero,
      focal: size.center(Offset.zero),
      scale: 1,
    );
  }

  Future<void> _newConstruction() async {
    final construction = ref.read(constructionProvider).construction;
    if (!construction.isEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New construction'),
          content: const Text(
            'Discard the current construction? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) {
        return;
      }
    }
    ref.read(constructionProvider.notifier).replace(Construction());
    ref.read(viewportProvider.notifier).set(_centeredViewport());
  }

  Future<void> _openConstruction() async {
    try {
      final decoded = await openConstructionFile();
      if (decoded == null) {
        return;
      }
      ref.read(constructionProvider.notifier).replace(decoded.construction);
      ref.read(viewportProvider.notifier).set(decoded.viewport);
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Could not open file'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveConstruction() => saveConstructionFile(
    ref.read(constructionProvider).construction,
    viewport: ref.read(viewportProvider),
  );

  void _fitConstruction() {
    final size = _canvasKey.currentContext?.size;
    if (size == null) {
      return;
    }
    final fitted = fittedViewport(
      ref.read(constructionProvider).construction.objects,
      size,
    );
    if (fitted != null) {
      ref.read(viewportProvider.notifier).set(fitted);
    }
  }

  /// Zoom step per key press; scroll zoom is continuous, keys are not.
  static const double _keyZoomFactor = 1.2;

  /// Screen pixels per arrow-key viewport nudge.
  static const double _nudgeStep = 32;

  Offset? get _canvasCenter =>
      _canvasKey.currentContext?.size?.center(Offset.zero);

  void _zoomAboutCenter(double factor) {
    final center = _canvasCenter;
    if (center == null) {
      return;
    }
    final viewport = CanvasViewport(ref.read(viewportProvider));
    ref
        .read(viewportProvider.notifier)
        .set(viewport.zoomedAbout(center, factor));
  }

  /// Back to 100 % keeping the world point at the canvas center fixed —
  /// unlike Reset, which also jumps the view back to the origin.
  void _zoomTo100() {
    final center = _canvasCenter;
    if (center == null) {
      return;
    }
    final viewport = CanvasViewport(ref.read(viewportProvider));
    ref
        .read(viewportProvider.notifier)
        .set(
          CanvasViewport.pinning(
            world: viewport.screenToWorld(center),
            focal: center,
            scale: 1,
          ),
        );
  }

  /// Arrow-key nudge with content semantics: pressing → moves the drawing
  /// right, matching the Phase 14 scroll mapping where every pan gesture
  /// moves content in the gesture's direction ([delta] is the *content*
  /// shift that [CanvasViewport.pannedByScreen] expects). Flipped from
  /// camera semantics in Session 21 — the trackpad pan made the old
  /// direction read as inverted.
  void _nudgeView(Offset delta) {
    final viewport = CanvasViewport(ref.read(viewportProvider));
    ref.read(viewportProvider.notifier).set(viewport.pannedByScreen(delta));
  }

  /// Hides the selection, one command for the lot (mirrors the
  /// inspector's Visible checkbox — hiding does not deselect).
  void _hideSelection() {
    final construction = ref.read(constructionProvider).construction;
    final updates = <String, ObjectAttributes>{};
    for (final id in ref.read(selectionProvider)) {
      final object = construction.byId(id);
      if (object != null && object.attributes.visible) {
        updates[object.id] = object.attributes.copyWith(visible: false);
      }
    }
    if (updates.isNotEmpty) {
      ref
          .read(commandStackProvider.notifier)
          .execute(ChangeAttributesCommand(updates));
    }
  }

  /// Reveals every hidden object — including macro scaffolding, which is
  /// deliberately hidden; "all" means all, and the command undoes.
  void _revealAll() {
    final updates = <String, ObjectAttributes>{
      for (final object in ref.read(constructionProvider).construction.objects)
        if (!object.attributes.visible)
          object.id: object.attributes.copyWith(visible: true),
    };
    if (updates.isNotEmpty) {
      ref
          .read(commandStackProvider.notifier)
          .execute(ChangeAttributesCommand(updates));
    }
  }

  Future<void> _deleteSelectedObjects() {
    final construction = ref.read(constructionProvider).construction;
    final objects = [
      for (final id in ref.read(selectionProvider))
        if (construction.byId(id) case final GeoObject object) object,
    ];
    if (objects.isEmpty) {
      return Future.value();
    }
    return deleteSelectionWithConfirmation(context, ref, objects);
  }

  Future<void> _activateSegmentRatioTool() async {
    final build = await askRatioBuilder(context);
    if (build == null) {
      return;
    }
    ref
        .read(toolProvider.notifier)
        .activate(TwoPointTool(newId: newObjectId, build: build));
  }

  Future<void> _activateRotateTool() async {
    final angle = await askRotationAngle(context);
    if (angle == null) {
      return;
    }
    ref
        .read(toolProvider.notifier)
        .activate(RotatedPointTool(newId: newObjectId, angle: angle));
  }

  Future<void> _activateAngleBySizeTool() async {
    final angle = await askAngleSize(context);
    if (angle == null) {
      return;
    }
    ref
        .read(toolProvider.notifier)
        .activate(AngleBySizeTool(newId: newObjectId, angle: angle));
  }

  Future<void> _activateRegularPolygonTool() async {
    final sides = await askPolygonSideCount(context);
    if (sides == null) {
      return;
    }
    ref
        .read(toolProvider.notifier)
        .activate(RegularPolygonMacroTool(newId: newObjectId, sideCount: sides));
  }

  /// The one exhaustive [AppAction] switch — a binding added to the
  /// table without behaviour here fails to compile.
  void _handleShortcut(AppAction action) {
    // Any shortcut closes the cheat sheet. Esc *only* closes it — the
    // active tool survives, one Esc per surface — while a working
    // shortcut (it is a reference card, after all) also executes.
    if (_showCheatSheet && action != AppAction.toggleCheatSheet) {
      setState(() => _showCheatSheet = false);
      if (action == AppAction.returnToMoveSelect) {
        return;
      }
    }
    final tools = ref.read(toolProvider.notifier);
    switch (action) {
      case AppAction.returnToMoveSelect:
        tools.deactivate();
      case AppAction.deleteSelection:
        _deleteSelectedObjects();
      case AppAction.undo:
        if (ref.read(commandStackProvider).canUndo) {
          ref.read(commandStackProvider.notifier).undo();
        }
      case AppAction.redo:
        if (ref.read(commandStackProvider).canRedo) {
          ref.read(commandStackProvider.notifier).redo();
        }
      case AppAction.selectAll:
        ref.read(selectionProvider.notifier).selectAll();
      case AppAction.saveFile:
        _saveConstruction();
      case AppAction.openFile:
        _openConstruction();
      case AppAction.newFile:
        _newConstruction();
      case AppAction.toggleTheme:
        ref
            .read(themeModeProvider.notifier)
            .toggle(Theme.of(context).brightness);
      case AppAction.hideSelection:
        _hideSelection();
      case AppAction.revealAll:
        _revealAll();
      case AppAction.toggleCheatSheet:
        setState(() => _showCheatSheet = !_showCheatSheet);
      case AppAction.zoomIn:
        _zoomAboutCenter(_keyZoomFactor);
      case AppAction.zoomOut:
        _zoomAboutCenter(1 / _keyZoomFactor);
      case AppAction.zoomTo100:
        _zoomTo100();
      case AppAction.fitView:
        _fitConstruction();
      case AppAction.nudgeLeft:
        _nudgeView(const Offset(-_nudgeStep, 0));
      case AppAction.nudgeRight:
        _nudgeView(const Offset(_nudgeStep, 0));
      case AppAction.nudgeUp:
        _nudgeView(const Offset(0, -_nudgeStep));
      case AppAction.nudgeDown:
        _nudgeView(const Offset(0, _nudgeStep));
      case AppAction.pointTool:
        tools.activate(PointTool(newId: newObjectId));
      case AppAction.lineTool:
        tools.activate(TwoPointTool(newId: newObjectId, build: buildLine));
      case AppAction.segmentTool:
        tools.activate(TwoPointTool(newId: newObjectId, build: buildSegment));
      case AppAction.rayTool:
        tools.activate(TwoPointTool(newId: newObjectId, build: buildRay));
      case AppAction.circleTool:
        tools.activate(TwoPointTool(newId: newObjectId, build: buildCircle));
      case AppAction.midpointTool:
        tools.activate(TwoPointTool(newId: newObjectId, build: buildMidpoint));
      case AppAction.intersectionTool:
        tools.activate(IntersectionTool(newId: newObjectId));
      case AppAction.angleBisectorTool:
        tools.activate(
          ThreePointTool(newId: newObjectId, build: buildAngleBisector),
        );
      case AppAction.vertexAngleTool:
        tools.activate(
          ThreePointTool(newId: newObjectId, build: buildVertexAngle),
        );
      case AppAction.lineAngleTool:
        tools.activate(TwoLineTool(newId: newObjectId, build: buildLineAngle));
      case AppAction.perpendicularTool:
        tools.activate(
          PointAndLineTool(newId: newObjectId, build: PerpendicularLine.new),
        );
      case AppAction.parallelTool:
        tools.activate(
          PointAndLineTool(newId: newObjectId, build: ParallelLine.new),
        );
      case AppAction.compassTool:
        tools.activate(
          ThreePointTool(newId: newObjectId, build: buildCompassCircle),
        );
      case AppAction.centroidTool:
        tools.activate(
          TriangleCenterTool(newId: newObjectId, buildCenter: Centroid.new),
        );
      case AppAction.orthocenterTool:
        tools.activate(
          TriangleCenterTool(newId: newObjectId, buildCenter: Orthocenter.new),
        );
      case AppAction.incenterTool:
        tools.activate(
          TriangleCenterTool(newId: newObjectId, buildCenter: Incenter.new),
        );
      case AppAction.circumcenterTool:
        tools.activate(
          TriangleCenterTool(newId: newObjectId, buildCenter: Circumcenter.new),
        );
      case AppAction.threePointCircleTool:
        tools.activate(
          ThreePointTool(newId: newObjectId, build: buildThreePointCircle),
        );
      case AppAction.segmentRatioTool:
        _activateSegmentRatioTool();
      case AppAction.arcTool:
        tools.activate(ThreePointTool(newId: newObjectId, build: buildArc));
      case AppAction.sectorTool:
        tools.activate(ThreePointTool(newId: newObjectId, build: buildSector));
      case AppAction.reflectAboutLineTool:
        tools.activate(
          PointAndLineTool(newId: newObjectId, build: buildReflectedPoint),
        );
      case AppAction.reflectAboutPointTool:
        tools.activate(
          TwoPointTool(newId: newObjectId, build: buildCentralReflection),
        );
      case AppAction.rotateAroundPointTool:
        _activateRotateTool();
      case AppAction.translateByVectorTool:
        tools.activate(
          ThreePointTool(newId: newObjectId, build: buildTranslatedPoint),
        );
      case AppAction.angleBySizeTool:
        _activateAngleBySizeTool();
      case AppAction.squareMacroTool:
        tools.activate(SquareMacroTool(newId: newObjectId));
      case AppAction.parallelogramMacroTool:
        tools.activate(ParallelogramMacroTool(newId: newObjectId));
      case AppAction.trapeziumMacroTool:
        tools.activate(TrapeziumMacroTool(newId: newObjectId));
      case AppAction.rectangleMacroTool:
        tools.activate(RectangleMacroTool(newId: newObjectId));
      case AppAction.rhombusMacroTool:
        tools.activate(RhombusMacroTool(newId: newObjectId));
      case AppAction.kiteMacroTool:
        tools.activate(KiteMacroTool(newId: newObjectId));
      case AppAction.isoscelesTrapeziumMacroTool:
        tools.activate(IsoscelesTrapeziumMacroTool(newId: newObjectId));
      case AppAction.rightTrapeziumMacroTool:
        tools.activate(RightTrapeziumMacroTool(newId: newObjectId));
      case AppAction.equilateralTriangleMacroTool:
        tools.activate(EquilateralTriangleMacroTool(newId: newObjectId));
      case AppAction.isoscelesTriangleMacroTool:
        tools.activate(IsoscelesTriangleMacroTool(newId: newObjectId));
      case AppAction.rightTriangleMacroTool:
        tools.activate(RightTriangleMacroTool(newId: newObjectId));
      case AppAction.regularPolygonMacroTool:
        _activateRegularPolygonTool();
      case AppAction.randomTriangleStamp:
        tools.activate(
          RandomShapeStampTool(
            newId: newObjectId,
            minVertices: 3,
            maxVertices: 3,
          ),
        );
      case AppAction.randomQuadrilateralStamp:
        tools.activate(
          RandomShapeStampTool.convexQuadrilateral(newId: newObjectId),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final undoRedo = ref.watch(commandStackProvider);

    return AppShortcuts(
      onAction: _handleShortcut,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _showObjectTree ? 'Hide object tree' : 'Show object tree',
            isSelected: _showObjectTree,
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => setState(() => _showObjectTree = !_showObjectTree),
          ),
          title: const Text('fgex'),
          actions: [
            PopupMenuButton<Future<void> Function()>(
              tooltip: 'File: new, open, save',
              icon: const Icon(Icons.folder_outlined),
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _newConstruction,
                  child: const Text('New'),
                ),
                PopupMenuItem(
                  value: _openConstruction,
                  child: const Text('Open…'),
                ),
                PopupMenuItem(
                  value: _saveConstruction,
                  child: const Text('Save…'),
                ),
              ],
            ),
            const GeometryToolbar(),
            IconButton(
              tooltip: 'Fit construction to view',
              icon: const Icon(Icons.fit_screen),
              onPressed: _fitConstruction,
            ),
            IconButton(
              tooltip: 'Reset view (origin at 100 %)',
              icon: const Icon(Icons.filter_center_focus),
              onPressed: () => ref.read(viewportProvider.notifier).reset(),
            ),
            IconButton(
              tooltip: 'Keyboard shortcuts (?)',
              isSelected: _showCheatSheet,
              icon: const Icon(Icons.keyboard_outlined),
              onPressed: () =>
                  setState(() => _showCheatSheet = !_showCheatSheet),
            ),
            IconButton(
              tooltip: Theme.of(context).brightness == Brightness.dark
                  ? 'Switch to light theme'
                  : 'Switch to dark theme',
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              onPressed: () => ref
                  .read(themeModeProvider.notifier)
                  .toggle(Theme.of(context).brightness),
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
        body: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showObjectTree) const ObjectTreePanel(),
                Expanded(
                  // Clicking the canvas pulls focus back to the shortcut
                  // layer: a focused name field commits (focus-loss
                  // commit) and stops suppressing the single-letter
                  // shortcuts.
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) => AppShortcuts.refocus(context),
                    child: GeometryCanvas(key: _canvasKey),
                  ),
                ),
                const AttributesInspector(),
              ],
            ),
            if (_showCheatSheet)
              ShortcutCheatSheet(
                onDismiss: () => setState(() => _showCheatSheet = false),
              ),
          ],
        ),
      ),
    );
  }
}

