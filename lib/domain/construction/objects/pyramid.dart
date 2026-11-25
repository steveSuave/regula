import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../geo_object.dart';
import '../space_incidence.dart';

/// The pyramid over the loop [base] with [apex] (intent 004, milestone
/// 3): the base and one triangle per base side.
///
/// **A base of four or more needs a plane.** [plane] is the plane the
/// base was drawn in, null for the base plane, and the pyramid is
/// defined only while every base vertex is in it — on its sheet with a
/// value there, or by construction. Lift one base vertex and the base is
/// no longer a face, so there is no solid; its edges, which are segments
/// of their own, stay. A base of three is a triangle wherever its
/// corners are, so a pyramid on three points and an apex is any four
/// points of space and asks for no plane.
///
/// Vertices are the base in order, then the apex. Face 0 is the base;
/// face `i + 1` is the side over base edge `i`.
class Pyramid extends GeoSolid {
  Pyramid({
    required super.id,
    required List<GeoPoint> base,
    required this.apex,
    this.plane,
    super.attributes,
  }) : base = List.unmodifiable(base) {
    if (base.length < 3) {
      throw ArgumentError.value(
        base.length,
        'base',
        'A pyramid needs at least 3 base vertices',
      );
    }
    final n = base.length;
    faces = List.unmodifiable([
      List<int>.unmodifiable([for (var i = 0; i < n; i++) i]),
      for (var i = 0; i < n; i++) List<int>.unmodifiable([i, (i + 1) % n, n]),
    ]);
    edges = List.unmodifiable([
      for (var i = 0; i < n; i++) (i, (i + 1) % n),
      for (var i = 0; i < n; i++) (i, n),
    ]);
    recompute();
  }

  final List<GeoPoint> base;
  final GeoPoint apex;

  /// The plane of the base, or null for the base plane. Not read for a
  /// base of three.
  final GeoPlane? plane;

  @override
  late final List<List<int>> faces;

  @override
  late final List<(int, int)> edges;

  List<Vec3>? _vertices;

  @override
  List<Vec3>? get spaceVertices => _vertices;

  @override
  List<GeoObject> get parents => [...base, apex, ?plane];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    _vertices = null;
    final positions = solidBasePositions(base, plane);
    final top = apex.spacePosition;
    if (positions == null || top == null) {
      return;
    }
    _vertices = List.unmodifiable([...positions, top]);
  }
}

/// The space positions of a solid's [base], or null when one has none
/// or — for a base of four or more — is not in [plane]. Shared by the
/// solids that stand on a base polygon.
List<Vec3>? solidBasePositions(List<GeoPoint> base, GeoPlane? plane) {
  final needsPlane = base.length > 3;
  final positions = <Vec3>[];
  for (final vertex in base) {
    final at = vertex.spacePosition;
    if (at == null || (needsPlane && !inPlaneOrSheet(vertex, plane))) {
      return null;
    }
    positions.add(at);
  }
  return positions;
}
