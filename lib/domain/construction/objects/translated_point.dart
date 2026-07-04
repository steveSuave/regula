import '../../math/vec2.dart';
import '../geo_object.dart';

/// [point] translated by the vector from [vectorFrom] to [vectorTo].
///
/// Defined whenever all three parents are — coincident vector points just
/// give the zero translation. The vector is live: dragging either of its
/// defining points re-translates the image.
class TranslatedPoint extends GeoPoint {
  TranslatedPoint({
    required super.id,
    required this.point,
    required this.vectorFrom,
    required this.vectorTo,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPoint point;
  final GeoPoint vectorFrom;
  final GeoPoint vectorTo;

  Vec2? _position;

  @override
  Vec2? get position => _position;

  @override
  List<GeoObject> get parents => [point, vectorFrom, vectorTo];

  @override
  void recompute() {
    final p = point.position;
    final from = vectorFrom.position;
    final to = vectorTo.position;
    _position =
        (p == null || from == null || to == null) ? null : p + (to - from);
  }
}
