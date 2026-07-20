import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/export/png_exporter.dart';
import 'application/object_ids.dart';
import 'application/persistence/file_io.dart';
import 'application/providers/command_stack_provider.dart';
import 'application/providers/construction_provider.dart';
import 'application/providers/document_settings_provider.dart';
import 'application/providers/preferences_provider.dart';
import 'application/providers/selection_provider.dart';
import 'application/providers/theme_provider.dart';
import 'application/providers/tool_provider.dart';
import 'application/providers/viewport_provider.dart';
import 'domain/construction/construction.dart';
import 'domain/construction/geo_object.dart';
import 'domain/construction/objects/centroid.dart';
import 'domain/construction/objects/circumcenter.dart';
import 'domain/construction/objects/incenter.dart';
import 'domain/construction/objects/orthocenter.dart';
import 'domain/construction/objects/parallel_line.dart';
import 'domain/construction/objects/perpendicular_line.dart';
import 'domain/math/vec2.dart';
import 'domain/tools/angle_bisector_tool.dart';
import 'domain/tools/angle_by_size_tool.dart';
import 'domain/tools/angle_tool.dart';
import 'domain/tools/area_tool.dart';
import 'domain/tools/delete_tool.dart';
import 'domain/tools/distance_tool.dart';
import 'domain/tools/equilateral_triangle_macro_tool.dart';
import 'domain/tools/fixed_length_segment_tool.dart';
import 'domain/tools/fixed_radius_circle_tool.dart';
import 'domain/tools/intersection_tool.dart';
import 'domain/tools/isosceles_trapezium_macro_tool.dart';
import 'domain/tools/isosceles_triangle_macro_tool.dart';
import 'domain/tools/kite_macro_tool.dart';
import 'domain/tools/locus_tool.dart';
import 'domain/tools/midpoint_tool.dart';
import 'domain/tools/parallelogram_macro_tool.dart';
import 'domain/tools/point_and_line_tool.dart';
import 'domain/tools/point_tool.dart';
import 'domain/tools/polygon_tool.dart';
import 'domain/tools/random_shape_stamp_tool.dart';
import 'domain/tools/rectangle_macro_tool.dart';
import 'domain/tools/regular_polygon_macro_tool.dart';
import 'domain/tools/rhombus_macro_tool.dart';
import 'domain/tools/right_trapezium_macro_tool.dart';
import 'domain/tools/right_triangle_macro_tool.dart';
import 'domain/tools/square_macro_tool.dart';
import 'domain/tools/tangent_tool.dart';
import 'domain/tools/three_point_tool.dart';
import 'domain/tools/transform_object_tool.dart';
import 'domain/tools/trapezium_macro_tool.dart';
import 'domain/tools/triangle_center_tool.dart';
import 'domain/tools/two_point_tool.dart';
import 'domain/tools/visibility_tool.dart';
import 'presentation/canvas/canvas_viewport.dart';
import 'presentation/canvas/fit_viewport.dart';
import 'presentation/canvas/geometry_canvas.dart';
import 'presentation/canvas/name_points_hint.dart';
import 'presentation/canvas/region_pick_overlay.dart';
import 'presentation/panels/attributes_inspector.dart';
import 'presentation/panels/delete_selection.dart';
import 'presentation/panels/export_dialog.dart';
import 'presentation/panels/object_tree_panel.dart';
import 'presentation/panels/toolbar.dart';
import 'presentation/shortcuts/app_shortcuts.dart';
import 'presentation/shortcuts/cheat_sheet.dart';
import 'presentation/shortcuts/shortcut_table.dart';
import 'presentation/theme/app_theme.dart';

/// True on Android/iOS builds — the targets with OS chrome to hide and
/// notches to avoid. Web stays false even in a phone browser: the
/// browser owns its chrome.
bool get isMobileTarget =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isMobileTarget) {
    // Every canvas pixel counts on a phone: hide the OS status bar
    // (swipe from the edge peeks it back, then it re-hides).
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
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
      title: 'regula',
      // The corner DEBUG banner costs canvas pixels on a phone and says
      // nothing the user can act on.
      debugShowCheckedModeBanner: false,
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

  /// True while the export region-pick overlay owns the canvas. Ephemeral
  /// UI state like [_showCheatSheet]; while set, `_handleShortcut`
  /// swallows everything except Esc (which cancels back to the dialog).
  bool _pickingExportRegion = false;

  /// The last drag-selected export region (canvas screen coordinates) and
  /// the last-used export options — kept so the dialog reopens where the
  /// user left it, both after a region pick and across separate exports.
  Rect? _exportRegion;
  ExportOptions _exportOptions = const ExportOptions();

  /// Fit-to-viewport needs the canvas's laid-out size at tap time; the
  /// key reads it without threading sizes through providers.
  final GlobalKey _canvasKey = GlobalKey();

  /// Opens the compact-mode drawers from the overflow menu and the strip's
  /// style button — both live outside the Scaffold's own context.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    ref.read(documentSettingsProvider.notifier).reset();
  }

  Future<void> _openConstruction() async {
    try {
      final decoded = await openConstructionFile();
      if (decoded == null) {
        return;
      }
      ref.read(constructionProvider.notifier).replace(decoded.construction);
      ref.read(viewportProvider.notifier).set(decoded.viewport);
      ref.read(documentSettingsProvider.notifier).set(decoded.settings);
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
    settings: ref.read(documentSettingsProvider),
  );

  /// Export flow: options dialog → (optionally a region-pick round trip
  /// via [_onExportRegionPicked]) → off-screen render → platform save.
  /// Read-only view work throughout — no `Command`, nothing undoable.
  Future<void> _exportPng() async {
    final size = _canvasKey.currentContext?.size;
    if (size == null) {
      return;
    }
    final objects = ref.read(constructionProvider).construction.objects;
    final settings = ref.read(documentSettingsProvider);
    final outcome = await showExportDialog(
      context,
      canvasSize: size,
      canFit: visibleWorldBounds(objects) != null,
      region: _exportRegion,
      initial: _exportOptions,
      hasBackgroundLayer: settings.showAxes || settings.showGrid,
    );
    if (outcome == null || !mounted) {
      return;
    }
    _exportOptions = outcome.options;
    switch (outcome) {
      case ExportRegionPickRequested():
        setState(() => _pickingExportRegion = true);
      case ExportConfirmed(:final options):
        await _runExport(options, size);
    }
  }

  void _onExportRegionPicked(Rect region) {
    setState(() {
      _pickingExportRegion = false;
      _exportRegion = region;
      _exportOptions =
          _exportOptions.copyWith(framing: ExportFramingChoice.region);
    });
    _exportPng();
  }

  Future<void> _runExport(ExportOptions options, Size canvasSize) async {
    final construction = ref.read(constructionProvider).construction;
    final viewportState = ref.read(viewportProvider);
    final framing = switch (options.framing) {
      // Fit can be stale-selected against a construction that just went
      // empty; falling back beats surprising the user with an error.
      ExportFramingChoice.fitConstruction =>
        fitConstructionFraming(construction.objects, canvasSize) ??
            currentViewFraming(viewportState, canvasSize),
      ExportFramingChoice.currentView =>
        currentViewFraming(viewportState, canvasSize),
      ExportFramingChoice.region =>
        regionFraming(viewportState, _exportRegion!),
    };
    final theme = Theme.of(context);
    // "As shown": the export renders the document's own toggles, gated
    // by the dialog's include checkbox.
    final settings = ref.read(documentSettingsProvider);
    final canvasColors = theme.extension<CanvasColors>();
    final bytes = await exportConstructionPng(
      construction,
      viewport: framing.viewport,
      logicalSize: framing.logicalSize,
      pixelRatio: options.scale.toDouble(),
      background:
          options.transparent ? null : theme.scaffoldBackgroundColor,
      defaultColor: theme.colorScheme.primary,
      showAxes: settings.showAxes && options.includeAxesGrid,
      showGrid: settings.showGrid && options.includeAxesGrid,
      axisColor: canvasColors?.axis ?? const Color(0xFF757575),
      gridColor: canvasColors?.grid ?? const Color(0xFFE3E6EA),
    );
    await savePngBytes(bytes);
  }

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

  /// The hide/delete flyout's Delete item: activates the tap-driven
  /// [DeleteTool]. Activating with a selection deletes it first (same
  /// confirmation path as Del), then the tool stays active for
  /// tap-by-tap deleting — a cancelled dialog keeps delete mode, since
  /// that's what the press asked for. Activation goes first so a Phase
  /// 30b drag commit lands on the undo stack before the selection's
  /// delete. Leaving the mode follows the flyout precedent: double-click
  /// the group icon, Esc or `V`.
  void _activateDeleteTool() {
    ref.read(toolProvider.notifier).activate(const DeleteTool());
    _deleteSelectedObjects();
  }

  /// Hide (`H`): the current selection hides at once — one command,
  /// nothing on the stack when no selected object is visible — then the
  /// tool stays active for tap-by-tap hiding. The selection stays
  /// selected (Phase 7 precedent: the inspector/tree is the way back).
  /// Show/Hide (`Shift+H`) deliberately has no such on-activation
  /// action: toggling a mixed selection is ambiguous.
  void _activateHideTool() {
    ref.read(toolProvider.notifier).activate(VisibilityTool.hide());
    final construction = ref.read(constructionProvider).construction;
    final command = VisibilityTool.hideAll([
      for (final id in ref.read(selectionProvider))
        if (construction.byId(id) case final GeoObject object) object,
    ]);
    if (command != null) {
      ref.read(commandStackProvider.notifier).execute(command);
    }
  }

  /// Show/Hide (`Shift+H` and the hide/delete flyout): unlike Hide,
  /// deliberately no act-on-selection step — toggling a mixed selection
  /// is ambiguous.
  void _activateShowHideTool() {
    ref.read(toolProvider.notifier).activate(VisibilityTool.showHide());
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
        .activate(TransformObjectTool.rotate(newId: newObjectId, angle: angle));
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

  Future<void> _activateNamePointsTool() async {
    final tool = await askNamePointsTool(context);
    if (tool == null) {
      return;
    }
    ref.read(toolProvider.notifier).activate(tool);
  }

  Future<void> _activateFixedRadiusCircleTool() async {
    final radius = await askCircleRadius(context);
    if (radius == null) {
      return;
    }
    ref
        .read(toolProvider.notifier)
        .activate(FixedRadiusCircleTool(newId: newObjectId, radius: radius));
  }

  Future<void> _activateFixedLengthSegmentTool() async {
    final length = await askSegmentLength(context);
    if (length == null) {
      return;
    }
    ref
        .read(toolProvider.notifier)
        .activate(FixedLengthSegmentTool(newId: newObjectId, length: length));
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
    // The region-pick overlay owns the canvas: Esc cancels back to the
    // export dialog, every other shortcut is swallowed (activating a tool
    // or opening a file mid-pick would fight the overlay).
    if (_pickingExportRegion) {
      if (action == AppAction.returnToMoveSelect) {
        setState(() => _pickingExportRegion = false);
        _exportPng();
      }
      return;
    }
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
      case AppAction.exportPng:
        _exportPng();
      case AppAction.toggleTheme:
        ref
            .read(themeModeProvider.notifier)
            .toggle(Theme.of(context).brightness);
      case AppAction.hideTool:
        _activateHideTool();
      case AppAction.showHideTool:
        _activateShowHideTool();
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
      case AppAction.toggleAxes:
        ref.read(documentSettingsProvider.notifier).toggleAxes();
      case AppAction.toggleGrid:
        ref.read(documentSettingsProvider.notifier).toggleGrid();
      case AppAction.toggleSnapToGrid:
        ref.read(documentSettingsProvider.notifier).toggleSnapToGrid();
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
        tools.activate(MidpointTool(newId: newObjectId));
      case AppAction.intersectionTool:
        tools.activate(IntersectionTool(newId: newObjectId));
      case AppAction.angleBisectorTool:
        tools.activate(AngleBisectorTool(newId: newObjectId));
      case AppAction.angleTool:
        tools.activate(AngleTool(newId: newObjectId));
      case AppAction.perpendicularTool:
        tools.activate(
          PointAndLineTool(newId: newObjectId, build: PerpendicularLine.new),
        );
      case AppAction.parallelTool:
        tools.activate(
          PointAndLineTool(newId: newObjectId, build: ParallelLine.new),
        );
      case AppAction.perpendicularBisectorTool:
        tools.activate(
          TwoPointTool(newId: newObjectId, build: buildPerpendicularBisector),
        );
      case AppAction.tangentTool:
        tools.activate(TangentTool(newId: newObjectId));
      case AppAction.fixedRadiusCircleTool:
        _activateFixedRadiusCircleTool();
      case AppAction.fixedLengthSegmentTool:
        _activateFixedLengthSegmentTool();
      case AppAction.distanceTool:
        tools.activate(DistanceTool(newId: newObjectId));
      case AppAction.areaTool:
        tools.activate(AreaTool(newId: newObjectId));
      case AppAction.locusTool:
        tools.activate(LocusTool(newId: newObjectId));
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
        tools.activate(TransformObjectTool.reflectAboutLine(newId: newObjectId));
      case AppAction.reflectAboutPointTool:
        tools.activate(TransformObjectTool.reflectAboutPoint(newId: newObjectId));
      case AppAction.rotateAroundPointTool:
        _activateRotateTool();
      case AppAction.translateByVectorTool:
        tools.activate(TransformObjectTool.translate(newId: newObjectId));
      case AppAction.angleBySizeTool:
        _activateAngleBySizeTool();
      case AppAction.namePointsTool:
        _activateNamePointsTool();
      case AppAction.polygonTool:
        tools.activate(PolygonTool(newId: newObjectId));
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

  /// Slim app-bar height for phones — visibly slimmer than the 56-px
  /// Material default while still fitting the standard 48-px icon-button
  /// touch targets. Canvas pixels matter most where the screen is
  /// smallest; the row's content is identical at every height.
  static const double _phoneBarHeight = 48;

  /// The app bar's one row — tree toggle, title, then the full action
  /// cluster through undo/redo. The same chrome shows at every window
  /// width (Phase 47, user feedback on the Phase 42 compact variant):
  /// when the row outgrows the window it scrolls horizontally in its
  /// entirety instead of re-arranging into a compact layout, so every
  /// affordance keeps one home. [IntrinsicWidth] over the min-width
  /// constraint sizes the row to max(content, bar), so the [Spacer]
  /// right-aligns the action cluster while it fits and is exactly
  /// zero-width once the row scrolls.
  Widget _appBarRow({
    required bool compactPanels,
    required bool hasSelection,
    required bool hideDeleteActive,
    required UndoRedoState undoRedo,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: IntrinsicWidth(
            child: Row(
              children: [
                // Always an explicit tree button (never Material's
                // auto-hamburger). What it opens follows the panel gate:
                // drawer under [compactPanels], docked-panel toggle
                // otherwise.
                if (compactPanels)
                  IconButton(
                    tooltip: 'Show object tree',
                    icon: const Icon(Icons.account_tree_outlined),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  )
                else
                  IconButton(
                    tooltip: _showObjectTree
                        ? 'Hide object tree'
                        : 'Show object tree',
                    isSelected: _showObjectTree,
                    icon: const Icon(Icons.account_tree_outlined),
                    onPressed: () =>
                        setState(() => _showObjectTree = !_showObjectTree),
                  ),
                // Styled by the AppBar's DefaultTextStyle (titleLarge).
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('regula'),
                ),
                const Spacer(),
                if (hasSelection)
                  IconButton(
                    tooltip: 'Style & properties',
                    icon: const Icon(Icons.palette_outlined),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
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
                    PopupMenuItem(
                      value: _exportPng,
                      child: const Text('Export as PNG…'),
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
                _gridMenu(),
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
                _hideDeleteGroup(active: hideDeleteActive),
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
          ),
        ),
      ),
    );
  }

  /// Hide, Show/Hide and Delete as one flyout group, visually matching
  /// the [GeometryToolbar] groups: primary-tinted icon while one of its
  /// tools is active, rows with shortcut hints, double-click to
  /// deactivate. It lives here rather than in the toolbar because Hide
  /// and Delete act on the current selection at activation, which the
  /// toolbar's pure tool factories don't do.
  Widget _hideDeleteGroup({required bool active}) {
    const idleTooltip = 'Hide & delete: tap objects to hide, reveal or '
        'delete them';
    final button = PopupMenuButton<VoidCallback>(
      key: const ValueKey('hide-delete-group'),
      tooltip: active ? '$idleTooltip — double-click to deselect' : idleTooltip,
      icon: Icon(
        Icons.delete_outline,
        color: active ? Theme.of(context).colorScheme.primary : null,
      ),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _activateHideTool,
          child: ToolMenuRow(
            label: 'Hide objects',
            display: shortcutDisplayFor(AppAction.hideTool),
          ),
        ),
        PopupMenuItem(
          value: _activateShowHideTool,
          child: ToolMenuRow(
            label: 'Show or hide objects (hidden show dimmed)',
            display: shortcutDisplayFor(AppAction.showHideTool),
          ),
        ),
        PopupMenuItem(
          value: _activateDeleteTool,
          child: ToolMenuRow(
            label: 'Delete objects',
            display: shortcutDisplayFor(AppAction.deleteSelection),
          ),
        ),
      ],
    );
    if (!active) {
      return button;
    }
    // The toolbar's _ToolGroup reasoning: the double-tap recognizer is
    // mounted only while active, so it delays the menu-opening tap only
    // then.
    return GestureDetector(
      onDoubleTap: () => ref.read(toolProvider.notifier).deactivate(),
      child: button,
    );
  }

  /// The Phase 36 axes/grid popup: two checked items flipping the
  /// per-document `DocumentSettings` toggles — view chrome like the
  /// viewport buttons around it, not undoable, persisted per document.
  Widget _gridMenu() {
    final settings = ref.watch(documentSettingsProvider);
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Axes & grid',
      icon: const Icon(Icons.grid_4x4),
      onSelected: (action) => action(),
      // The rows show their shortcuts like the tool flyouts do (Phase 17
      // discoverability, extended here on user request) — the cheat
      // sheet must not be the only place the grid keys appear.
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          checked: settings.showAxes,
          value: () =>
              ref.read(documentSettingsProvider.notifier).toggleAxes(),
          child: ToolMenuRow(
            label: 'Show axes',
            display: shortcutDisplayFor(AppAction.toggleAxes),
          ),
        ),
        CheckedPopupMenuItem(
          checked: settings.showGrid,
          value: () =>
              ref.read(documentSettingsProvider.notifier).toggleGrid(),
          child: ToolMenuRow(
            label: 'Show grid',
            display: shortcutDisplayFor(AppAction.toggleGrid),
          ),
        ),
        CheckedPopupMenuItem(
          checked: settings.snapToGrid,
          value: () =>
              ref.read(documentSettingsProvider.notifier).toggleSnapToGrid(),
          child: ToolMenuRow(
            label: 'Snap to grid',
            display: shortcutDisplayFor(AppAction.toggleSnapToGrid),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final undoRedo = ref.watch(commandStackProvider);
    // One gate (PLAN "Unified scrollable app bar"): the Material compact
    // breakpoint decides only where the panels live (drawers vs docked).
    // The app bar itself is the same at every width — too-narrow windows
    // scroll it horizontally instead of re-arranging it.
    final screen = MediaQuery.sizeOf(context);
    final compactPanels = screen.shortestSide < 600;
    // Watched only with drawer panels: the app bar's style button
    // appears with the selection (it opens the inspector drawer, which
    // never auto-opens); a docked inspector is already visible.
    final hasSelection =
        compactPanels && ref.watch(selectionProvider).isNotEmpty;
    // Narrow select: tool taps bump the provider's revision every input,
    // and the scaffold must not rebuild per tap.
    final hideDeleteActive = ref.watch(
      toolProvider.select(
        (state) => state.tool is DeleteTool || state.tool is VisibilityTool,
      ),
    );
    final drawerWidth = math.min(
      AttributesInspector.panelWidth,
      MediaQuery.sizeOf(context).width * 0.85,
    );

    return AppShortcuts(
      onAction: _handleShortcut,
      child: Scaffold(
        key: _scaffoldKey,
        // Edge swipes belong to the canvas — a drag starting at the
        // screen edge is usually a draw, not a panel request. The drawers
        // open from the hamburger, the overflow menu and the style
        // button only.
        drawerEnableOpenDragGesture: false,
        endDrawerEnableOpenDragGesture: false,
        drawer: compactPanels
            ? Drawer(width: drawerWidth, child: const ObjectTreePanel())
            : null,
        endDrawer: compactPanels
            ? Drawer(width: drawerWidth, child: const AttributesInspector())
            : null,
        appBar: AppBar(
          // The whole bar is [_appBarRow] in the title slot; no leading
          // (a null leading with a drawer set would inject Material's
          // auto-hamburger — the row carries its own tree button).
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          // Same row everywhere, but slimmer on phones (user feedback):
          // the height rides the panel gate, not a chrome gate.
          toolbarHeight: compactPanels ? _phoneBarHeight : null,
          title: _appBarRow(
            compactPanels: compactPanels,
            hasSelection: hasSelection,
            hideDeleteActive: hideDeleteActive,
            undoRedo: undoRedo,
          ),
          // Non-empty actions suppress the end-drawer button Material
          // injects when `endDrawer` is set — the inspector drawer opens
          // from the row's style button only.
          actions: const [SizedBox.shrink()],
        ),
        body: SafeArea(
          // A no-op except on notched mobile devices, where the
          // immersive mode set in main() leaves the display cutout to
          // avoid.
          left: isMobileTarget,
          top: isMobileTarget,
          right: isMobileTarget,
          bottom: isMobileTarget,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compactPanels && _showObjectTree)
                    const ObjectTreePanel(),
                  Expanded(
                    // Clicking the canvas pulls focus back to the shortcut
                    // layer: a focused name field commits (focus-loss
                    // commit) and stops suppressing the single-letter
                    // shortcuts.
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => AppShortcuts.refocus(context),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GeometryCanvas(key: _canvasKey),
                          const NamePointsHint(),
                          // Sits on top of (and exactly over) the canvas,
                          // so its local coordinates are canvas
                          // coordinates; opaque, so the canvas can't
                          // react to the pick drag.
                          if (_pickingExportRegion)
                            RegionPickOverlay(
                              onSelected: _onExportRegionPicked,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!compactPanels) const AttributesInspector(),
                ],
              ),
              if (_showCheatSheet)
                ShortcutCheatSheet(
                  onDismiss: () => setState(() => _showCheatSheet = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

