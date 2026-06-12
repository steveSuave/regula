import '../../math/vec2.dart';
import '../geo_object.dart';

/// A user-placed point — the only directly mutable object in the graph.
///
/// Everything else derives from free points; dragging one and recomputing
/// its transitive dependents is the app's core interaction.
class FreePoint extends GeoPoint {
  FreePoint({required super.id, required Vec2 position, super.attributes})
      : _position = position;

  Vec2 _position;

  @override
  Vec2 get position => _position;

  /// Mutated only by `Construction.moveFreePoint` (via commands) so every
  /// move goes through dependent recomputation.
  set position(Vec2 value) => _position = value;

  @override
  List<GeoObject> get parents => const [];

  @override
  void recompute() {
    // Free points are roots: nothing to derive.
  }
}
