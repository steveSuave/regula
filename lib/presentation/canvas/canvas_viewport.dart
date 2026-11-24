import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../application/providers/viewport_provider.dart';
import '../../domain/math/vec2.dart';
import '../../domain/math/vec3.dart';
import '../../domain/projective/space/plane_frame.dart';

/// A point of space, in world coordinates: the base plane is `z == 0` and
/// a planar document's `Vec2(x, y)` is `(x, y, 0)`. A presentation-side
/// record, for camera pivots; the space kernel (intent 004, milestone 2)
/// brings the domain's own type.

/// World↔screen transforms for the canvas, built from a [ViewportState]
/// (never duplicating its data — see the Phase 4 STATUS note).
///
/// Named `CanvasViewport` because Flutter already ships a `Viewport`
/// widget and the two would collide in every file importing
/// `flutter/widgets.dart`.
///
/// Conventions:
/// - World coordinates are y-up (the geometry convention); screen
///   coordinates are y-down (the Flutter convention). This class is the
///   only place the flip happens — painter and hit tester stay flip-free.
/// - `state.pan` is the world-space point at the canvas origin (top-left);
///   `state.scale` is screen pixels per world unit.
/// - `state.rotation` rotates the content about the canvas origin,
///   positive = counterclockwise on screen (Phase 43). The rotation is
///   applied in the y-up frame *before* the flip, so `pan` keeps its
///   meaning at any angle (the origin is the rotation's fixed point).
///   Rotation preserves lengths, so the length helpers carry no term.
///
/// **The space view (intent 004).** With `state.tilt` nonzero this is a
/// turntable camera under parallel projection, and the `Vec2` transforms
/// are those of the **base plane**. Three things follow, and
/// DECISIONS §"The space view is a camera over one document" argues them:
/// - At tilt 0 every method takes the planar branch it always had, by an
///   early return rather than by multiplying through `cos 0`, so no
///   float differs from the planar app.
/// - The tilted image of the base plane is the planar image with its
///   screen y scaled by `cos tilt` and shifted — [sheetToScreen]. The
///   painter computes in the planar frame ([flat]) and maps through it.
/// - [worldToScreenLength], [worldToScreenAngle] and
///   [worldToScreenDirection] are quantities of that planar frame: a
///   tilted plane has no single pixels-per-unit.
class CanvasViewport {
  const CanvasViewport(this.state);

  /// Zoom bounds, in screen pixels per world unit. Wide enough that no
  /// reasonable construction hits them; tight enough that float precision
  /// in the transforms never becomes visible.
  ///
  /// [maxScale] was 50 through Phase 126, which was ample for Euclidean
  /// documents — they are drawn at world coordinates of order tens to
  /// hundreds — and far too tight for a **hyperbolic** one, whose entire
  /// plane is the unit disc: at 50 the whole geometry was 100 pixels
  /// across and could not be worked in. Raised to 2000, which frames the
  /// disc in a typical window at roughly 300 and leaves an order of
  /// magnitude to zoom in with.
  ///
  /// The bound is not a precision cliff and never was. `worldToScreen`
  /// subtracts the pan *before* scaling, so the significant digits are
  /// spent in `world − pan` — a difference bounded by the visible window
  /// in world units, which shrinks as the scale grows. What the ceiling
  /// really guards is the *view*: a gesture that can zoom without limit
  /// loses the figure.
  static const double minScale = 0.05;
  static const double maxScale = 2000;

  /// The ceiling a **fit** may reach, which is deliberately lower than
  /// [maxScale] and used to be the same number.
  ///
  /// Raising [maxScale] for the hyperbolic disc moved six goldens, and
  /// that was the useful part: it showed the two limits were answering
  /// different questions through one constant. "How far may the user
  /// zoom?" is about the view, and a hyperbolic document needs a great
  /// deal of it. "How far may a fit blow a tiny figure up?" is about
  /// taste — a three-point construction one world unit across should not
  /// fill the window at 2000× — and its right answer did not change.
  /// `fittedToAbsolute` takes [maxScale], because the absolute is not a
  /// figure that happens to be small: it is the whole plane.
  static const double maxFitScale = 50;

  /// `|cos tilt|` below which the base plane is too close to edge-on to
  /// be picked (about 2.9° either side of it). A pointer there answers a
  /// plane point tens of canvas widths from anything on screen, so
  /// [pickBasePlane] refuses instead; panning and orbiting stay total.
  static const double pickFloor = 0.05;

  final ViewportState state;

  /// Whether the camera has left the planar view.
  bool get isTilted => state.tilt != 0;

  /// Whether a pointer can be resolved to a base-plane point.
  bool get basePlanePickable =>
      !isTilted || math.cos(state.tilt).abs() >= pickFloor;

  /// This viewport with the camera looking straight down: the planar
  /// frame the painter computes in. Itself when not tilted.
  CanvasViewport get flat => isTilted
      ? CanvasViewport(
          ViewportState(
            pan: state.pan,
            scale: state.scale,
            rotation: state.rotation,
          ),
        )
      : this;

  /// The screen-y shift of the sheet map: where the planar frame's
  /// `y == 0` row lands.
  double get _sheetShift => state.scale * math.sin(state.tilt) * state.panZ;

  /// `cos tilt`, held away from zero by [pickFloor] with its sign kept —
  /// the divisor of every pull-back from the screen to the base plane.
  double get _pullbackCos {
    final cosTilt = math.cos(state.tilt);
    if (cosTilt.abs() >= pickFloor) {
      return cosTilt;
    }
    return cosTilt < 0 ? -pickFloor : pickFloor;
  }

  /// The sheet map: carries a point of the [flat] frame's screen to this
  /// camera's screen. The identity when not tilted.
  Offset sheetToScreen(Offset flatScreen) => isTilted
      ? Offset(
          flatScreen.dx,
          math.cos(state.tilt) * flatScreen.dy + _sheetShift,
        )
      : flatScreen;

  /// The sheet map as a column-major 4×4, for `Path.transform`.
  Float64List get sheetMatrix => Float64List(16)
    ..[0] = 1
    ..[5] = math.cos(state.tilt)
    ..[10] = 1
    ..[13] = _sheetShift
    ..[15] = 1;

  /// The part of the [flat] frame's screen this camera can see on a
  /// [canvasSize] canvas grown by [margin] — the canvas rectangle pulled
  /// back through the sheet map. `Offset.zero & canvasSize` (grown) when
  /// not tilted. Inside the edge-on band the true region is unbounded;
  /// [pickFloor] bounds it at twenty canvas heights.
  Rect flatFrame(Size canvasSize, {double margin = 0}) {
    if (!isTilted) {
      // `0 - margin`, not `-margin`: the unmargined frame's corner must
      // be +0.0, the `Offset.zero` the planar painter always used.
      return Rect.fromLTRB(
        0 - margin,
        0 - margin,
        canvasSize.width + margin,
        canvasSize.height + margin,
      );
    }
    final cosTilt = _pullbackCos;
    final a = (-margin - _sheetShift) / cosTilt;
    final b = (canvasSize.height + margin - _sheetShift) / cosTilt;
    return Rect.fromLTRB(
      -margin,
      math.min(a, b),
      canvasSize.width + margin,
      math.max(a, b),
    );
  }

  /// The screen image of a point of space.
  Offset spaceToScreen(Vec3 point) {
    final dx = point.x - state.pan.x;
    final dy = point.y - state.pan.y;
    final dz = point.z - state.panZ;
    final c = math.cos(state.rotation);
    final s = math.sin(state.rotation);
    final ux = dx * c - dy * s;
    final uy = dx * s + dy * c;
    return Offset(
      ux * state.scale,
      -(math.cos(state.tilt) * uy + math.sin(state.tilt) * dz) * state.scale,
    );
  }

  /// How near the viewer a point of space is: its coordinate along the
  /// view direction, larger for nearer. Parallel projection has no eye
  /// point, so only differences mean anything; the hit test uses them to
  /// prefer the nearer of two objects equally close to the pointer.
  double depthOf(Vec3 point) {
    final dx = point.x - state.pan.x;
    final dy = point.y - state.pan.y;
    final dz = point.z - state.panZ;
    final uy = dx * math.sin(state.rotation) + dy * math.cos(state.rotation);
    return math.cos(state.tilt) * dz - math.sin(state.tilt) * uy;
  }

  /// The point of space under [screen]: on the base plane when it can be
  /// picked, otherwise on the plane through the pan point that faces the
  /// camera. Always defined — the anchor for gestures that must keep
  /// "what is under the finger" there at any tilt.
  Vec3 spaceUnder(Offset screen) {
    if (basePlanePickable) {
      final world = screenToWorld(screen);
      return Vec3(world.x, world.y, 0);
    }
    final vx = screen.dx / state.scale;
    final vy = -screen.dy / state.scale;
    final uy = math.cos(state.tilt) * vy;
    final uz = math.sin(state.tilt) * vy;
    final c = math.cos(state.rotation);
    final s = math.sin(state.rotation);
    return Vec3(
      state.pan.x + vx * c + uy * s,
      state.pan.y + uy * c - vx * s,
      state.panZ + uz,
    );
  }

  /// The base-plane point under [screen], or null when the plane is
  /// within [pickFloor] of edge-on. What a tap or an object drag uses.
  ///
  /// With a [height], the pick is on the plane that far above the base
  /// plane, and the answer is the foot of the picked point: where a
  /// point lifted to that height must have its base coordinates to sit
  /// under the pointer. That is how a lifted point is dragged parallel
  /// to its plane.
  Vec2? pickBasePlane(Offset screen, {double height = 0}) =>
      basePlanePickable ? screenToWorld(footScreen(screen, height)) : null;

  /// The point of a plane under [screen], in the plane's own [frame]
  /// coordinates — or, with a [height], the foot of the point picked on
  /// the parallel plane that far along the normal. Null when the plane is
  /// seen within [pickFloor] of edge-on: the same refusal as
  /// [pickBasePlane], for the same reason, at any plane.
  ///
  /// Under parallel projection a plane's coordinates map to the screen
  /// affinely, so the pick is the inverse of a 2×2 map whose determinant
  /// is `scale² · cos(angle between the normal and the view)`.
  Vec2? pickPlane(Offset screen, PlaneFrame frame, {double height = 0}) {
    final origin = spaceToScreen(frame.lift(Vec2.zero, height));
    final base = spaceToScreen(frame.origin);
    final u = spaceToScreen(frame.origin + frame.u) - base;
    final v = spaceToScreen(frame.origin + frame.v) - base;
    final det = u.dx * v.dy - u.dy * v.dx;
    if (det.abs() < pickFloor * state.scale * state.scale) {
      return null;
    }
    final d = screen - origin;
    return Vec2(
      (d.dx * v.dy - d.dy * v.dx) / det,
      (u.dx * d.dy - u.dy * d.dx) / det,
    );
  }

  /// The screen image of the foot of a point seen at [screen] and known
  /// to be [height] above the base plane. [screen] itself at height 0.
  Offset footScreen(Offset screen, double height) => height == 0
      ? screen
      : Offset(
          screen.dx,
          screen.dy + state.scale * math.sin(state.tilt) * height,
        );

  /// The state with the camera turned to [rotation] and [tilt] while
  /// [pivot] keeps its place on screen.
  ViewportState orbitedAbout(
    Vec3 pivot, {
    required double rotation,
    required double tilt,
  }) => pinning(
    world: Vec2(pivot.x, pivot.y),
    worldZ: pivot.z,
    focal: spaceToScreen(pivot),
    scale: state.scale,
    rotation: rotation,
    tilt: tilt,
  );

  /// The state after multiplying scale by [factor] (> 1 zooms in) while
  /// keeping the world point under [focal] (screen coordinates) exactly
  /// there — the cursor pins the content. Scale is clamped to
  /// [minScale]..[maxScale]; at a bound the state returns unchanged.
  ViewportState zoomedAbout(Offset focal, double factor) {
    final newScale = (state.scale * factor)
        .clamp(minScale, maxScale)
        .toDouble();
    if (newScale == state.scale) {
      return state;
    }
    if (isTilted) {
      final under = spaceUnder(focal);
      return pinning(
        world: Vec2(under.x, under.y),
        worldZ: under.z,
        focal: focal,
        scale: newScale,
        rotation: state.rotation,
        tilt: state.tilt,
      );
    }
    return pinning(
      world: screenToWorld(focal),
      focal: focal,
      scale: newScale,
      rotation: state.rotation,
    );
  }

  /// The state after shifting the content by [delta] screen pixels
  /// (y-down, like a pointer delta): content follows a rightward/downward
  /// delta, so the world point at the canvas origin moves the other way.
  /// Backs viewport nudging; scale and rotation are untouched.
  ViewportState pannedByScreen(Offset delta) {
    if (isTilted) {
      // The same statement in space: whatever sits delta before the
      // origin moves to the origin. Total at edge-on, where a vertical
      // delta is a change of height rather than of plane point.
      final under = spaceUnder(-delta);
      return pinning(
        world: Vec2(under.x, under.y),
        worldZ: under.z,
        focal: Offset.zero,
        scale: state.scale,
        rotation: state.rotation,
        tilt: state.tilt,
      );
    }
    return ViewportState(
      // The new origin world point is whatever currently sits delta
      // *before* the origin — valid at any rotation, since
      // screenToWorld already folds the angle in.
      pan: screenToWorld(-delta),
      scale: state.scale,
      rotation: state.rotation,
    );
  }

  /// The state with [scale] (clamped) and [rotation] whose pan puts the
  /// [world] point at the [focal] screen point — the shared solve behind
  /// scroll zoom and the pinch/pan gesture, where the anchor world point
  /// must track a moving focal.
  ///
  /// With a nonzero [tilt] the pinned point is the point of space
  /// `(world, worldZ)`. The pan is only determined up to a slide along
  /// the view direction, which no picture can show; it is slid onto the
  /// base plane (`panZ == 0`) whenever the plane can be picked, so that
  /// away from edge-on the pan stays what it is in the planar view: the
  /// base-plane point at the canvas origin.
  static ViewportState pinning({
    required Vec2 world,
    required Offset focal,
    required double scale,
    double rotation = 0,
    double tilt = 0,
    double worldZ = 0,
  }) {
    final clamped = scale.clamp(minScale, maxScale).toDouble();
    if (tilt != 0) {
      final clampedTilt = tilt.clamp(0.0, math.pi).toDouble();
      final cosTilt = math.cos(clampedTilt);
      final sinTilt = math.sin(clampedTilt);
      final c = math.cos(rotation);
      final s = math.sin(rotation);
      final vx = focal.dx / clamped;
      final vy = -focal.dy / clamped;
      // The focal's offset from the pan, in the camera-facing plane
      // through the pan, turned back into world axes.
      var uy = cosTilt * vy;
      var panZ = worldZ - sinTilt * vy;
      if (cosTilt.abs() >= pickFloor) {
        // Slide along the view direction (0, −sin, cos) to height 0.
        uy -= sinTilt * panZ / cosTilt;
        panZ = 0;
      }
      return ViewportState(
        pan: Vec2(world.x - (vx * c + uy * s), world.y - (uy * c - vx * s)),
        scale: clamped,
        rotation: rotation,
        tilt: clampedTilt,
        panZ: panZ,
      );
    }
    // Solve screenToWorld(focal) == world for pan: pan = world − R(−θ)·f,
    // where f is the focal in y-up world units.
    final fx = focal.dx / clamped;
    final fy = -focal.dy / clamped;
    final c = math.cos(rotation);
    final s = math.sin(rotation);
    return ViewportState(
      pan: Vec2(world.x - (fx * c + fy * s), world.y - (fy * c - fx * s)),
      scale: clamped,
      rotation: rotation,
    );
  }

  Offset worldToScreen(Vec2 world) {
    final dx = world.x - state.pan.x;
    final dy = world.y - state.pan.y;
    final c = math.cos(state.rotation);
    final s = math.sin(state.rotation);
    // Rotate by +θ in the y-up frame, then scale and flip. At θ = 0 the
    // products reduce exactly to the pre-rotation transform.
    final flatScreen = Offset(
      (dx * c - dy * s) * state.scale,
      -(dx * s + dy * c) * state.scale,
    );
    return isTilted ? sheetToScreen(flatScreen) : flatScreen;
  }

  /// The base-plane point under [screen]. Total: inside the edge-on band
  /// the pull-back is held at [pickFloor], which is right for a clip
  /// bound and wrong for a pointer — those go through [pickBasePlane].
  Vec2 screenToWorld(Offset screen) {
    if (isTilted) {
      return flat.screenToWorld(
        Offset(screen.dx, (screen.dy - _sheetShift) / _pullbackCos),
      );
    }
    final rx = screen.dx / state.scale;
    final ry = -screen.dy / state.scale;
    final c = math.cos(state.rotation);
    final s = math.sin(state.rotation);
    // Unflip and unscale, then rotate by −θ back into world axes.
    return Vec2(state.pan.x + rx * c + ry * s, state.pan.y + ry * c - rx * s);
  }

  /// Screen-space polar angle of the world-space polar angle
  /// [worldAngle]: the view rotation composes in, then the y-flip negates
  /// — `worldToScreen(c + r·(cos α, sin α))` lands at screen angle
  /// `worldToScreenAngle(α)` from `worldToScreen(c)`. Angle *sweeps*
  /// (differences) only negate; the rotation term cancels.
  double worldToScreenAngle(double worldAngle) =>
      -(worldAngle + state.rotation);

  /// Screen-space image of the world-space direction [direction]
  /// (rotated, y-flipped, *not* scaled — a unit world direction stays a
  /// unit screen direction).
  Offset worldToScreenDirection(Vec2 direction) {
    final c = math.cos(state.rotation);
    final s = math.sin(state.rotation);
    return Offset(
      direction.x * c - direction.y * s,
      -(direction.x * s + direction.y * c),
    );
  }

  /// Screen pixels covered by [worldLength] world units.
  double worldToScreenLength(double worldLength) => worldLength * state.scale;

  /// World units covered by [screenLength] screen pixels — e.g. the 8 px
  /// hit-test threshold expressed in world units.
  double screenToWorldLength(double screenLength) => screenLength / state.scale;

  /// The world radius, on the base plane, of a [screenRadius]-pixel
  /// reach.
  ///
  /// Not tilted, it is [screenToWorldLength], and the plan view's hit
  /// test uses it. Tilted, a world disc is a squashed ellipse on screen,
  /// so the radius is widened by `1 / |cos tilt|`, capped at double.
  /// Since milestone 2 of intent 004 the space view hit-tests in screen
  /// pixels (`SpaceHitTester`) and no longer leans on that; what still
  /// reads this under a tilt is a tool's snap threshold, which is a
  /// distance on the plane by nature and for which the approximation is
  /// the honest size.
  double hitRadius(double screenRadius) => isTilted
      ? screenRadius / state.scale / math.max(math.cos(state.tilt).abs(), 0.5)
      : screenToWorldLength(screenRadius);

  /// Axis-aligned world bounds enclosing a [canvasSize] canvas, grown by
  /// [margin] screen pixels on every side.
  ///
  /// The box of the four corners' world images: under a nonzero
  /// [ViewportState.rotation] the visible region is a rotated rectangle,
  /// so this is a superset rather than the region itself. That is the
  /// right side to err on — it is a clip bound for unbounded curves, and
  /// the canvas trims whatever it over-includes.
  ({Vec2 min, Vec2 max}) visibleWorldBox(Size canvasSize, {double margin = 0}) {
    if (isTilted) {
      return flat.worldBoxOf(flatFrame(canvasSize, margin: margin));
    }
    final corners = [
      screenToWorld(Offset(-margin, -margin)),
      screenToWorld(Offset(canvasSize.width + margin, -margin)),
      screenToWorld(Offset(-margin, canvasSize.height + margin)),
      screenToWorld(
        Offset(canvasSize.width + margin, canvasSize.height + margin),
      ),
    ];
    var minX = corners.first.x, maxX = corners.first.x;
    var minY = corners.first.y, maxY = corners.first.y;
    for (final corner in corners.skip(1)) {
      minX = math.min(minX, corner.x);
      maxX = math.max(maxX, corner.x);
      minY = math.min(minY, corner.y);
      maxY = math.max(maxY, corner.y);
    }
    return (min: Vec2(minX, minY), max: Vec2(maxX, maxY));
  }

  /// [visibleWorldBox] for an arbitrary screen rectangle [frame] of this
  /// viewport, which must not be tilted: the axis-aligned world bounds of
  /// its four corners. For `Offset.zero & size` it is `visibleWorldBox`
  /// to the bit.
  ({Vec2 min, Vec2 max}) worldBoxOf(Rect frame) {
    assert(!isTilted, 'worldBoxOf is a planar-frame question');
    final corners = [
      screenToWorld(frame.topLeft),
      screenToWorld(frame.topRight),
      screenToWorld(frame.bottomLeft),
      screenToWorld(frame.bottomRight),
    ];
    var minX = corners.first.x, maxX = corners.first.x;
    var minY = corners.first.y, maxY = corners.first.y;
    for (final corner in corners.skip(1)) {
      minX = math.min(minX, corner.x);
      maxX = math.max(maxX, corner.x);
      minY = math.min(minY, corner.y);
      maxY = math.max(maxY, corner.y);
    }
    return (min: Vec2(minX, minY), max: Vec2(maxX, maxY));
  }
}
