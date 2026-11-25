import '../../math/vec3.dart';
import '../../projective/absolute.dart';
import '../geo_object.dart';
import 'pyramid.dart';

/// The prism over the loop [base] whose first vertex has [top] above it
/// (intent 004, milestone 3): two ends and one parallelogram per base
/// side.
///
/// The other end is the base moved by the vector from `base[0]` to
/// [top], computed here. The tool that builds a prism also adds a
/// `TranslatedPoint` per corner of that end, for edges and labels to
/// attach to; those points and these vertices agree by construction,
/// and deleting one of the points changes nothing about the solid.
///
/// Right or oblique is a matter of what [top] is: a `RaisedPoint` over
/// `base[0]` gives a right prism that stays right, a
/// `ProportionalRaisedPoint` over a square gives a cube, and any other
/// point of space gives the oblique prism to it.
///
/// A base of four or more needs a plane, as for a `Pyramid`.
///
/// Vertices are the base in order, then the other end in the same
/// order. Face 0 is the base, face 1 the other end, and face `i + 2`
/// the side over base edge `i`.
class Prism extends GeoSolid {
  Prism({
    required super.id,
    required List<GeoPoint> base,
    required this.top,
    this.plane,
    super.attributes,
  }) : base = List.unmodifiable(base) {
    if (base.length < 3) {
      throw ArgumentError.value(
        base.length,
        'base',
        'A prism needs at least 3 base vertices',
      );
    }
    final n = base.length;
    faces = List.unmodifiable([
      List<int>.unmodifiable([for (var i = 0; i < n; i++) i]),
      List<int>.unmodifiable([for (var i = 0; i < n; i++) n + i]),
      for (var i = 0; i < n; i++)
        List<int>.unmodifiable([i, (i + 1) % n, n + (i + 1) % n, n + i]),
    ]);
    edges = List.unmodifiable([
      for (var i = 0; i < n; i++) (i, (i + 1) % n),
      for (var i = 0; i < n; i++) (n + i, n + (i + 1) % n),
      for (var i = 0; i < n; i++) (i, n + i),
    ]);
    recompute();
  }

  final List<GeoPoint> base;

  /// The corner of the other end that stands over `base[0]`.
  final GeoPoint top;

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
  List<GeoObject> get parents => [...base, top, ?plane];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    _vertices = null;
    final positions = solidBasePositions(base, plane);
    final over = top.spacePosition;
    if (positions == null || over == null) {
      return;
    }
    final shift = over - positions.first;
    _vertices = List.unmodifiable([
      ...positions,
      for (final at in positions) at + shift,
    ]);
  }
}
