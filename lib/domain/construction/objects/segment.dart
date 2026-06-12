import '../../math/line_eq.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';
import 'line_through_two_points.dart';

/// The segment between two points.
///
/// A [GeoLine] via its carrier [line], so segments participate in
/// intersections like infinite lines do (clipping intersection points to
/// the segment's extent is deferred — see `IntersectionPoint`). Undefined
/// while the endpoints coincide or a parent is undefined.
class Segment extends GeoLine {
  Segment({
    required super.id,
    required this.point1,
    required this.point2,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point1;
  final GeoPoint point2;

  LineEq? _line;

  @override
  LineEq? get line => _line;

  /// Current endpoints; null while the respective parent is undefined.
  /// The painter draws from these, [line] exists for intersection math.
  Vec2? get start => point1.position;
  Vec2? get end => point2.position;

  @override
  List<GeoObject> get parents => [point1, point2];

  @override
  void recompute() {
    _line = carrierLineThrough(point1, point2);
  }
}
