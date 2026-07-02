import '../commands/command.dart';
import '../construction/geo_object.dart';
import '../math/vec2.dart';

/// One user input delivered to the active tool — a tap (or click) on the
/// canvas, already hit-tested by the presentation layer.
///
/// [position] is the tap in world coordinates. [hit] is the topmost object
/// under the tap (by the hit tester's priority order), or null over empty
/// canvas. Tools decide what a hit means: a point tool refuses to stack a
/// point on an existing one, a midpoint tool consumes the hit point as its
/// next parent.
class ToolInput {
  const ToolInput(this.position, {this.hit});

  final Vec2 position;
  final GeoObject? hit;
}

/// What a tool did with one input; see [Tool.onInput].
sealed class ToolResult {
  const ToolResult();
}

/// The input was consumed but the tool needs more before it can build
/// anything (e.g. the first point of a two-point line). The tool's
/// in-progress state changed — preview watchers should repaint.
class ToolAccepted extends ToolResult {
  const ToolAccepted();
}

/// The input completed the tool's collection: execute [command] via the
/// command stack to realise the construction step. The tool has already
/// reset itself and is ready to collect the next round of inputs.
class ToolCommitted extends ToolResult {
  const ToolCommitted(this.command);

  final Command command;
}

/// The input is unusable in the tool's current state (e.g. a point tool
/// tapped an existing point). Nothing changed.
class ToolIgnored extends ToolResult {
  const ToolIgnored();
}

/// A construction tool: collects hit-tested inputs one tap at a time and,
/// once it has enough, emits a [Command] — tools never mutate the
/// construction directly.
///
/// Tools may hold in-progress state between [onInput] calls; [reset]
/// discards it (tool switch, cancel). After returning [ToolCommitted] a
/// tool must be back in its initial state, ready to build the next object
/// of its kind.
///
/// Hover previews (`onHover` in the PLAN sketch) are deliberately absent
/// until the first tool needs them (Phase 6).
abstract interface class Tool {
  ToolResult onInput(ToolInput input);

  /// Discards any partially-collected input. Must be safe to call at any
  /// time, including when nothing is collected.
  void reset();
}

/// Optional capability for multi-input tools: exposes the world positions
/// of the inputs collected so far, so the canvas can render in-progress
/// markers. Positions are read live — a collected existing point that
/// moves (or goes undefined and is skipped) is reflected on the next read.
abstract interface class ToolInputPreview implements Tool {
  /// One position per collected input still worth marking; empty when the
  /// tool is idle.
  List<Vec2> get previewPositions;
}
