import '../../math/vec2.dart';
import '../geo_object.dart';

/// The closed region over [vertices], in loop order — the first
/// variable-arity object: at least 3 vertices, fixed for the object's
/// lifetime (constructor-enforced, like every parent list).
///
/// A polygon draws its own closed outline and fill and deliberately owns
/// no `Segment` edges — the shape macros stay segment-based editable
/// compositions, while this is a single first-class region. Undefined
/// while any vertex is; a collinear or self-intersecting loop stays
/// defined (it is a drawable outline — area math handles it separately).
class Polygon extends GeoPolygon {
  Polygon({
    required super.id,
    required List<GeoPoint> vertices,
    super.attributes,
  }) : vertices = List.unmodifiable(vertices) {
    if (vertices.length < 3) {
      throw ArgumentError.value(
        vertices.length,
        'vertices',
        'A polygon needs at least 3 vertices',
      );
    }
    recompute();
  }

  final List<GeoPoint> vertices;

  List<Vec2>? _polygonVertices;

  @override
  List<Vec2>? get polygonVertices => _polygonVertices;

  @override
  List<GeoObject> get parents => vertices;

  @override
  void recompute() {
    final positions = <Vec2>[];
    for (final vertex in vertices) {
      final position = vertex.position;
      if (position == null) {
        _polygonVertices = null;
        return;
      }
      positions.add(position);
    }
    _polygonVertices = List.unmodifiable(positions);
  }
}
