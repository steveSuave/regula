import '../../math/vec2.dart';
import '../geo_object.dart';

/// The orthogonal projection of [point] onto [line] — the foot of the
/// perpendicular.
///
/// Undefined while either parent is (e.g. the line's defining points
/// coincide); a point already on the line projects to itself, which is
/// not degenerate. Segments and rays project onto their infinite
/// carrier, matching `ReflectedPoint`'s mirror semantics.
class ProjectionPoint extends GeoPoint {
  ProjectionPoint({
    required super.id,
    required this.point,
    required this.line,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point;
  final GeoLine line;

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [point, line];

  @override
  void recompute() {
    final p = point.position;
    final carrier = line.line;
    _position = (p == null || carrier == null) ? null : carrier.project(p);
  }
}
