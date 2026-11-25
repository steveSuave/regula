import '../../projective/absolute.dart';
import '../../projective/space/plane3.dart';
import '../../projective/space/plane_frame.dart';
import '../geo_object.dart';

/// The plane of one face of a solid (intent 004, milestone 3): what
/// makes a face a place to work in.
///
/// Its coordinates start at the face's first corner and run along its
/// first edge, with the normal along the first two edges' cross product
/// — the face's own loop, in the solid's own order, so a point placed
/// in the face keeps its place whatever else about the solid changes.
/// Which way that normal looks is not asked.
///
/// **Scaffolding** ([isInternal]), like an adapter. The face is its
/// picture, so it draws no patch, is not listed and is never selected;
/// it is in the graph so that what is built in the face has a sheet,
/// and so that undo, deletion and saving need no special case. It is
/// made when a face is first worked in and added by the same command as
/// the first thing built there, and it is left out of a saved file when
/// nothing was.
///
/// The frame is read from the solid at every access and never cached:
/// between a tap on a face and the first commit in it the plane is not
/// yet in the construction, so nothing would recompute it.
class FacePlane extends GeoPlane {
  FacePlane({required super.id, required this.solid, required this.face}) {
    if (face < 0 || face >= solid.faces.length) {
      throw ArgumentError.value(face, 'face', 'The solid has no such face');
    }
  }

  final GeoSolid solid;

  /// The index of the face in `solid.faces`.
  final int face;

  @override
  bool get isInternal => true;

  @override
  PlaneFrame? get frame {
    final corners = solid.faceVertices(face);
    if (corners == null) {
      return null;
    }
    return PlaneFrame.throughPoints(corners[0], corners[1], corners[2]);
  }

  @override
  Plane3? get spacePlane => frame?.plane;

  @override
  List<GeoObject> get parents => [solid];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    // Nothing is cached: see the class doc.
  }
}

/// The plane of face [face] of [solid] among [objects], or null when
/// that face has not been worked in yet.
FacePlane? facePlaneOf(Iterable<GeoObject> objects, GeoSolid solid, int face) {
  for (final object in objects) {
    if (object is FacePlane &&
        identical(object.solid, solid) &&
        object.face == face) {
      return object;
    }
  }
  return null;
}
