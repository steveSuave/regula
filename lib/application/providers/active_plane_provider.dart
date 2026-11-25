import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/construction/geo_object.dart';
import '../../domain/construction/objects/face_plane.dart';
import '../object_ids.dart';
import 'construction_provider.dart';

part 'active_plane_provider.g.dart';

/// The id of the active plane (intent 004, milestone 2), or null for the
/// base plane: the plane a tool's tap lands in and a new free point is
/// placed in.
///
/// Session state, like the space view it belongs to: never saved, the
/// base plane at launch, after File > New or Open, and whenever the
/// space view is turned off. It holds an id, not the plane, so that an
/// undo which removes the plane does not leave a tool working in an
/// object that is gone: read it through [activePlaneOf], which answers
/// the base plane for an id that no longer names a defined plane.
@Riverpod(keepAlive: true, name: 'activePlaneProvider')
class ActivePlaneNotifier extends _$ActivePlaneNotifier {
  @override
  String? build() {
    // A swapped-in construction has none of the old one's planes.
    ref.listen(
      constructionProvider.select((ConstructionState s) => s.construction),
      (_, _) {
        _pending = null;
        state = null;
      },
    );
    return null;
  }

  FacePlane? _pending;

  /// The plane of a face that has been tapped and not yet built in: it
  /// is active and not yet in the construction (intent 004, milestone
  /// 3). One instance per face for as long as that face stays the
  /// active one, because a sheet is an identity: two taps of one tool
  /// must land in the same plane object. The first command that builds
  /// in it adds it.
  FacePlane? get pending => _pending;

  void set(String? id) {
    if (id != _pending?.id) {
      _pending = null;
    }
    state = id;
  }

  /// Makes face [face] of [solid] the active plane: the plane already
  /// built for it among [objects], or one held here until something is
  /// built in it.
  void setFace(GeoSolid solid, int face, Iterable<GeoObject> objects) {
    final existing = facePlaneOf(objects, solid, face);
    if (existing != null) {
      set(existing.id);
      return;
    }
    final held = _pending;
    if (held != null && identical(held.solid, solid) && held.face == face) {
      state = held.id;
      return;
    }
    final plane = FacePlane(id: newObjectId(), solid: solid, face: face);
    _pending = plane;
    state = plane.id;
  }
}

/// The plane [id] names among [objects] if it is there and defined, else
/// null — the base plane. A plane that has collapsed (three collinear
/// points) has no coordinates to place a point in, so it cannot be
/// worked in until it comes back.
GeoPlane? activePlaneOf(
  String? id,
  Iterable<GeoObject> objects, {
  FacePlane? pending,
}) {
  if (id == null) {
    return null;
  }
  var solidIsThere = false;
  for (final object in objects) {
    if (object.id == id) {
      return object is GeoPlane && object.isDefined ? object : null;
    }
    solidIsThere = solidIsThere || identical(object, pending?.solid);
  }
  // A face tapped and not yet built in: active while its solid is
  // still in the construction and the face still has a plane.
  if (pending != null &&
      pending.id == id &&
      solidIsThere &&
      pending.isDefined) {
    return pending;
  }
  return null;
}
