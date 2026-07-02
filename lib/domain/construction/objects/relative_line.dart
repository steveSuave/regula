import '../../math/line_eq.dart';
import '../../math/vec2.dart';
import '../geo_object.dart';

/// Base for lines derived from a point and a reference line: the subclass
/// picks the direction (`PerpendicularLine`, `ParallelLine`), this base
/// handles parents and degeneracy.
///
/// The reference may be any [GeoLine] — a segment's carrier works as well
/// as an infinite line's. Undefined while [through] or [reference] is
/// undefined; comes back when both recover.
abstract class RelativeLine extends GeoLine {
  RelativeLine({
    required super.id,
    required this.through,
    required this.reference,
    super.attributes,
  }) {
    recompute();
  }

  /// The point the derived line passes through.
  final GeoPoint through;

  /// The line the derived direction is taken from.
  final GeoLine reference;

  LineEq? _line;

  @override
  LineEq? get line => _line;

  @override
  List<GeoObject> get parents => [through, reference];

  /// Direction of the derived line, given the reference's carrier.
  /// [LineEq.normal] and [LineEq.direction] are unit length, so
  /// implementations built on them never hand a zero direction to
  /// `LineEq.pointDirection`.
  Vec2 directionFrom(LineEq referenceLine);

  @override
  void recompute() {
    final p = through.position;
    final ref = reference.line;
    _line = (p == null || ref == null)
        ? null
        : LineEq.pointDirection(p, directionFrom(ref));
  }
}
