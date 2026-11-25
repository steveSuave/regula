import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/object_attributes.dart';
import '../construction/objects/section_polygon.dart';
import '../math/vec2.dart';
import 'tool.dart';

/// Section: a plane and a solid, in either order, give the polygon the
/// plane cuts the solid in (intent 004, milestone 3).
///
/// A plane's patch and a solid's faces are both regions, and one is
/// often in front of the other, so each tap is read for the kind still
/// missing among everything under it, not only for what is on top: a
/// tap on a patch seen through a cube takes the plane when the cube is
/// already held.
class SectionTool implements ToolInputPreview, ScopedTool {
  SectionTool({required this.newId});

  final String Function() newId;

  /// The fill a new section gets, so that it reads as a surface.
  static const double defaultFillAlpha = 0.35;

  @override
  ToolScope get scope => ToolScope.space;

  GeoPlane? _plane;
  GeoSolid? _solid;

  @override
  bool get hasPartialInput => _plane != null || _solid != null;

  @override
  List<Vec2> get previewPositions => const [];

  @override
  List<String> get previewObjectIds => [?_plane?.id, ?_solid?.id];

  @override
  ToolResult onInput(ToolInput input) {
    final hits = input.hits;
    final plane = hits.whereType<GeoPlane>().firstOrNull;
    final solid = hits.whereType<GeoSolid>().firstOrNull;
    if (_plane == null && _solid == null) {
      // Nothing held: what is on top decides.
      switch (hits.where((o) => o is GeoPlane || o is GeoSolid).firstOrNull) {
        case final GeoPlane first:
          _plane = first;
        case final GeoSolid first:
          _solid = first;
        default:
          return const ToolIgnored();
      }
      return const ToolAccepted();
    }
    if (_plane == null) {
      if (plane == null) {
        return const ToolIgnored();
      }
      _plane = plane;
    } else {
      if (solid == null) {
        return const ToolIgnored();
      }
      _solid = solid;
    }
    final cutting = _plane!;
    final cut = _solid!;
    reset();
    // The same cut twice is one section.
    if (input.objects.any(
      (o) =>
          o is SectionPolygon &&
          identical(o.plane, cutting) &&
          identical(o.solid, cut),
    )) {
      return const ToolIgnored();
    }
    return ToolCommitted(
      AddObjectCommand(
        SectionPolygon(
          id: newId(),
          plane: cutting,
          solid: cut,
          attributes: const ObjectAttributes(fillAlpha: defaultFillAlpha),
        ),
      ),
    );
  }

  @override
  void reset() {
    _plane = null;
    _solid = null;
  }
}
