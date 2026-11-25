import '../../math/vec2.dart';
import '../../projective/absolute.dart';
import '../../projective/space/section.dart';
import '../geo_object.dart';

/// The polygon in which [plane] cuts [solid] (intent 004, milestone 3).
///
/// A polygon **on the plane's sheet**: its vertices are in the plane's
/// own coordinates, so it is drawn, picked and measured as any polygon
/// in that plane is — the Area tool reads it with no change, because a
/// plane's coordinates are orthonormal and the shoelace sum in them is
/// the area in space.
///
/// Its side count is not fixed: it changes as the plane moves through
/// the solid's corners, and [polygonVertices] is rebuilt at every
/// recompute. The cut is exact (`sectionLoops`), so a plane through a
/// corner has that corner once and a plane that only touches the solid
/// has no section.
///
/// **One loop or nothing.** A solid that is not convex can be cut in
/// several pieces; a polygon is one loop, and an area that silently
/// read one piece of several would be a lie, so the section is then
/// undefined. Every solid over a convex base gives at most one.
class SectionPolygon extends GeoPolygon {
  SectionPolygon({
    required super.id,
    required this.plane,
    required this.solid,
    super.attributes,
  }) {
    recompute();
  }

  final GeoPlane plane;
  final GeoSolid solid;

  List<Vec2>? _vertices;

  @override
  List<Vec2>? get polygonVertices => _vertices;

  /// How many sides the section has now; 0 while there is none.
  int get sideCount => _vertices?.length ?? 0;

  @override
  Sheet get sheet => Sheet.of(plane);

  @override
  List<GeoObject> get parents => [plane, solid];

  @override
  void recompute([Absolute absolute = Absolute.euclidean]) {
    _vertices = null;
    final frame = plane.frame;
    final vertices = solid.spaceVertices;
    if (frame == null || vertices == null) {
      return;
    }
    final loops = sectionLoops(
      vertices,
      solid.faces,
      frame.origin,
      frame.normal,
    );
    if (loops.length != 1) {
      return;
    }
    _vertices = List.unmodifiable([
      for (final p in loops.single) frame.pull(p),
    ]);
  }
}
