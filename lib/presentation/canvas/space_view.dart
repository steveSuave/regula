import '../../domain/construction/geo_object.dart';
import 'canvas_viewport.dart';
import 'fit_viewport.dart';

/// The point the space view's camera turns about: the centre of the
/// figure's bounds, on the base plane — the bounds Fit frames — or the
/// world origin for an empty document.
///
/// Not the point under the canvas centre. Near edge-on that point lies
/// far away on the plane, and turning about it would swing the figure
/// off screen; the figure's own centre keeps what the user is looking at
/// where it is.
SpacePoint figurePivot(Iterable<GeoObject> objects) {
  final bounds = visibleWorldBounds(objects);
  if (bounds == null) {
    return (x: 0, y: 0, z: 0);
  }
  return (
    x: (bounds.min.x + bounds.max.x) / 2,
    y: (bounds.min.y + bounds.max.y) / 2,
    z: 0,
  );
}
