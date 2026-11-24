import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_point.dart';
import '../../projective/space/point3.dart';
import '../geo_object.dart';
import '../object_attributes.dart';
import '../space_incidence.dart';

/// A point of space, read in a plane's coordinates: the adapter that
/// lets a planar construction in [plane] take [source], a point that
/// lies in the plane without being on its sheet (intent 004, milestone
/// 2). The apex of a pyramid, used as the centre of a circle drawn in
/// one of its faces, reaches the circle through one of these.
///
/// It is scaffolding ([isInternal]): a real object of the graph, so that
/// undo, deletion cascades and saving need no special case, and never
/// drawn, picked, named or listed. It is the same point as its source,
/// so its [spacePoint] is the source's own.
///
/// Its value is the orthogonal pull of the source onto the plane — which
/// is the source itself exactly while the source lies in the plane by
/// construction, and that is the only time it has a value: `liesIn` is
/// asked at every recompute, because the one thing that can take a point
/// out of a plane it was built in is lifting it, and then a pull would
/// answer its foot.
class ChartPoint extends GeoPoint {
  ChartPoint({
    required super.id,
    required this.source,
    required this.plane,
    ObjectAttributes? attributes,
  }) : super(attributes: attributes ?? const ObjectAttributes(visible: false)) {
    recompute();
  }

  final GeoPoint source;
  final GeoPlane plane;

  ProjPoint? _point;

  @override
  bool get isInternal => true;

  @override
  Sheet get sheet => Sheet.of(plane);

  @override
  ProjPoint? get projPoint => _point;

  @override
  Vec2? get position => _point?.toVec2();

  @override
  Point3? get spacePoint => _point == null ? null : source.spacePoint;

  @override
  Vec3? get spacePosition => _point == null ? null : source.spacePosition;

  @override
  List<GeoObject> get parents => [source, plane];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final at = source.spacePoint;
    final frame = plane.frame;
    if (at == null || frame == null || !liesIn(source, plane)) {
      _point = null;
      return;
    }
    final pulled = frame.pullPoint(at);
    _point = pulled.isZero ? null : pulled.wPositive;
  }
}
