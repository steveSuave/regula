import 'geo_object.dart';
import 'objects/free_point.dart';

/// Whether a document holds anything off the base plane (intent 004,
/// milestone 2): a plane, a point or line with no sheet, or a lifted
/// free point. Hidden objects count — the document is what it is whether
/// or not it shows.
///
/// It is what makes a document open in the space view, what the prover
/// declines (it is planar), and what refuses a change of geometry (space
/// is Euclidean). The save format's version 4 names the same thing on
/// the encoded side.
bool hasSpaceContent(Iterable<GeoObject> objects) => objects.any(
  (object) =>
      object is GeoPlane ||
      object.sheetFrame == null ||
      (object is FreePoint && object.isLifted),
);
