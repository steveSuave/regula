import '../../math/line_eq.dart';
import '../../projective/absolute.dart';
import '../../projective/proj_line.dart';
import '../../projective/space/line3.dart';
import '../geo_object.dart';
import '../object_attributes.dart';
import '../space_incidence.dart';
import 'ray.dart';
import 'segment.dart';

/// A line of space, read in a plane's coordinates: the line sibling of
/// `ChartPoint` (intent 004, milestone 2). The base edge AB of a
/// pyramid, used inside the face OAB to drop the slant height onto it,
/// reaches that perpendicular through one of these.
///
/// Scaffolding ([isInternal]), and the same line as its [source]: its
/// [spaceLine] is the source's own, and it keeps the source's extent — a
/// segment read in a plane is still that segment, so a point glued to it
/// stays between its ends.
///
/// Its carrier is the orthogonal pull of the source onto the plane, and
/// it has one only while the source lies in the plane by construction
/// (see `ChartPoint` for why that is asked at every recompute).
class ChartLine extends GeoLine {
  ChartLine({
    required super.id,
    required this.source,
    required this.plane,
    ObjectAttributes? attributes,
  }) : super(attributes: attributes ?? const ObjectAttributes(visible: false)) {
    recompute();
  }

  final GeoLine source;
  final GeoPlane plane;

  ProjLine? _carrier;
  LineEq? _line;

  @override
  bool get isInternal => true;

  @override
  Sheet get sheet => Sheet.of(plane);

  @override
  ProjLine? get projLine => _carrier;

  @override
  LineEq? get line => _line;

  @override
  Line3? get spaceLine => _carrier == null ? null : source.spaceLine;

  /// The source's ends, in this plane's coordinates along this carrier.
  @override
  (double?, double?)? get parameterExtent {
    final line = _line;
    final frame = plane.frame;
    if (line == null || frame == null) {
      return null;
    }
    switch (source) {
      case Segment(:final spaceStart?, :final spaceEnd?):
        final t1 = line.parameterAt(frame.pull(spaceStart));
        final t2 = line.parameterAt(frame.pull(spaceEnd));
        return t1 <= t2 ? (t1, t2) : (t2, t1);
      case Ray(:final spaceStart?, :final spaceThrough?):
        final t0 = line.parameterAt(frame.pull(spaceStart));
        final tThrough = line.parameterAt(frame.pull(spaceThrough));
        return tThrough >= t0 ? (t0, null) : (null, t0);
      default:
        return null;
    }
  }

  @override
  List<GeoObject> get parents => [source, plane];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    final at = source.spaceLine;
    final frame = plane.frame;
    if (at == null || frame == null || !liesIn(source, plane)) {
      _carrier = null;
      _line = null;
      return;
    }
    final pulled = frame.pullLine(at);
    _carrier = pulled.isZero ? null : pulled;
    _line = _carrier?.toOrientedLineEq();
  }
}
