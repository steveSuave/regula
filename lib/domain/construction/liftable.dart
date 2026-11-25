import '../projective/space/plane_frame.dart';
import 'geo_object.dart';

/// A point with a **height** a gesture may change: a stored real number
/// along the normal of a plane, set only through
/// `Construction.setPointHeight` and its command (intent 004).
///
/// Two kinds are this. A `FreePoint` is lifted off the plane it was
/// placed in; a `RaisedPoint` stands over another point. The lift
/// handle, its session and its command work against this and do not
/// know which they hold.
///
/// With a free point's coordinates and a glued point's parameter, a
/// height is one of the three stored numbers of a construction that a
/// gesture changes directly. Everything else is derived.
abstract class Liftable extends GeoPoint {
  Liftable({required super.id, super.attributes});

  /// The signed height along [liftFrame]'s normal.
  double get height;
  set height(double value);

  /// The plane the height is measured over; null while that plane is
  /// undefined.
  PlaneFrame? get liftFrame;
}
