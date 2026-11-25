import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../domain/construction/construction.dart';
import '../../domain/construction/document_kernel.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/construction/liftable.dart';
import '../../domain/construction/line_clip.dart';
import '../../domain/construction/objects/arc.dart';
import '../../domain/construction/objects/face_plane.dart';
import '../../domain/construction/objects/locus.dart';
import '../../domain/construction/objects/ray.dart';
import '../../domain/construction/objects/sector.dart';
import '../../domain/construction/objects/segment.dart';
import '../../domain/math/circle_eq.dart';
import '../../domain/math/vec2.dart';
import '../../domain/projective/conic_matrix.dart';
import '../../domain/projective/conic_shape.dart';
import '../../domain/projective/space/plane_frame.dart';
import 'canvas_viewport.dart';
import 'fit_viewport.dart';
import 'grid_layout.dart';
import 'label_layout.dart';
import 'large_radius_arc.dart';
import 'lift_handle.dart';
import 'plane_patch.dart';
import 'screen_figure.dart';
import 'sheet_canvas.dart';

/// The canvas rect minus the disc — the region that is not part of the
/// plane, as one even-odd path.
///
/// **Even-odd rather than `Path.combine(PathOperation.difference, …)`,
/// and that is a bug fix rather than a simplification (Phase 126d).** The
/// boolean difference produced the whole rect — no hole at all — on the
/// web renderer whenever the disc lay *entirely inside* the canvas, and
/// the correct annulus as soon as any part of it hung over an edge. Every
/// test stayed green because the VM harness has a different path-ops
/// implementation from CanvasKit, so the defect was only ever visible in
/// a browser: a hyperbolic document showed a uniformly washed canvas with
/// the rim floating on it, and looked correct the moment the user zoomed
/// far enough to push the boundary off screen.
///
/// The even-odd rule needs no boolean op to express the same region. A
/// point inside both the rect and the disc has crossing number two, which
/// is even, so it is not filled; a point in the rect alone has one. That
/// is exact, portable and cheaper, and it is the shape to reach for
/// whenever a fill needs a hole in it.
Path outsideDiscPath(Size size, Offset centre, double radius) => Path()
  ..fillType = PathFillType.evenOdd
  ..addRect(Offset.zero & size)
  ..addOval(Rect.fromCircle(center: centre, radius: radius));

/// Where the document's fundamental conic is on screen, or null when its
/// geometry has no real absolute to draw (Phase 126).
///
/// Only the **hyperbolic** absolute is drawable: `x² + y² − w² = 0` is the
/// unit circle, the Beltrami–Klein disc's boundary, and the region outside
/// it is not part of the hyperbolic plane at all — a figure dragged across
/// it does not merely look wrong, it goes undefined. The wash is what
/// makes that legible before it happens.
///
/// The **elliptic** absolute `x² + y² + w² = 0` has no real points, and
/// that is a fact about the geometry rather than a gap in the drawing:
/// elliptic space has no boundary and no unreachable region, the whole
/// real projective plane being the space. Drawing anything would be
/// inventing an edge that is not there. **Euclidean** draws nothing for
/// the mirror-image reason — its absolute is the line at infinity, real
/// enough but with no points in any chart.
///
/// Centre and radius come from the viewport rather than from a projection
/// of the conic, which is exact rather than approximate: the absolute is a
/// world-space circle about the origin, and a circle stays a circle under
/// everything the viewport does to it, rotation included. Its world radius
/// is the kernel's (Phase 131), which is 1 for every document written
/// before that and for every one that never asks for another.
({Offset centre, double radius})? absoluteDisc(
  DocumentKernel kernel,
  CanvasViewport viewport,
) {
  if (kernel.metric != FundamentalConic.hyperbolic) {
    return null;
  }
  final radius = viewport.worldToScreenLength(kernel.radius);
  if (!radius.isFinite || radius <= 0) {
    return null;
  }
  return (centre: viewport.worldToScreen(Vec2.zero), radius: radius);
}

/// Paints the construction in insertion order (first added = bottom).
///
/// Skips undefined and invisible objects, per the `GeoObject` contract.
/// Stroke widths and point radii come from `ObjectAttributes` and are in
/// logical pixels — they do not scale with zoom (a hairline stays a
/// hairline). A named object with `labelVisible` gets its name painted
/// beside its [labelBaseTopLeft], in the object's own color.
class GeometryPainter extends CustomPainter {
  GeometryPainter({
    required this.construction,
    required this.viewport,
    required this.revision,
    required this.defaultColor,
    required this.selectionColor,
    this.selectedIds = const {},
    this.highlightedIds = const {},
    this.highlightColor = const Color(0xFFB26A00),
    this.highlightPulse,
    this.previewMarkers = const [],
    this.previewObjectIds = const {},
    this.labelDragPreview,
    this.showHidden = false,
    this.liftHandleEnabled = false,
    this.activePlaneId,
    this.activePlane,
    this.showAxes = false,
    this.showGrid = false,
    this.axisColor = const Color(0xFF757575),
    this.gridColor = const Color(0xFFE3E6EA),
    this.absoluteColor = const Color(0xFFB26A00),
    this.absoluteOutsideColor = const Color(0x40B26A00),
  }) : super(repaint: highlightPulse);

  /// Stroke widths of the background layer (logical px) and the font size
  /// of its tick labels.
  static const double _gridStrokeWidth = 1;
  static const double _axisStrokeWidth = 1.5;
  // 12 rather than the original 10 (Phase 54): the smallest text on the
  // canvas follows the larger-defaults pass.
  static const double _tickFontSize = 12;

  /// Screen-px gap between an axis and its tick labels.
  static const double _tickLabelGap = 3;

  /// Radii (logical px) of an in-progress input marker: a filled dot
  /// inside a hollow ring, visually distinct from a plain point.
  static const double _markerDotRadius = 3;
  static const double _markerRingRadius = 7;

  /// How much wider (logical px) a selection halo is than the stroke it
  /// sits under; also the extra radius on a selected point's halo disc.
  static const double _haloExtra = 5;

  static const double _haloAlpha = 0.4;

  /// The proof-step emphasis is the selection halo's geometry at twice
  /// the width, so a highlighted object that is *also* selected shows
  /// both rings rather than one swallowing the other. DECISIONS §M-P4 says to
  /// reuse the selection styling; it does not say to be indistinguishable
  /// from a selection, which would make a proof step look like something
  /// the next tool would act on.
  static const double _highlightExtra = 11;

  /// Alpha at the pulse's peak. The trough is [_highlightPulseFloor] of
  /// it, so the emphasis never blinks out — a highlight that vanishes
  /// reads as a redraw glitch, not as attention.
  static const double _highlightAlpha = 0.55;
  static const double _highlightPulseFloor = 0.45;

  /// Opacity factor for hidden objects while [showHidden] is on.
  static const double _hiddenAlpha = 0.35;

  /// Screen-px margin the conic clip box is grown by, and the flatness
  /// (also screen px) the conic sweep is walked to. Half a pixel is under
  /// the antialiasing floor at any zoom.
  static const double _conicClipMargin = 8;
  static const double _conicFlatness = 0.5;

  /// Read live at paint time, in insertion (drawing) order.
  final Construction construction;

  final CanvasViewport viewport;

  /// The construction's revision when the painter was created — the
  /// construction mutates in place, so instance comparison alone can't
  /// drive repaints (same trick as `ConstructionState`). The instance
  /// still matters: `replace()` resets the revision, so a swapped-in
  /// construction can carry the same revision number as the old one.
  final int revision;

  /// Color for objects whose attributes carry no explicit color.
  final Color defaultColor;

  /// Ids of selected objects, drawn with a translucent halo underneath.
  final Set<String> selectedIds;

  /// Base color of the selection halo (alpha is the painter's business).
  final Color selectionColor;

  /// Ids of the objects the proof step being read is about, drawn with a
  /// wider halo *under* the selection's so both stay legible.
  final Set<String> highlightedIds;

  /// Base color of that halo.
  final Color highlightColor;

  /// Drives the emphasis's alpha between [_highlightPulseFloor] and 1.
  ///
  /// Passed to `CustomPainter`'s `repaint`, so a tick repaints without
  /// rebuilding the canvas widget — the construction, viewport and
  /// selection are all untouched by an animation frame. Null means a
  /// still highlight at full alpha, which is what a theme-less host or a
  /// test that has not pumped an animation gets.
  final ValueListenable<double>? highlightPulse;

  /// World positions of the active tool's in-progress inputs (see
  /// `ToolInputPreview`), drawn as markers on top of the construction.
  final List<Vec2> previewMarkers;

  /// Ids of existing objects the active tool has consumed as inputs
  /// (see `ToolInputPreview.previewObjectIds`), haloed exactly like a
  /// selection — the union with [selectedIds].
  final Set<String> previewObjectIds;

  /// A label mid-drag: [offset] replaces the object's stored label
  /// offset for this frame only. The canvas holds the drag as widget
  /// state and commits one `ChangeAttributesCommand` at gesture end, so
  /// the construction is never mutated per frame.
  final ({String id, Offset offset})? labelDragPreview;

  /// Renders hidden objects (and their labels) at [_hiddenAlpha] opacity
  /// instead of skipping them — the Show/Hide tool's view state, never
  /// persisted and never on in PNG export (which builds its own painter
  /// and leaves the default false).
  final bool showHidden;

  /// Whether the lift handle is offered for a single selected free point
  /// (intent 004): the space view is on, no tool is active, and the
  /// document is Euclidean. The drop line of a lifted, selected point is
  /// drawn regardless.
  final bool liftHandleEnabled;

  /// The id of the active plane (intent 004, milestone 2), or null for
  /// the base plane: its patch is outlined in the selection colour, and
  /// the tool's preview markers are positions in it.
  final String? activePlaneId;

  /// The active plane itself, when it is one the construction does not
  /// hold yet: the plane of a face tapped and not yet built in (intent
  /// 004, milestone 3). Otherwise null, and [activePlaneId] finds it.
  final GeoPlane? activePlane;

  GeoObject? get _active =>
      activePlane ?? construction.byId(activePlaneId ?? '');

  /// The plane whose sheet this painter paints, or null for the painter
  /// the canvas owns, which paints the base sheet, everything with no
  /// sheet, and then one of these per plane that has something on it.
  GeoPlane? _sheetPlane;

  /// Draws the coordinate axes / the background grid behind every object
  /// (the Phase 36 `DocumentSettings` toggles). Both default off, so
  /// existing callers — exporter included — render byte-identically.
  final bool showAxes;
  final bool showGrid;

  /// Colors for the background layer, from the theme's `CanvasColors`
  /// extension (defaults match the light palette for theme-less callers).
  final Color axisColor;
  final Color gridColor;

  /// The fundamental conic of a non-Euclidean document (Phase 126).
  final Color absoluteColor;

  /// The wash over the region outside it, alpha included (Phase 126b —
  /// it is a theme colour rather than one opacity applied to
  /// [absoluteColor], because the light and dark canvases start from
  /// opposite ends and the same alpha cannot serve both).
  final Color absoluteOutsideColor;

  /// Stroke width (logical px) of the absolute. Heavier than an axis
  /// because it is not chrome: it is the edge of the plane.
  static const double _absoluteStrokeWidth = 2;

  /// The planar frame every coordinate below is computed in: [viewport]
  /// with the camera looking straight down, and [viewport] itself when
  /// it already is. The [SheetCanvas] carries the result to the screen.
  late final CanvasViewport _flat = viewport.flat;

  /// The figure's world bounds while the base plane is inside the
  /// edge-on band, null otherwise. There the whole plane is on screen as
  /// one line, so no pull-back of the canvas bounds what is visible; the
  /// clip bounds below are widened to hold the figure instead, so that a
  /// conic or a locus on that line is not trimmed away. Set per paint.
  ({Vec2 min, Vec2 max})? _bandBox;

  /// The part of the planar frame the canvas can see: `Offset.zero &
  /// size` when the camera is not tilted.
  Rect _frame(Size size) {
    final frame = viewport.flatFrame(size);
    final band = _bandBox;
    if (band == null) {
      return frame;
    }
    return frame
        .expandToInclude(
          Rect.fromPoints(
            _flat.worldToScreen(band.min),
            _flat.worldToScreen(Vec2(band.min.x, band.max.y)),
          ),
        )
        .expandToInclude(
          Rect.fromPoints(
            _flat.worldToScreen(band.max),
            _flat.worldToScreen(Vec2(band.max.x, band.min.y)),
          ),
        );
  }

  /// The world box unbounded curves are clipped to: the canvas grown by
  /// [margin] screen px.
  ({Vec2 min, Vec2 max}) _visibleBox(Size size, double margin) {
    final box = viewport.visibleWorldBox(size, margin: margin);
    final band = _bandBox;
    if (band == null) {
      return box;
    }
    return (
      min: Vec2(
        math.min(box.min.x, band.min.x),
        math.min(box.min.y, band.min.y),
      ),
      max: Vec2(
        math.max(box.max.x, band.max.x),
        math.max(box.max.y, band.max.y),
      ),
    );
  }

  /// A screen-px [margin] in planar-frame px: the sheet map shrinks the
  /// frame's y, so the same clearance on screen needs more of it.
  double _frameMargin(double margin) =>
      viewport.isTilted ? margin / viewport.sheetShrink : margin;

  @override
  void paint(Canvas screen, Size size) {
    // Infinite lines are drawn with far-away endpoints; the clip keeps
    // that overdraw inside the canvas.
    screen.clipRect(Offset.zero & size);
    final canvas = SheetCanvas(screen, viewport);
    _bandBox = viewport.basePlanePickable
        ? null
        : visibleWorldBounds(construction.objects);

    if (showGrid || showAxes) {
      _drawBackground(canvas, size);
    }
    _drawAbsolute(canvas, size);

    _drawPlanePatches(screen, size);

    // The base sheet and everything with no sheet, in insertion order.
    _paintObjects(canvas, size, (object) => object.sheet.plane == null);
    // Then each plane's own sheet, through that plane's viewport: the
    // same per-kind code, with another sheet map (intent 004, milestone
    // 2). A plane with nothing on it costs a lookup.
    final onSheet = <GeoPlane>{
      for (final object in construction.objects) ?object.sheet.plane,
    };
    final active = _active;
    if (active is GeoPlane && previewMarkers.isNotEmpty) {
      onSheet.add(active);
    }
    for (final plane in onSheet) {
      final frame = plane.frame;
      if (frame != null) {
        _forSheet(plane, frame)._paintSheet(screen, size);
      }
    }

    _drawLift(screen);
    if (active is! GeoPlane) {
      _drawPreviewMarkers(canvas);
    }
  }

  /// This painter's settings on another sheet.
  GeometryPainter _forSheet(GeoPlane plane, PlaneFrame frame) =>
      GeometryPainter(
        construction: construction,
        viewport: PlaneViewport(viewport, frame),
        revision: revision,
        defaultColor: defaultColor,
        selectionColor: selectionColor,
        selectedIds: selectedIds,
        highlightedIds: highlightedIds,
        highlightColor: highlightColor,
        highlightPulse: highlightPulse,
        previewMarkers: previewMarkers,
        previewObjectIds: previewObjectIds,
        labelDragPreview: labelDragPreview,
        showHidden: showHidden,
        activePlaneId: activePlaneId,
        activePlane: activePlane,
      ).._sheetPlane = plane;

  /// Paints the objects on [_sheetPlane]'s sheet, and the tool's preview
  /// markers when that plane is the active one.
  void _paintSheet(Canvas screen, Size size) {
    final plane = _sheetPlane!;
    final canvas = SheetCanvas(screen, viewport);
    _bandBox = viewport.basePlanePickable
        ? null
        : visibleWorldBounds(construction.objects, sheet: Sheet.of(plane));
    _paintObjects(
      canvas,
      size,
      (object) => identical(object.sheet.plane, plane),
    );
    if (plane.id == activePlaneId) {
      _drawPreviewMarkers(canvas);
    }
  }

  void _drawPreviewMarkers(SheetCanvas canvas) {
    final dot = Paint()..color = defaultColor;
    final ring = Paint()
      ..color = defaultColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final marker in previewMarkers) {
      final center = _flat.worldToScreen(marker);
      canvas.drawDot(center, _markerDotRadius, dot);
      canvas.drawDot(center, _markerRingRadius, ring);
    }
  }

  /// Paints, in insertion order, every visible defined object [mine]
  /// claims: halo, fill, stroke and label.
  void _paintObjects(
    SheetCanvas canvas,
    Size size,
    bool Function(GeoObject) mine,
  ) {
    for (final object in construction.objects) {
      final hidden = !object.attributes.visible;
      if ((hidden && !showHidden) ||
          !object.isDefined ||
          object.isInternal ||
          !mine(object)) {
        continue;
      }
      // A hidden object drawn through [showHidden] dims everything it
      // paints — halo, fill, stroke and label — by the same factor.
      final dim = hidden ? _hiddenAlpha : 1.0;
      if (highlightedIds.contains(object.id)) {
        final pulse = highlightPulse?.value ?? 1.0;
        final alpha =
            _highlightAlpha *
            (_highlightPulseFloor + (1 - _highlightPulseFloor) * pulse) *
            dim;
        final emphasis = Paint()
          ..color = highlightColor.withValues(alpha: alpha)
          ..strokeWidth = object.attributes.strokeWidth + _highlightExtra
          ..style = PaintingStyle.stroke;
        _drawObject(
          canvas,
          size,
          object,
          emphasis,
          pointRadiusExtra: _highlightExtra,
        );
      }
      if (selectedIds.contains(object.id) ||
          previewObjectIds.contains(object.id)) {
        final halo = Paint()
          ..color = selectionColor.withValues(alpha: _haloAlpha * dim)
          ..strokeWidth = object.attributes.strokeWidth + _haloExtra
          ..style = PaintingStyle.stroke;
        _drawObject(canvas, size, object, halo, pointRadiusExtra: _haloExtra);
      }
      final baseColor = Color(
        object.attributes.colorArgb ?? defaultColor.toARGB32(),
      );
      final color = hidden
          ? baseColor.withValues(alpha: baseColor.a * dim)
          : baseColor;
      final fillAlpha = object.attributes.fillAlpha;
      if (fillAlpha != null) {
        _drawFill(
          canvas,
          size,
          object,
          Paint()
            ..color = baseColor.withValues(alpha: fillAlpha * dim)
            ..style = PaintingStyle.fill,
        );
      }
      final paint = Paint()
        ..color = color
        ..strokeWidth = object.attributes.strokeWidth
        ..style = PaintingStyle.stroke;
      _drawObject(
        canvas,
        size,
        object,
        paint,
        dashPeriod: object.attributes.dashPeriod,
      );
      final text = labelText(object);
      if (text != null) {
        _drawLabel(canvas, object, text, color);
      }
    }
  }

  /// The translucent fills of the planes (intent 004, milestone 2),
  /// before everything else and from the farthest to the nearest, so a
  /// nearer plane tints a farther one and no patch covers a stroke. The
  /// outline of each patch is the plane's stroke and is drawn with the
  /// other objects, in insertion order.
  ///
  /// The order is by the depth of the patch's centre. Two patches that
  /// cross have no right order; hidden surfaces are milestone 3.
  void _drawPlanePatches(Canvas screen, Size size) {
    final patches = <({double depth, Path path, Paint paint})>[];
    Path? activeOutline;
    for (final object in construction.objects) {
      // A face's plane is scaffolding: the face is its picture.
      if (object is! GeoPlane || !object.isDefined || object.isInternal) {
        continue;
      }
      final hidden = !object.attributes.visible;
      if (hidden && !showHidden) {
        continue;
      }
      final corners = planePatch(
        object,
        construction.objects,
        minHalfExtent: viewport.screenToWorldLength(patchMinHalfExtentPx),
      );
      if (corners == null) {
        continue;
      }
      final base = Color(
        object.attributes.colorArgb ?? defaultColor.toARGB32(),
      );
      final alpha =
          (object.attributes.fillAlpha ?? patchFillAlpha) *
          (hidden ? _hiddenAlpha : 1.0);
      final path = Path()
        ..addPolygon([
          for (final corner in corners) viewport.spaceToScreen(corner),
        ], true);
      if (object.id == activePlaneId) {
        activeOutline = path;
      }
      patches.add((
        depth: viewport.depthOf((corners[0] + corners[2]) * 0.5),
        path: path,
        paint: Paint()
          ..color = base.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      ));
    }
    final activeFace = switch (_active) {
      final FacePlane plane => plane,
      _ => null,
    };
    // The faces of the solids, with the patches and by the same rule
    // (intent 004, milestone 3). Every view ray through a convex solid
    // crosses two faces, so its silhouette is one even tint.
    for (final object in construction.objects) {
      if (object is! GeoSolid || !object.isDefined) {
        continue;
      }
      final hidden = !object.attributes.visible;
      if (hidden && !showHidden) {
        continue;
      }
      final base = Color(
        object.attributes.colorArgb ?? defaultColor.toARGB32(),
      );
      final paint = Paint()
        ..color = base.withValues(
          alpha:
              (object.attributes.fillAlpha ?? solidFaceAlpha) *
              (hidden ? _hiddenAlpha : 1.0),
        )
        ..style = PaintingStyle.fill;
      for (var i = 0; i < object.faces.length; i++) {
        final corners = object.faceVertices(i)!;
        final centre =
            corners.reduce((sum, corner) => sum + corner) /
            corners.length.toDouble();
        final path = Path()
          ..addPolygon([
            for (final corner in corners) viewport.spaceToScreen(corner),
          ], true);
        if (activeFace != null &&
            identical(activeFace.solid, object) &&
            activeFace.face == i) {
          activeOutline = path;
        }
        patches.add((
          depth: viewport.depthOf(centre),
          path: path,
          paint: paint,
        ));
      }
    }
    patches.sort((a, b) => a.depth.compareTo(b.depth));
    for (final patch in patches) {
      screen.drawPath(patch.path, patch.paint);
    }
    // The active plane says so with its outline: the place the next tap
    // lands is the one thing about a plane that cannot be left to guess.
    if (activeOutline != null) {
      screen.drawPath(
        activeOutline,
        Paint()
          ..color = selectionColor
          ..strokeWidth = _activePlaneStrokeWidth
          ..style = PaintingStyle.stroke,
      );
    }
  }

  /// The height of a lifted point, and the handle that changes it
  /// (intent 004, milestone 2).
  ///
  /// Every selected free point that is off its plane gets a dashed drop
  /// line to its foot and a ring at the foot: a parallel projection
  /// cannot show height by itself, and a point floating over a figure is
  /// unreadable without the place it floats over. The single selected
  /// free point also gets the [LiftHandle] — a stem along the plane's
  /// normal and a grip — when [liftHandleEnabled]. All of it is selection
  /// chrome, in the selection colour, drawn over the objects.
  void _drawLift(Canvas screen) {
    final direct = SheetCanvas(screen, _flat);
    final stroke = Paint()
      ..color = selectionColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final id in selectedIds) {
      final object = construction.byId(id);
      if (object is! Liftable ||
          !object.isDefined ||
          (!object.attributes.visible && !showHidden)) {
        continue;
      }
      final foot = LiftHandle.footOf(object, viewport);
      final position = object.spacePosition;
      if (foot == null || position == null) {
        continue;
      }
      _drawStraight(direct, foot, viewport.spaceToScreen(position), stroke, 8);
      screen.drawCircle(foot, _liftFootRadius, stroke);
    }
    if (!liftHandleEnabled) {
      return;
    }
    final handle = LiftHandle.forSelection(construction, selectedIds, viewport);
    if (handle == null) {
      return;
    }
    final grip = handle.grip;
    screen.drawLine(
      handle.point,
      grip - handle.axis * LiftHandle.gripRadius,
      stroke,
    );
    screen.drawCircle(
      grip,
      LiftHandle.gripRadius,
      Paint()..color = selectionColor,
    );
    // A double chevron along the axis: this moves both ways.
    final across = Offset(-handle.axis.dy, handle.axis.dx);
    final glyph = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final side in const [1.0, -1.0]) {
      final tip = grip + handle.axis * (7 * side);
      final base = grip + handle.axis * (2.5 * side);
      screen.drawLine(base + across * 4.5, tip, glyph);
      screen.drawLine(base - across * 4.5, tip, glyph);
    }
  }

  static const double _liftFootRadius = 3;
  static const double _activePlaneStrokeWidth = 2.5;

  /// The Phase 36 background layer: grid hairlines at every multiple of
  /// the adaptive [gridStep], then 1.5-px axes through the world origin
  /// with tick labels — drawn first, so every object paints over it.
  /// Grid and axes are view chrome, not objects: hit testing, selection
  /// and fit never see them.
  /// Draws the document's fundamental conic and washes the region that is
  /// not part of the plane (Phase 126). See [absoluteDisc] for which
  /// geometries have anything to draw and why the other two do not.
  void _drawAbsolute(SheetCanvas canvas, Size size) {
    final disc = absoluteDisc(construction.kernel, _flat);
    if (disc == null) {
      return;
    }
    // The wash covers the *canvas* outside the disc, so it is a screen
    // shape with the disc's sheet image cut out of it.
    canvas.screen.drawPath(
      canvas.isIdentity
          ? outsideDiscPath(size, disc.centre, disc.radius)
          : (Path()
              ..fillType = PathFillType.evenOdd
              ..addRect(Offset.zero & size)
              ..addPath(
                canvas.mapPath(
                  Path()..addOval(
                    Rect.fromCircle(center: disc.centre, radius: disc.radius),
                  ),
                ),
                Offset.zero,
              )),
      Paint()..color = absoluteOutsideColor,
    );
    canvas.drawCircle(
      disc.centre,
      disc.radius,
      Paint()
        ..color = absoluteColor
        ..strokeWidth = _absoluteStrokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawBackground(SheetCanvas canvas, Size size) {
    final step = gridStep(_flat.state.scale);
    // Grid and axes are world-space (Phase 43 decision): under view
    // rotation they rotate with the content, staying glued to the world
    // axes. The visible world region is then a rotated quad — cover its
    // axis-aligned bounding box (at rotation 0 this reduces exactly to
    // the two screen corners); the canvas clips the overhang.
    final frame = _frame(size);
    final corners = [
      _flat.screenToWorld(frame.topLeft),
      _flat.screenToWorld(frame.topRight),
      _flat.screenToWorld(frame.bottomLeft),
      _flat.screenToWorld(frame.bottomRight),
    ];
    final minX = corners.map((c) => c.x).reduce(math.min);
    final maxX = corners.map((c) => c.x).reduce(math.max);
    final minY = corners.map((c) => c.y).reduce(math.min);
    final maxY = corners.map((c) => c.y).reduce(math.max);

    if (showGrid) {
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = _gridStrokeWidth;
      for (var i = (minX / step).ceil(); i * step <= maxX; i++) {
        canvas.drawLine(
          _flat.worldToScreen(Vec2(i * step, maxY)),
          _flat.worldToScreen(Vec2(i * step, minY)),
          grid,
        );
      }
      for (var i = (minY / step).ceil(); i * step <= maxY; i++) {
        canvas.drawLine(
          _flat.worldToScreen(Vec2(minX, i * step)),
          _flat.worldToScreen(Vec2(maxX, i * step)),
          grid,
        );
      }
    }

    if (showAxes) {
      final axis = Paint()
        ..color = axisColor
        ..strokeWidth = _axisStrokeWidth;
      final xAxisVisible = minY <= 0 && 0 <= maxY;
      final yAxisVisible = minX <= 0 && 0 <= maxX;
      if (xAxisVisible) {
        canvas.drawLine(
          _flat.worldToScreen(Vec2(minX, 0)),
          _flat.worldToScreen(Vec2(maxX, 0)),
          axis,
        );
      }
      if (yAxisVisible) {
        canvas.drawLine(
          _flat.worldToScreen(Vec2(0, maxY)),
          _flat.worldToScreen(Vec2(0, minY)),
          axis,
        );
      }
      _drawTickLabels(
        canvas,
        size,
        step,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        xAxisVisible: xAxisVisible,
        yAxisVisible: yAxisVisible,
      );
    }
  }

  /// Tick labels at every grid multiple along the visible axes: x labels
  /// below their tick, y labels left of theirs, and a single `0` in the
  /// origin's lower-left quadrant instead of one per axis. Labels ride
  /// their axis — an off-screen axis shows none — and stay screen-upright
  /// at any view rotation (only the tick anchors transform).
  void _drawTickLabels(
    SheetCanvas canvas,
    Size size,
    double step, {
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required bool xAxisVisible,
    required bool yAxisVisible,
  }) {
    void paintLabel(String text, Offset Function(Size textSize) place) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: axisColor, fontSize: _tickFontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas.screen, place(textPainter.size));
      textPainter.dispose();
    }

    if (xAxisVisible) {
      for (var i = (minX / step).ceil(); i * step <= maxX; i++) {
        if (i == 0) {
          continue;
        }
        final tick = viewport.worldToScreen(Vec2(i * step, 0));
        paintLabel(
          formatTick(i * step),
          (textSize) =>
              Offset(tick.dx - textSize.width / 2, tick.dy + _tickLabelGap),
        );
      }
    }
    if (yAxisVisible) {
      for (var i = (minY / step).ceil(); i * step <= maxY; i++) {
        if (i == 0) {
          continue;
        }
        final tick = viewport.worldToScreen(Vec2(0, i * step));
        paintLabel(
          formatTick(i * step),
          (textSize) => Offset(
            tick.dx - textSize.width - _tickLabelGap,
            tick.dy - textSize.height / 2,
          ),
        );
      }
    }
    if (xAxisVisible && yAxisVisible) {
      final origin = viewport.worldToScreen(Vec2.zero);
      paintLabel(
        '0',
        (textSize) => Offset(
          origin.dx - textSize.width - _tickLabelGap,
          origin.dy + _tickLabelGap,
        ),
      );
    }
  }

  /// Draws one object with [paint] — both the normal pass and, with a
  /// wider translucent paint plus [pointRadiusExtra], the selection halo.
  ///
  /// [dashPeriod] > 0 draws stroked kinds dashed; the halo pass leaves it
  /// at 0 (a dashed halo under a dashed stroke is unreadable — the halo
  /// is selection UI, not object style). Points fill regardless, and
  /// angle markers stay solid for the wedge's readability.
  void _drawObject(
    SheetCanvas canvas,
    Size size,
    GeoObject object,
    Paint paint, {
    double pointRadiusExtra = 0,
    double dashPeriod = 0,
  }) {
    if (drawnInSpace(object)) {
      _drawInSpace(
        canvas,
        size,
        object,
        paint,
        pointRadiusExtra: pointRadiusExtra,
        dashPeriod: dashPeriod,
      );
      return;
    }
    switch (object) {
      case GeoPoint():
        canvas.drawDot(
          _flat.worldToScreen(object.position!),
          object.attributes.pointSize + pointRadiusExtra,
          paint..style = PaintingStyle.fill,
        );
      case Segment():
        final start = _flat.worldToScreen(object.start!);
        final end = _flat.worldToScreen(object.end!);
        _drawStraight(canvas, start, end, paint, dashPeriod);
        _drawTickMarks(canvas, start, end, object.attributes.tickMarks, paint);
      case Ray():
        final span = _clipSpan(object);
        if (span != null) {
          _drawStraight(
            canvas,
            _flat.worldToScreen(span.start),
            _flat.worldToScreen(span.end),
            paint,
            dashPeriod,
          );
        } else {
          _drawRay(canvas, size, object, paint, dashPeriod);
        }
      case GeoLine():
        final span = _clipSpan(object);
        if (span != null) {
          _drawStraight(
            canvas,
            _flat.worldToScreen(span.start),
            _flat.worldToScreen(span.end),
            paint,
            dashPeriod,
          );
        } else {
          _drawInfiniteLine(canvas, size, object, paint, dashPeriod);
        }
      case Arc():
        _drawCarrierBranch(
          canvas,
          size,
          object.circle!,
          object.startAngle!,
          object.sweep!,
          paint,
          dashPeriod: dashPeriod,
        );
      case Sector():
        _drawCarrierBranch(
          canvas,
          size,
          object.circle!,
          object.startAngle!,
          object.sweep!,
          paint,
          closeToCenter: true,
          dashPeriod: dashPeriod,
        );
      case GeoCircle():
        final circle = object.circle;
        if (circle == null) {
          // A conic-valued kind that does not project to a centre and
          // radius — an ellipse, parabola, hyperbola or line pair.
          // Circles keep the arm below untouched, so their goldens do
          // not move.
          _drawConic(canvas, size, object.conic!, paint, dashPeriod);
          break;
        }
        final center = _flat.worldToScreen(circle.center);
        final radius = _flat.worldToScreenLength(circle.radius);
        if (radius > largeRadiusThreshold) {
          _drawLargeCircleRim(canvas, size, center, radius, paint, dashPeriod);
        } else if (dashPeriod > 0) {
          final rim = Path()
            ..addOval(Rect.fromCircle(center: center, radius: radius));
          canvas.drawPath(rim, paint, dashPeriod: dashPeriod);
        } else {
          canvas.drawCircle(center, radius, paint);
        }
      case GeoAngle():
        _drawAngleMarker(canvas, object, paint);
      case GeoPolygon():
        final path = _polygonPath(object);
        canvas.drawPath(path, paint, dashPeriod: dashPeriod);
      case GeoMeasurement() || GeoText():
        // Measurements and texts are pure text, painted by the label pass
        // — always with a value part (see labelText), so they never go
        // unpainted.
        break;
      case GeoLocus():
        _drawLocus(canvas, size, object, paint, dashPeriod);
      case GeoPlane() || GeoSolid():
        // Never on a sheet: [drawnInSpace] sent it to [_drawInSpace].
        break;
    }
  }

  /// Draws an object that has no value in its sheet — a lifted point, a
  /// segment to one — from its space value (intent 004, milestone 2).
  ///
  /// The geometry is the object's [screenInkOf], the same screen ink the
  /// space view's hit test measures against, so what is drawn is what is
  /// picked. It is already in screen coordinates, so it goes to the real
  /// canvas through an identity sheet: strokes, dashes and dots keep
  /// their screen size, as everywhere.
  void _drawInSpace(
    SheetCanvas canvas,
    Size size,
    GeoObject object,
    Paint paint, {
    required double pointRadiusExtra,
    required double dashPeriod,
  }) {
    // A solid strokes nothing of its own: its edges are segments beside
    // it. Only the selection halo and the highlight trace them, so that
    // a selected solid shows which one it is.
    if (object is GeoSolid && pointRadiusExtra == 0) {
      return;
    }
    final direct = SheetCanvas(canvas.screen, _flat);
    final ink = screenInkOf(construction.objects, viewport, size, object);
    final dot = ink.dot;
    if (dot != null) {
      direct.drawDot(
        dot,
        object.attributes.pointSize + pointRadiusExtra,
        paint..style = PaintingStyle.fill,
      );
    }
    for (final (from, to) in ink.segments) {
      _drawStraight(direct, from, to, paint, dashPeriod);
      if (object is Segment) {
        _drawTickMarks(direct, from, to, object.attributes.tickMarks, paint);
      }
    }
  }

  /// The interior of a polygon over points of space (intent 004,
  /// milestone 3): the screen polygon of its vertices, from the same ink
  /// the hit test reads.
  void _fillInSpace(
    SheetCanvas canvas,
    Size size,
    GeoObject object,
    Paint fill,
  ) {
    final region = screenInkOf(
      construction.objects,
      viewport,
      size,
      object,
    ).fill;
    if (region == null) {
      return;
    }
    SheetCanvas(
      canvas.screen,
      _flat,
    ).drawPath(Path()..addPolygon(region, true), fill);
  }

  /// A locus paints one polyline per non-null sample run — gaps where
  /// the traced point was undefined split the stroke, and a length-1 run
  /// draws no ink (a stroke needs two ends). A gapless full-circle-host
  /// locus closes into a loop: its samples cover one full turn with no
  /// duplicated endpoint, so the closing edge is the painter's to add.
  /// Arc/Sector hosts sweep only their angular extent — an open stroke
  /// whose samples already include both endpoints.
  ///
  /// **The polyline is clipped to the visible world box** (Phase 136),
  /// for the reason [_drawConic] gives twenty lines below: a locus arm
  /// can run off to infinity and there is no "far enough" to over-extend
  /// to. A line-host locus sweeps its whole carrier, so a diverging arm
  /// reaches astronomically far out — `no-locus.rgl` carries a sample at
  /// **1e9**, which at its own zoom is a *screen* coordinate of 2.7e10 —
  /// and every one of those went into the same `Path` as the visible
  /// curve. `GeoLocus.coreSamples` exists because the viewport fitter
  /// and the label anchor already could not use the raw samples; the
  /// painter was the last reader still handing them to the rasterizer
  /// whole.
  ///
  /// Clipping is exact and by segment, so a run that leaves the box and
  /// comes back is two strokes rather than one across the middle. A
  /// segment nothing trimmed keeps its endpoints *bit-identical* (the
  /// parameters are compared against 0 and 1 rather than recomputed), so
  /// a figure that fits on screen paints exactly what it painted before
  /// and the goldens do not move.
  void _drawLocus(
    SheetCanvas canvas,
    Size size,
    GeoLocus object,
    Paint paint,
    double dashPeriod,
  ) {
    final samples = object.samples!;
    final box = _visibleBox(size, _conicClipMargin);
    final runs = <Path>[];
    Path? run;
    Vec2? runEnd;
    var trimmed = false;
    var hasGap = false;
    void endRun() {
      if (run != null) {
        runs.add(run!);
      }
      run = null;
      runEnd = null;
    }

    Vec2? previous;
    for (final sample in samples) {
      if (sample == null) {
        endRun();
        hasGap = true;
        previous = null;
        continue;
      }
      if (previous == null) {
        previous = sample;
        continue;
      }
      final from = previous;
      previous = sample;
      final piece = _clipSegmentToBox(from, sample, box.min, box.max);
      if (piece == null) {
        // Wholly outside: the stroke resumes where the curve comes back.
        endRun();
        trimmed = true;
        continue;
      }
      final (start, end) = piece;
      if (start != from || end != sample) {
        trimmed = true;
      }
      if (run == null || runEnd != start) {
        endRun();
        final from = _flat.worldToScreen(start);
        run = Path()..moveTo(from.dx, from.dy);
      }
      final to = _flat.worldToScreen(end);
      run!.lineTo(to.dx, to.dy);
      runEnd = end;
    }
    endRun();
    final host = object is Locus ? object.driver.curve : null;
    // Only an untrimmed, gapless sweep is a closed loop; a clipped one
    // has ends because the canvas gave it ends, and joining them would
    // draw a chord across the figure.
    if (!hasGap &&
        !trimmed &&
        runs.length == 1 &&
        host is GeoCircle &&
        host.angularExtent == null) {
      runs.single.close();
    }
    for (final path in runs) {
      canvas.drawPath(path, paint, dashPeriod: dashPeriod);
    }
  }

  /// The part of the segment [a]→[b] inside the box [min]..[max], or null
  /// when none of it is (Liang–Barsky).
  ///
  /// An endpoint the box does not cut is returned **as itself**, not
  /// recomputed from its parameter, so an unclipped segment survives bit
  /// for bit. A non-finite endpoint is refused rather than clamped: it
  /// has no position to clip toward, and it is exactly what must never
  /// reach a `Path`.
  static (Vec2, Vec2)? _clipSegmentToBox(Vec2 a, Vec2 b, Vec2 min, Vec2 max) {
    if (!a.x.isFinite || !a.y.isFinite || !b.x.isFinite || !b.y.isFinite) {
      return null;
    }
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    var t0 = 0.0;
    var t1 = 1.0;
    for (final (p, q) in [
      (-dx, a.x - min.x),
      (dx, max.x - a.x),
      (-dy, a.y - min.y),
      (dy, max.y - a.y),
    ]) {
      if (p == 0) {
        // Parallel to this edge: in or out for the whole segment.
        if (q < 0) return null;
        continue;
      }
      final r = q / p;
      if (p < 0) {
        if (r > t1) return null;
        if (r > t0) t0 = r;
      } else {
        if (r < t0) return null;
        if (r < t1) t1 = r;
      }
    }
    return (
      t0 == 0 ? a : Vec2(a.x + t0 * dx, a.y + t0 * dy),
      t1 == 1 ? b : Vec2(a.x + t1 * dx, a.y + t1 * dy),
    );
  }

  /// Paints a conic with no centre-and-radius form — an ellipse,
  /// parabola, hyperbola or degenerate line pair — as one stroke per
  /// visible arc.
  ///
  /// Unlike an infinite line, a conic cannot be drawn by over-extending
  /// past the canvas: a hyperbola runs off in two directions and a
  /// parabola in one, so there is no "far enough".
  /// [ConicShape.polylines] does the clipping in world space instead,
  /// exactly, and returns only what the box can see. The box is grown by
  /// [_conicClipMargin] so an arc leaves the canvas *past* the edge
  /// rather than exactly on it — the canvas' own clip trims the
  /// overshoot, while a join sitting on the boundary would show its
  /// mitre.
  void _drawConic(
    SheetCanvas canvas,
    Size size,
    ConicMatrix conic,
    Paint paint,
    double dashPeriod,
  ) {
    final box = _visibleBox(size, _conicClipMargin);
    final strokes = ConicShape.of(conic).polylines(
      min: box.min,
      max: box.max,
      flatness: _flat.screenToWorldLength(_conicFlatness),
    );
    for (final stroke in strokes) {
      if (stroke.points.length < 2) {
        continue;
      }
      final first = _flat.worldToScreen(stroke.points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in stroke.points.skip(1)) {
        final screen = _flat.worldToScreen(point);
        path.lineTo(screen.dx, screen.dy);
      }
      if (stroke.closed) {
        path.close();
      }
      canvas.drawPath(path, paint, dashPeriod: dashPeriod);
    }
  }

  /// The closed screen-space outline over a polygon's vertex loop —
  /// shared by the stroke, fill and halo passes.
  Path _polygonPath(GeoPolygon object) {
    final vertices = object.polygonVertices!;
    final first = _flat.worldToScreen(vertices.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final vertex in vertices.skip(1)) {
      final screen = _flat.worldToScreen(vertex);
      path.lineTo(screen.dx, screen.dy);
    }
    return path..close();
  }

  /// The world endpoints of a clipped line/ray's drawn stretch, or null
  /// for the full carrier. The `lineClip == 0` guard skips the helper's
  /// whole-construction scan for the common unclipped case.
  ({Vec2 start, Vec2 end})? _clipSpan(GeoLine object) =>
      object.attributes.lineClip == 0
      ? null
      : lineClipSpan(construction.objects, object);

  /// Equal-length tick marks (congruence notation): [count] short
  /// strokes perpendicular to the [from]→[to] stretch, centered as a
  /// group on its midpoint. Screen-space geometry in logical pixels, so
  /// zoom changes neither tick length nor spacing. Always solid — ticks
  /// are notation, not object style — and painted with the object's
  /// [paint], so the selection-halo pass widens them like the stroke.
  /// A degenerate (coincident-endpoint) stretch has no perpendicular
  /// and draws none.
  void _drawTickMarks(
    SheetCanvas canvas,
    Offset from,
    Offset to,
    int count,
    Paint paint,
  ) {
    if (count <= 0) {
      return;
    }
    final along = to - from;
    final length = along.distance;
    if (length < 1e-9) {
      return;
    }
    const halfTick = 5.0;
    const spacing = 5.0;
    final unit = along / length;
    final normal = Offset(-unit.dy, unit.dx) * halfTick;
    final midpoint = (from + to) / 2;
    for (var i = 0; i < count; i++) {
      final center = midpoint + unit * ((i - (count - 1) / 2) * spacing);
      canvas.drawLine(center - normal, center + normal, paint);
    }
  }

  /// One straight stroke — solid via `drawLine`, or rebuilt as a dashed
  /// path when [dashPeriod] > 0.
  void _drawStraight(
    SheetCanvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double dashPeriod,
  ) {
    if (dashPeriod > 0) {
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
      canvas.drawPath(path, paint, dashPeriod: dashPeriod);
    } else {
      canvas.drawLine(from, to, paint);
    }
  }

  /// Paints the object's [labelText] at its [labelBaseTopLeft], shifted
  /// by the stored label offset (or the in-progress [labelDragPreview]).
  /// Like stroke widths, the font size and offset are in logical pixels
  /// and do not scale with zoom.
  void _drawLabel(
    SheetCanvas canvas,
    GeoObject object,
    String text,
    Color color,
  ) {
    final preview = labelDragPreview;
    final offset = preview != null && preview.id == object.id
        ? preview.offset
        : Offset(object.attributes.labelDx, object.attributes.labelDy);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: object.attributes.labelFontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas.screen,
      labelBaseTopLeft(object, viewport, textPainter.size) + offset,
    );
    textPainter.dispose();
  }

  /// Draws a ray from its start extending far past the canvas on one side
  /// (the clip in [paint] trims it). Direction comes from the parent
  /// points, not the carrier — the carrier normalizes it away.
  void _drawRay(
    SheetCanvas canvas,
    Size size,
    Ray object,
    Paint paint,
    double dashPeriod,
  ) {
    final start = _flat.worldToScreen(object.start!);
    final along = _flat.worldToScreen(object.throughPosition!) - start;
    final direction = along / along.distance;
    final frame = _frame(size);
    final reach = (start - frame.topLeft).distance + frame.width + frame.height;
    _drawStraight(canvas, start, start + direction * reach, paint, dashPeriod);
  }

  /// Draws the branch of a circle carrier given by a start angle and a
  /// signed sweep — an arc, or with [closeToCenter] a sector's pie wedge
  /// (the two radii close the outline). World angles are counter-clockwise
  /// with y up; `worldToScreenAngle` folds in the view rotation and the
  /// y-flip. Sweeps only negate — the rotation term cancels in the
  /// difference.
  void _drawCarrierBranch(
    SheetCanvas canvas,
    Size size,
    CircleEq circle,
    double startAngle,
    double sweep,
    Paint paint, {
    bool closeToCenter = false,
    double dashPeriod = 0,
  }) {
    final center = _flat.worldToScreen(circle.center);
    final radius = _flat.worldToScreenLength(circle.radius);
    if (radius > largeRadiusThreshold) {
      _drawLargeCarrierBranch(
        canvas,
        size,
        center,
        radius,
        startAngle,
        sweep,
        paint,
        closeToCenter: closeToCenter,
        dashPeriod: dashPeriod,
      );
      return;
    }
    final rect = Rect.fromCircle(center: center, radius: radius);
    final screenStart = _flat.worldToScreenAngle(startAngle);
    if (dashPeriod > 0) {
      // The same screen-angle mapping as the solid branch below; with
      // [closeToCenter] the path walks center → arc start → arc → back,
      // so the radii dash too.
      final path = Path();
      if (closeToCenter) {
        path.moveTo(center.dx, center.dy);
      }
      path.arcTo(rect, screenStart, -sweep, !closeToCenter);
      if (closeToCenter) {
        path.close();
      }
      canvas.drawPath(path, paint, dashPeriod: dashPeriod);
    } else {
      canvas.drawArc(rect, screenStart, -sweep, closeToCenter, paint);
    }
  }

  /// The rim of a screen-space circle too large for `drawCircle` (see
  /// [largeRadiusThreshold]): only the arc that can reach the canvas,
  /// sampled into a polyline so every vertex stays near the _flat.
  void _drawLargeCircleRim(
    SheetCanvas canvas,
    Size size,
    Offset center,
    double radius,
    Paint paint,
    double dashPeriod,
  ) {
    final window = visibleAngularWindowIn(
      center: center,
      radius: radius,
      frame: _frame(size),
      margin: _frameMargin(paint.strokeWidth + 1),
    );
    if (window == null) {
      return;
    }
    final path = Path();
    if (window.halfWidth >= math.pi - 1e-9) {
      addSampledArc(path, center, radius, 0, 2 * math.pi);
      path.close();
    } else {
      addSampledArc(
        path,
        center,
        radius,
        window.center - window.halfWidth,
        window.center + window.halfWidth,
      );
    }
    canvas.drawPath(path, paint, dashPeriod: dashPeriod);
  }

  /// [_drawCarrierBranch]'s fallback past [largeRadiusThreshold]: the
  /// arc's stretches inside the visible window as sampled polylines,
  /// plus — for a sector — the two straight radii, whose far endpoints
  /// rasterize fine (same contract as infinite lines). The sector's
  /// outline becomes disjoint contours here, so its dash phase differs
  /// from the small-radius closed walk; invisible at these sizes.
  void _drawLargeCarrierBranch(
    SheetCanvas canvas,
    Size size,
    Offset center,
    double radius,
    double startAngle,
    double sweep,
    Paint paint, {
    required bool closeToCenter,
    required double dashPeriod,
  }) {
    final window = visibleAngularWindowIn(
      center: center,
      radius: radius,
      frame: _frame(size),
      margin: _frameMargin(paint.strokeWidth + 1),
    );
    final screenStart = _flat.worldToScreenAngle(startAngle);
    final screenSweep = -sweep;
    final path = Path();
    if (window != null) {
      for (final piece in arcWindowOverlap(
        start: screenStart,
        sweep: screenSweep,
        window: window,
      )) {
        addSampledArc(path, center, radius, piece.start, piece.end);
      }
    }
    if (closeToCenter) {
      for (final angle in [screenStart, screenStart + screenSweep]) {
        final rim = center + Offset(math.cos(angle), math.sin(angle)) * radius;
        path
          ..moveTo(center.dx, center.dy)
          ..lineTo(rim.dx, rim.dy);
      }
    }
    canvas.drawPath(path, paint, dashPeriod: dashPeriod);
  }

  /// Fills the interior of a fillable kind — a sector's pie wedge, an
  /// angle marker's wedge/square, a polygon's region, or a full circle's
  /// disc — with [fill], drawn under the stroke pass. Other kinds have no
  /// filled form and are skipped; an arc's fill shape is ambiguous
  /// (wedge? circular segment?), so arcs deliberately don't fill.
  void _drawFill(SheetCanvas canvas, Size size, GeoObject object, Paint fill) {
    if (object is GeoPolygon && drawnInSpace(object)) {
      _fillInSpace(canvas, size, object, fill);
      return;
    }
    switch (object) {
      case Sector():
        final circle = object.circle!;
        final center = _flat.worldToScreen(circle.center);
        final radius = _flat.worldToScreenLength(circle.radius);
        if (radius > largeRadiusThreshold) {
          canvas.drawPath(
            _largeSectorFillPath(
              size,
              center,
              radius,
              _flat.worldToScreenAngle(object.startAngle!),
              -object.sweep!,
            ),
            fill,
          );
        } else {
          final rect = Rect.fromCircle(center: center, radius: radius);
          canvas.drawArc(
            rect,
            _flat.worldToScreenAngle(object.startAngle!),
            -object.sweep!,
            true,
            fill,
          );
        }
      case Arc():
        break;
      case GeoCircle():
        final circle = object.circle;
        if (circle == null) {
          // A conic with no centre and radius has no filled form to draw,
          // for the same reason an arc has none — only more so: a
          // hyperbola bounds nothing, a parabola's interior is unbounded,
          // and a clipped ellipse's would have to be closed along the
          // viewport edges. It is also the stance the hit-tester already
          // takes (Phase 119: a conic is a curve, not a region), and the
          // inspector withholds the fill row to match.
          break;
        }
        final center = _flat.worldToScreen(circle.center);
        final radius = _flat.worldToScreenLength(circle.radius);
        if (radius > largeRadiusThreshold) {
          _drawLargeCircleFill(canvas, size, center, radius, fill);
        } else {
          canvas.drawCircle(center, radius, fill);
        }
      case GeoAngle():
        _drawAngleMarker(canvas, object, fill);
      case GeoPolygon():
        canvas.drawPath(_polygonPath(object), fill);
      default:
        break;
    }
  }

  /// Fills the visible part of a disc too large for `drawCircle`: the
  /// whole canvas when the viewport sits inside the disc, nothing when
  /// it sits outside, otherwise the pie slice over the visible window —
  /// within the canvas clip that is exactly the disc's visible region
  /// (every canvas point of the disc lies inside the tangent cone the
  /// window comes from).
  void _drawLargeCircleFill(
    SheetCanvas canvas,
    Size size,
    Offset center,
    double radius,
    Paint fill,
  ) {
    final window = visibleAngularWindowIn(
      center: center,
      radius: radius,
      frame: _frame(size),
      margin: _frameMargin(1),
    );
    if (window == null) {
      final frame = _frame(size);
      final dist = (frame.center - center).distance;
      if (radius > dist) {
        canvas.drawRect(frame, fill);
      }
      return;
    }
    final path = Path();
    if (window.halfWidth >= math.pi - 1e-9) {
      addSampledArc(path, center, radius, 0, 2 * math.pi);
    } else {
      addSampledArc(
        path,
        center,
        radius,
        window.center - window.halfWidth,
        window.center + window.halfWidth,
      );
      path.lineTo(center.dx, center.dy);
    }
    path.close();
    canvas.drawPath(path, fill);
  }

  /// A huge sector's pie wedge as a fillable polygon: center → rim walk
  /// → close, with the rim sampled densely only inside the visible
  /// window and bridged by straight chords elsewhere. Chords stay inside
  /// the disc and every on-screen wedge point has its rim angle inside
  /// the window, so within the canvas clip the polygon fills the same
  /// pixels as the true wedge.
  Path _largeSectorFillPath(
    Size size,
    Offset center,
    double radius,
    double screenStart,
    double screenSweep,
  ) {
    final a = screenSweep >= 0 ? screenStart : screenStart + screenSweep;
    final b = a + screenSweep.abs();
    final window = visibleAngularWindowIn(
      center: center,
      radius: radius,
      frame: _frame(size),
      margin: _frameMargin(1),
    );
    Offset rim(double angle) =>
        center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final path = Path()..moveTo(center.dx, center.dy);
    final start = rim(a);
    path.lineTo(start.dx, start.dy);
    if (window != null) {
      for (final piece in arcWindowOverlap(
        start: a,
        sweep: b - a,
        window: window,
      )) {
        addSampledArc(
          path,
          center,
          radius,
          piece.start,
          piece.end,
          startWithMove: false,
        );
      }
    }
    final end = rim(b);
    path.lineTo(end.dx, end.dy);
    path.close();
    return path;
  }

  /// Draws an angle as a small wedge at its vertex, opening from the
  /// start direction through the sweep (angles negate on screen, as in
  /// [_drawCarrierBranch]). The radius comes from
  /// `attributes.angleMarkerRadius` and is fixed in screen space. A sweep
  /// of exactly π/2 — right angles from perpendicular constructions are
  /// fp-exact — draws the conventional square instead of the arc.
  ///
  /// [paint]'s style decides outline vs interior: the stroke pass and the
  /// fill pass share this geometry.
  void _drawAngleMarker(SheetCanvas canvas, GeoAngle object, Paint paint) {
    final angle = object.angle!;
    if ((angle.sweep - math.pi / 2).abs() <= defaultEpsilon) {
      canvas.drawPath(_rightAngleSquarePath(object), paint);
      return;
    }
    final rect = Rect.fromCircle(
      center: _flat.worldToScreen(angle.vertex),
      radius: object.attributes.angleMarkerRadius,
    );
    canvas.drawArc(
      rect,
      _flat.worldToScreenAngle(angle.startDirection.angle),
      -angle.sweep,
      true,
      paint,
    );
  }

  /// The right-angle marker: a closed square with corners at the vertex,
  /// at 0.7 × the marker radius along each arm, and at their vector sum.
  Path _rightAngleSquarePath(GeoAngle object) {
    final angle = object.angle!;
    final vertex = _flat.worldToScreen(angle.vertex);
    final side = 0.7 * object.attributes.angleMarkerRadius;
    final d1 = angle.startDirection;
    final d2 = d1.rotated(angle.sweep);
    // World directions rotate with the view, then the screen flips y.
    Offset corner(Vec2 d) => vertex + _flat.worldToScreenDirection(d) * side;
    final c1 = corner(d1);
    final c12 = corner(d1 + d2);
    final c2 = corner(d2);
    return Path()
      ..moveTo(vertex.dx, vertex.dy)
      ..lineTo(c1.dx, c1.dy)
      ..lineTo(c12.dx, c12.dy)
      ..lineTo(c2.dx, c2.dy)
      ..close();
  }

  /// Draws the visible stretch of an infinite line by extending far past
  /// the canvas on both sides (the clip in [paint] trims it).
  void _drawInfiniteLine(
    SheetCanvas canvas,
    Size size,
    GeoLine object,
    Paint paint,
    double dashPeriod,
  ) {
    final line = object.line!;
    final anchor = _flat.worldToScreen(line.pointOnLine);
    // Screen-space direction; y-flip is handled by the transform.
    final along =
        _flat.worldToScreen(line.pointOnLine + line.direction) - anchor;
    final direction = along / along.distance;
    // Long enough to cross the whole canvas from wherever the anchor sits
    // (the anchor is the line's closest point to the *world* origin and
    // can be far off-screen when panned/zoomed away).
    final frame = _frame(size);
    final reach =
        (anchor - frame.topLeft).distance + frame.width + frame.height;
    _drawStraight(
      canvas,
      anchor - direction * reach,
      anchor + direction * reach,
      paint,
      dashPeriod,
    );
  }

  @override
  bool shouldRepaint(GeometryPainter oldDelegate) =>
      !identical(oldDelegate.construction, construction) ||
      oldDelegate.revision != revision ||
      oldDelegate.viewport.state != viewport.state ||
      oldDelegate.defaultColor != defaultColor ||
      oldDelegate.selectionColor != selectionColor ||
      !setEquals(oldDelegate.selectedIds, selectedIds) ||
      !setEquals(oldDelegate.highlightedIds, highlightedIds) ||
      oldDelegate.highlightColor != highlightColor ||
      oldDelegate.highlightPulse != highlightPulse ||
      !listEquals(oldDelegate.previewMarkers, previewMarkers) ||
      !setEquals(oldDelegate.previewObjectIds, previewObjectIds) ||
      oldDelegate.labelDragPreview != labelDragPreview ||
      oldDelegate.showHidden != showHidden ||
      oldDelegate.liftHandleEnabled != liftHandleEnabled ||
      oldDelegate.activePlaneId != activePlaneId ||
      oldDelegate.showAxes != showAxes ||
      oldDelegate.showGrid != showGrid ||
      oldDelegate.axisColor != axisColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.absoluteColor != absoluteColor ||
      oldDelegate.absoluteOutsideColor != absoluteOutsideColor;
}
