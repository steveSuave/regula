import '../../math/line_eq.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';
import 'line_through_two_points.dart';

/// The ray from [origin] through [through].
///
/// A [GeoLine] via its carrier [line], so rays participate in
/// intersections like infinite lines do (clipping intersection points to
/// the ray's extent is deferred, matching `Segment`). Undefined while the
/// points coincide or a parent is undefined.
///
/// The carrier's `direction` is normalized independently of the parents'
/// order, so painter and hit tester must use [start] and
/// [throughPosition] — not the carrier — to know which half-line exists.
class Ray extends GeoLine {
  Ray({
    required super.id,
    required this.origin,
    required this.through,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint origin;
  final GeoPoint through;

  LineEq? _line;

  @override
  LineEq? get line => _line;

  /// The ray's endpoint; null while [origin] is undefined.
  Vec2? get start => origin.position;

  /// A point the ray passes through, fixing its direction from [start];
  /// null while [through] is undefined.
  Vec2? get throughPosition => through.position;

  @override
  List<GeoObject> get parents => [origin, through];

  @override
  void recompute() {
    _line = carrierLineThrough(origin, through);
  }
}
