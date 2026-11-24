import 'dart:math' as math;
import 'dart:ui';

import '../../application/providers/viewport_provider.dart';
import '../../domain/construction/document_kernel.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/math/vec2.dart';
import '../../domain/math/vec3.dart';
import '../../domain/projective/conic_matrix.dart';
import '../../domain/projective/conic_shape.dart';
import 'canvas_viewport.dart';

/// Screen pixels kept free around a fitted construction.
const double fitMarginPx = 48;

/// Axis-aligned bounds of the drawable extent of [objects] in the *view
/// frame*: the y-up world frame rotated by [rotation] (the viewport's
/// angle, Phase 61), so the box is screen-aligned at that view angle. At
/// the default `rotation` 0 these are plain world bounds. Null when
/// nothing contributes.
///
/// Hidden and undefined objects don't count — fit frames what the user
/// sees. Per kind: points contribute their position, circles their full
/// carrier disc (arcs/sectors are framed a little loosely, by design —
/// their carrier box is stable while the branch swings during drags;
/// a disc is rotation-invariant, so it rotates as its center ± radius),
/// angles their vertex (the marker is screen-sized), and lines nothing:
/// their carrier is unbounded, and their defining points are objects in
/// the construction contributing on their own.
({Vec2 min, Vec2 max})? visibleWorldBounds(
  Iterable<GeoObject> objects, {
  double rotation = 0,
  Sheet sheet = Sheet.base,
}) {
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  double? minX, minY, maxX, maxY;
  // Extends the box by a point already in the view frame.
  void extend(double x, double y) {
    minX = math.min(minX ?? x, x);
    minY = math.min(minY ?? y, y);
    maxX = math.max(maxX ?? x, x);
    maxY = math.max(maxY ?? y, y);
  }

  // Rotates a world point by +rotation into the view frame — the same
  // R(+θ) `worldToScreen` applies before the flip — then extends.
  void include(double wx, double wy) =>
      extend(wx * cos - wy * sin, wx * sin + wy * cos);

  for (final object in objects) {
    if (!object.attributes.visible || !object.isDefined) {
      continue;
    }
    // Positions are coordinates in a sheet (intent 004): the bounds are
    // of one sheet's objects, the base plane's unless asked otherwise.
    if (object.sheet != sheet) {
      continue;
    }
    switch (object) {
      case GeoPoint(:final position?):
        include(position.x, position.y);
      case GeoCircle(:final circle?):
        // A disc is rotation-invariant: rotate the center, then pad by
        // the radius in the view frame (rotating box *corners* would
        // misplace the box at any non-cardinal angle).
        final cx = circle.center.x * cos - circle.center.y * sin;
        final cy = circle.center.x * sin + circle.center.y * cos;
        extend(cx - circle.radius, cy - circle.radius);
        extend(cx + circle.radius, cy + circle.radius);
      case GeoAngle(:final angle?):
        include(angle.vertex.x, angle.vertex.y);
      case GeoPolygon(:final polygonVertices?):
        for (final vertex in polygonVertices) {
          include(vertex.x, vertex.y);
        }
      case GeoMeasurement(:final anchor?):
        include(anchor.x, anchor.y);
      case GeoText(:final anchor):
        include(anchor.x, anchor.y);
      // Core samples, not the full trace: a line-host locus sweeps its
      // whole carrier and a diverging arm reaches astronomically far —
      // fitting on it would zoom the figure down to a dot.
      case GeoLocus(:final coreSamples?):
        for (final sample in coreSamples) {
          include(sample.x, sample.y);
        }
      case GeoLine():
      // A plane's patch follows the figure, so it must not frame it.
      case GeoPlane():
        break;
      // A Cayley–Klein circle is a conic bitangent to the absolute, so
      // it projects to no centre and radius (Phase 126) and is framed by
      // its conic's own support intervals instead (Phase 130): the box
      // in the *view* frame is the extent between the tangent lines
      // normal to each view axis, which is one call per axis with the
      // axis as the normal — no rotating of the conic, and exact.
      //
      // Null for anything unbounded, which is the same answer this
      // function already gives a line: a hyperbola has two real tangents
      // normal to a direction and runs out between them, so a box built
      // on them would frame a curve that is not there.
      case GeoCircle(:final conic?):
        final box = _conicViewBox(conic, cos, sin);
        if (box != null) {
          extend(box.min.x, box.min.y);
          extend(box.max.x, box.max.y);
        }
      case GeoCircle():
      // isDefined held above, so the remaining null-payload cases are
      // unreachable; Dart's exhaustiveness checker still wants them.
      case GeoPoint():
      case GeoAngle():
      case GeoPolygon():
      case GeoMeasurement():
      case GeoLocus():
        break;
    }
  }
  final left = minX;
  if (left == null) {
    return null;
  }
  return (min: Vec2(left, minY!), max: Vec2(maxX!, maxY!));
}

/// [conic]'s bounding box in the view frame — the frame rotated so that
/// `(cos, sin)` is its x axis — or null when the conic has no bounded ink
/// to frame.
///
/// One [ConicShape.extentAlong] per view axis, with the axis as the
/// line's normal, so the rotation costs a different argument rather than
/// a transformed conic.
({Vec2 min, Vec2 max})? _conicViewBox(
  ConicMatrix conic,
  double cos,
  double sin,
) {
  final shape = ConicShape.of(conic);
  final across = shape.extentAlong(cos, sin);
  final along = shape.extentAlong(-sin, cos);
  if (across == null || along == null) {
    return null;
  }
  return (min: Vec2(across.min, along.min), max: Vec2(across.max, along.max));
}

/// The viewport framing the Cayley–Klein absolute — the unit disc — in
/// [canvasSize], or null when the document's geometry has no real
/// absolute to frame (Phase 126).
///
/// A hyperbolic document lives *inside its absolute*, and the app's
/// default scale is one pixel per world unit, so at the canonical radius
/// the entire plane is a two-pixel dot at the origin. Framing the disc is
/// how the user is shown where the geometry is; without it the mode is
/// technically present and practically invisible.
///
/// Deliberately frames *only* the absolute, not the union of the absolute
/// and the construction — which since Phase 131 is no longer a compromise
/// but the same thing: the switch sizes the absolute to contain the
/// figure, so framing the plane frames the figure with it.
ViewportState? fittedToAbsolute(
  DocumentKernel kernel,
  Size canvasSize, {
  double marginPx = fitMarginPx,
  double rotation = 0,
  double tilt = 0,
}) {
  if (kernel.metric != FundamentalConic.hyperbolic) {
    return null;
  }
  final usable = math.min(
    canvasSize.width - 2 * marginPx,
    canvasSize.height - 2 * marginPx,
  );
  if (usable <= 0) {
    return null;
  }
  // The absolute is a circle of the kernel's radius about the world
  // origin, so the scale that fits it is half the usable extent over that
  // radius — and the pan has to be *solved*, like every other fit:
  // `ViewportState.pan` is the world point at screen (0, 0), not the one
  // at the canvas centre.
  return CanvasViewport.pinning(
    world: Vec2.zero,
    focal: Offset(canvasSize.width / 2, canvasSize.height / 2),
    scale: usable / (2 * kernel.radius),
    rotation: rotation,
    // The disc's width does not foreshorten under a turntable tilt, so
    // the same scale frames it at any camera (intent 004).
    tilt: tilt,
  );
}

/// The viewport framing every visible object centered in [canvasSize]
/// with [marginPx] to spare, or null when there is nothing to frame.
///
/// [rotation] is the view angle the framing keeps (Phase 61 — fit
/// frames, the compass levels): extents are measured in the rotated
/// view frame, so the content fits at that angle. Scale is clamped to
/// [CanvasViewport.minScale]..[CanvasViewport.maxFitScale]; a zero-size
/// extent (a single
/// point) centers at 100 % instead of zooming to the clamp.
///
/// [tilt] is the space view's camera tilt (intent 004): the extent along
/// the view frame's y is foreshortened by `|cos tilt|` on screen, so that
/// is what has to fit the canvas height. Edge-on, only the width binds.
/// The visible, defined points that are not on the base sheet — lifted
/// off it, or on another plane's: what [visibleWorldBounds] cannot see,
/// because it is a box of base-plane coordinates.
/// A segment to a lifted point is covered by the point.
List<Vec3> liftedPositions(Iterable<GeoObject> objects) => [
  for (final object in objects)
    if (object is GeoPoint &&
        object.attributes.visible &&
        (object.position == null || !object.sheet.isBase))
      ?object.spacePosition,
];

/// The centre of the figure in space: the centre of the box around the
/// planar figure's bounds and every lifted point. Null for an empty
/// figure. What the camera turns about.
Vec3? figureCentre(Iterable<GeoObject> objects) {
  final bounds = visibleWorldBounds(objects);
  final lifted = liftedPositions(objects);
  if (bounds == null && lifted.isEmpty) {
    return null;
  }
  final points = [
    if (bounds != null) ...[
      Vec3(bounds.min.x, bounds.min.y, 0),
      Vec3(bounds.max.x, bounds.max.y, 0),
    ],
    ...lifted,
  ];
  var min = points.first;
  var max = points.first;
  for (final p in points.skip(1)) {
    min = Vec3(
      math.min(min.x, p.x),
      math.min(min.y, p.y),
      math.min(min.z, p.z),
    );
    max = Vec3(
      math.max(max.x, p.x),
      math.max(max.y, p.y),
      math.max(max.z, p.z),
    );
  }
  return (min + max) * 0.5;
}

/// [fittedViewport] for a figure with points off the base plane: the
/// screen images of the planar bounds' corners and of every lifted point
/// are framed, since a box on the plane no longer bounds the picture.
ViewportState? _fittedInSpace(
  Iterable<GeoObject> objects,
  List<Vec3> lifted,
  Size canvasSize, {
  required double marginPx,
  required double rotation,
  required double tilt,
}) {
  if (canvasSize.shortestSide <= 0) {
    return null;
  }
  final bounds = visibleWorldBounds(objects);
  final points = [
    if (bounds != null) ...[
      Vec3(bounds.min.x, bounds.min.y, 0),
      Vec3(bounds.min.x, bounds.max.y, 0),
      Vec3(bounds.max.x, bounds.min.y, 0),
      Vec3(bounds.max.x, bounds.max.y, 0),
    ],
    ...lifted,
  ];
  // The picture at unit scale, to measure it.
  final probe = CanvasViewport(ViewportState(rotation: rotation, tilt: tilt));
  final images = [for (final p in points) probe.spaceToScreen(p)];
  var box = Rect.fromPoints(images.first, images.first);
  for (final image in images.skip(1)) {
    box = box.expandToInclude(Rect.fromPoints(image, image));
  }
  final availableWidth = math.max(1.0, canvasSize.width - 2 * marginPx);
  final availableHeight = math.max(1.0, canvasSize.height - 2 * marginPx);
  final scale = (box.width <= 0 && box.height <= 0)
      ? 1.0
      : math
            .min(
              box.width > 0 ? availableWidth / box.width : double.infinity,
              box.height > 0 ? availableHeight / box.height : double.infinity,
            )
            .clamp(CanvasViewport.minScale, CanvasViewport.maxFitScale)
            .toDouble();
  // Parallel projection scales about the pan, so the box's centre is at
  // `box.center * scale`; slide it to the canvas centre.
  final scaled = CanvasViewport(
    ViewportState(scale: scale, rotation: rotation, tilt: tilt),
  );
  return scaled.pannedByScreen(
    Offset(canvasSize.width / 2, canvasSize.height / 2) - box.center * scale,
  );
}

ViewportState? fittedViewport(
  Iterable<GeoObject> objects,
  Size canvasSize, {
  double marginPx = fitMarginPx,
  double rotation = 0,
  double tilt = 0,
}) {
  final lifted = liftedPositions(objects);
  if (lifted.isNotEmpty) {
    return _fittedInSpace(
      objects,
      lifted,
      canvasSize,
      marginPx: marginPx,
      rotation: rotation,
      tilt: tilt,
    );
  }
  final bounds = visibleWorldBounds(objects, rotation: rotation);
  if (bounds == null || canvasSize.shortestSide <= 0) {
    return null;
  }
  final width = bounds.max.x - bounds.min.x;
  final depth = bounds.max.y - bounds.min.y;
  final height = tilt == 0 ? depth : depth * math.cos(tilt).abs();
  final availableWidth = math.max(1.0, canvasSize.width - 2 * marginPx);
  final availableHeight = math.max(1.0, canvasSize.height - 2 * marginPx);
  final scale = (width <= 0 && height <= 0)
      ? 1.0
      : math
            .min(
              width > 0 ? availableWidth / width : double.infinity,
              height > 0 ? availableHeight / height : double.infinity,
            )
            .clamp(CanvasViewport.minScale, CanvasViewport.maxFitScale)
            .toDouble();
  // The bounds center, rotated by −rotation back into world axes so
  // `pinning` (which solves in world coordinates) can put it at the
  // canvas center. At rotation 0 this reduces exactly to the old
  // direct pan solve.
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  final viewCenterX = (bounds.min.x + bounds.max.x) / 2;
  final viewCenterY = (bounds.min.y + bounds.max.y) / 2;
  return CanvasViewport.pinning(
    world: Vec2(
      viewCenterX * cos + viewCenterY * sin,
      viewCenterY * cos - viewCenterX * sin,
    ),
    focal: Offset(canvasSize.width / 2, canvasSize.height / 2),
    scale: scale,
    rotation: rotation,
    tilt: tilt,
  );
}
