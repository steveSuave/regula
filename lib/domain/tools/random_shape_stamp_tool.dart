import 'dart:math' as math;

import '../commands/add_object_command.dart';
import '../commands/command.dart';
import '../commands/macro_command.dart';
import '../construction/objects/free_point.dart';
import '../construction/objects/segment.dart';
import '../math/vec2.dart';
import 'tool.dart';

/// One tap stamps a randomized simple polygon around it: between
/// [minVertices] and [maxVertices] *free* points at sorted random angles
/// and jittered radii (sorted angles keep the outline from
/// self-intersecting), joined by segments — one `MacroCommand`, fully
/// editable afterwards. Backs the "random triangle" (3–3) and "random
/// polygon" (4–7) menu items.
///
/// The tap never consumes or glues to existing objects — a stamp is new
/// geometry by definition. The stamp radius scales with the input's snap
/// threshold (≈10× ≈ 80 screen px at any zoom), falling back to 80 world
/// units when the threshold is 0. [random] is injectable so tests are
/// deterministic.
class RandomShapeStampTool implements Tool {
  RandomShapeStampTool({
    required this.newId,
    required this.minVertices,
    required this.maxVertices,
    math.Random? random,
  })  : assert(minVertices >= 3, 'a polygon needs at least 3 vertices'),
        assert(minVertices <= maxVertices, 'empty vertex-count range'),
        _random = random ?? math.Random();

  /// Produces a fresh unique object id per call (see `PointTool.newId`).
  final String Function() newId;

  final int minVertices;
  final int maxVertices;
  final math.Random _random;

  @override
  ToolResult onInput(ToolInput input) {
    final count = minVertices + _random.nextInt(maxVertices - minVertices + 1);
    final radius = input.snapThreshold > 0 ? input.snapThreshold * 10 : 80.0;
    final angles = List.generate(
      count,
      (_) => _random.nextDouble() * 2 * math.pi,
    )..sort();
    final vertices = [
      for (final angle in angles)
        FreePoint(
          id: newId(),
          position: input.position +
              Vec2(math.cos(angle), math.sin(angle)) *
                  (radius * (0.5 + 0.5 * _random.nextDouble())),
        ),
    ];
    final commands = <Command>[
      for (final vertex in vertices) AddObjectCommand(vertex),
      for (var k = 0; k < count; k++)
        AddObjectCommand(
          Segment(
            id: newId(),
            point1: vertices[k],
            point2: vertices[(k + 1) % count],
          ),
        ),
    ];
    return ToolCommitted(MacroCommand(commands));
  }

  @override
  void reset() {}
}
