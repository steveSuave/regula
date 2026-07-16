import '../commands/add_object_command.dart';
import '../construction/geo_object.dart';
import '../construction/objects/locus.dart';
import '../construction/objects/point_on_object.dart';
import '../math/vec2.dart';
import 'tool.dart';

/// Two taps trace a locus: first the *driver* — a `PointOnObject`, the
/// only kind with a sweepable parameter — then the *traced* point, any
/// point that (transitively) depends on the driver. One
/// `AddObjectCommand`; no points are ever created, so taps that don't
/// resolve are ignored (a curve tap, an independent point, the driver
/// itself as tap 2). The collected driver is haloed, never marked with a
/// temporary dot — it exists already (the Phase 29 convention).
///
/// For a line-hosted driver the sampling window is baked here, at
/// creation: centered on the driver's current parameter, spanning the
/// visible world width (`ToolInput.viewExtent`) to each side, falling
/// back to 100 world units when the caller has no viewport. Circle
/// hosts sweep one full turn and take the `Locus` defaults.
class LocusTool implements Tool, ToolInputPreview {
  LocusTool({required this.newId});

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  PointOnObject? _driver;

  @override
  List<Vec2> get previewPositions => const [];

  @override
  List<String> get previewObjectIds => [?_driver?.id];

  @override
  ToolResult onInput(ToolInput input) {
    final driver = _driver;
    if (driver == null) {
      final hit = input.hits.whereType<PointOnObject>().firstOrNull;
      if (hit == null) {
        return const ToolIgnored();
      }
      _driver = hit;
      return const ToolAccepted();
    }
    final traced = input.hits.whereType<GeoPoint>().firstOrNull;
    if (traced == null ||
        identical(traced, driver) ||
        !_reachesDriver(traced, driver)) {
      return const ToolIgnored();
    }
    final halfSpan = input.viewExtent > 0 ? input.viewExtent : 100.0;
    reset();
    return ToolCommitted(
      AddObjectCommand(
        Locus(
          id: newId(),
          driver: driver,
          traced: traced,
          center: driver.parameter,
          halfSpan: halfSpan,
        ),
      ),
    );
  }

  @override
  void reset() {
    _driver = null;
  }

  /// The constructor's dependency walk, run before building so a
  /// non-tracing tap is ignored instead of throwing.
  static bool _reachesDriver(GeoObject object, PointOnObject driver) =>
      identical(object, driver) ||
      object.parents.any((parent) => _reachesDriver(parent, driver));
}
