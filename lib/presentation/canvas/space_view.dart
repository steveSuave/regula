import 'dart:math' as math;
import 'dart:ui';

import '../../application/providers/viewport_provider.dart';
import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/free_point.dart';
import '../../domain/math/vec2.dart';
import '../../domain/math/vec3.dart';
import 'canvas_viewport.dart';
import 'fit_viewport.dart';

/// The camera positions the Views menu offers.
enum SpaceViewPreset {
  /// Straight down, level: the plan, which is the planar view.
  top('Top', 0, 0),

  /// Edge-on to the base plane, looking along world +y.
  front('Front', 0, math.pi / 2),

  /// Edge-on, looking along world −x.
  side('Side', math.pi / 2, math.pi / 2),

  /// The textbook three-quarter view.
  oblique('Oblique', -math.pi / 6, obliqueTilt);

  const SpaceViewPreset(this.label, this.rotation, this.tilt);

  final String label;
  final double rotation;
  final double tilt;
}

/// The tilt the space view opens at: 60° from straight down, where a
/// square on the base plane is drawn half as tall as it is wide.
const double obliqueTilt = math.pi / 3;

/// Whether a document holds anything off the base plane: what makes it a
/// version 4 file, and what makes it open in the space view. Hidden
/// objects count — the document is what it is whether or not it shows.
bool hasSpaceContent(Iterable<GeoObject> objects) =>
    objects.any((object) => object is FreePoint && object.isLifted);

/// The point the space view's camera turns about: the centre of the
/// figure's bounds — the planar bounds Fit frames, together with any
/// point lifted off the plane — or the world origin for an empty document.
///
/// Not the point under the canvas centre. Near edge-on that point lies
/// far away on the plane, and turning about it would swing the figure
/// off screen; the figure's own centre keeps what the user is looking at
/// where it is.
Vec3 figurePivot(Iterable<GeoObject> objects) =>
    figureCentre(objects) ?? Vec3.zero;

/// The camera after the space view is switched on: tilted to
/// [obliqueTilt] at the azimuth it had, the figure where it was.
ViewportState enterSpaceView(
  CanvasViewport current,
  Iterable<GeoObject> objects,
) => current.orbitedAbout(
  figurePivot(objects),
  rotation: current.state.rotation,
  tilt: obliqueTilt,
);

/// The camera after the space view is switched off: looking straight
/// down again at the azimuth it had, the figure where it was. Scale and
/// rotation are the planar view's own, so they are kept.
ViewportState leaveSpaceView(
  CanvasViewport current,
  Iterable<GeoObject> objects,
) => current.orbitedAbout(
  figurePivot(objects),
  rotation: current.state.rotation,
  tilt: 0,
);

/// The camera at [preset], the figure where it was.
ViewportState presetSpaceView(
  CanvasViewport current,
  Iterable<GeoObject> objects,
  SpaceViewPreset preset,
) => current.orbitedAbout(
  figurePivot(objects),
  rotation: preset.rotation,
  tilt: preset.tilt,
);

/// Reset in the space view: the world origin at the canvas centre, 100 %,
/// at the oblique preset. (The planar Reset puts the origin at the
/// canvas corner; a turned figure about a corner would be mostly off
/// screen.)
ViewportState resetSpaceView(Size canvasSize) => CanvasViewport.pinning(
  world: Vec2.zero,
  focal: canvasSize.center(Offset.zero),
  scale: 1,
  rotation: SpaceViewPreset.oblique.rotation,
  tilt: SpaceViewPreset.oblique.tilt,
);
