import '../../math/vec2.dart';
import '../../math/vec3.dart';
import '../../projective/absolute.dart';
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
///
/// Migrated (Phase 112): reads the vertices' projective views and
/// projects them into the chart itself — the outline is a chart drawable
/// (the metric boundary). A vertex that is complex or at infinity leaves
/// the polygon undefined; there is no partial outline.
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
  List<Vec3>? _spaceVertices;

  @override
  List<Vec2>? get polygonVertices => _polygonVertices;

  /// Whether the vertices have no common value in the sheet, so there is
  /// no planar loop and the space one stands in (intent 004, milestone
  /// 3). A vertex at infinity or complex in its sheet is not this: the
  /// polygon stays undefined, as it always was.
  bool get _offSheet =>
      !sheet.exists || vertices.any((vertex) => vertex.projPoint == null);

  /// A polygon needs no plane: when its vertices have no common value in
  /// one sheet (one is lifted, or they sit in different planes) the loop
  /// is their space positions.
  @override
  List<Vec3>? get spaceVertices =>
      _offSheet ? _spaceVertices : super.spaceVertices;

  @override
  List<GeoObject> get parents => vertices;

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    _spaceVertices = null;
    if (_offSheet) {
      _polygonVertices = null;
      final positions = <Vec3>[];
      for (final vertex in vertices) {
        final position = vertex.spacePosition;
        if (position == null) {
          return;
        }
        positions.add(position);
      }
      _spaceVertices = List.unmodifiable(positions);
      return;
    }
    final positions = <Vec2>[];
    for (final vertex in vertices) {
      final position = vertex.projPoint?.toVec2();
      if (position == null) {
        _polygonVertices = null;
        return;
      }
      positions.add(position);
    }
    _polygonVertices = List.unmodifiable(positions);
  }
}
