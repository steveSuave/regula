import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/construction/geo_object.dart';
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
      (_, _) => state = null,
    );
    return null;
  }

  void set(String? id) => state = id;
}

/// The plane [id] names among [objects] if it is there and defined, else
/// null — the base plane. A plane that has collapsed (three collinear
/// points) has no coordinates to place a point in, so it cannot be
/// worked in until it comes back.
GeoPlane? activePlaneOf(String? id, Iterable<GeoObject> objects) {
  if (id == null) {
    return null;
  }
  for (final object in objects) {
    if (object.id == id) {
      return object is GeoPlane && object.isDefined ? object : null;
    }
  }
  return null;
}
