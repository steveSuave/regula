import '../commands/command.dart';
import '../construction/geo_object.dart';
import '../math/vec2.dart';
import '../projective/absolute.dart';

/// One user input delivered to the active tool — a tap (or click) on the
/// canvas, already hit-tested by the presentation layer.
///
/// [position] is the tap in world coordinates. [hit] is the topmost object
/// under the tap (by the hit tester's priority order), or null over empty
/// canvas. Tools decide what a hit means: a point tool refuses to stack a
/// point on an existing one, a midpoint tool consumes the hit point as its
/// next parent.
///
/// [extraHits] carries the *other* objects within the hit threshold, in
/// the same (priority, distance) rank order, [hit] excluded — so point
/// resolution can notice a tap near the crossing of two curves even
/// though only one of them is topmost. [snapThreshold] is the hit
/// threshold in world units; intersection snapping never fires beyond it.
/// [objects] is the whole construction in insertion order, for tools that
/// must look beyond the tap — e.g. the transform tool reusing an
/// equivalent existing image instead of adding a duplicate.
/// [gridSnapStep] is the snap-to-grid spacing in world units (Phase 45),
/// 0 while snapping is off — the canvas supplies the same adaptive step
/// the grid draws at, and grid rounding is the resolution ladder's *last*
/// rung, so snapping to an existing point / curve / crossing always wins.
/// [viewExtent] is the visible world width (Phase 39), 0 when the caller
/// has no viewport — the locus tool bakes a line-host sampling window
/// from it. [text] carries dialog-entered content (Phase 58): the text
/// tool's canvas pre-gate collects the string *before* dispatching, so
/// the tool stays pure — a null [text] tells it the input wasn't meant
/// for it. The defaults (`const []`, `0`, `null`) make a bare
/// `ToolInput(pos, hit: x)` behave exactly as before the fields existed.
///
/// [absolute] is the **document's** geometry (Phase 126), read off
/// `Construction.kernel` by whoever builds the input. It lives here rather
/// than being reached for inside the tools because a tool is a pure
/// function of its input — and because what it decides is not cosmetic: a
/// tool that snaps to a crossing writes a `branchIndex`, which addresses
/// the candidate list *as filtered against the absolute* (Phase 125).
/// Building that address under the wrong geometry stores a number naming a
/// different crossing, which is the Phase 120c failure arriving through
/// the tool layer. The Euclidean default is what every document was before
/// this phase, and what a caller that means Euclidean should keep.
class ToolInput {
  const ToolInput(
    this.position, {
    this.hit,
    this.extraHits = const [],
    this.snapThreshold = 0,
    this.objects = const [],
    this.gridSnapStep = 0,
    this.viewExtent = 0,
    this.text,
    this.absolute = Absolute.euclidean,
    this.plane,
    this.spaceParameterOn,
    this.viewerSide = 1,
  });

  final Vec2 position;
  final GeoObject? hit;
  final List<GeoObject> extraHits;
  final double snapThreshold;
  final Iterable<GeoObject> objects;
  final double gridSnapStep;
  final double viewExtent;
  final String? text;
  final Absolute absolute;

  /// The active plane (intent 004, milestone 2): the plane [position] is
  /// a point of, in that plane's own coordinates, and the plane a new
  /// free point is placed in. Null is the base plane, which is every
  /// planar document and the default.
  final GeoPlane? plane;

  /// For a line drawn from its space value (an edge to a lifted point),
  /// the parameter in its `spaceParameterFrame` of the point of it drawn
  /// nearest the tap, or null when the tap cannot name one — the line is
  /// seen end-on (intent 004, milestone 3). [position] cannot say this:
  /// it is a point of the active plane, and such a line is in none. Null
  /// outside the space view, where nothing is drawn from a space value
  /// that a tap could miss the plane of.
  final double? Function(GeoLine line)? spaceParameterOn;

  /// Which side of the active plane the viewer is on: +1 for the side
  /// its normal points to, −1 for the other (intent 004, milestone 3).
  /// A solid built on the plane rises on this side, towards whoever is
  /// building it. +1 outside the space view.
  final double viewerSide;

  /// This input with its hits replaced: what the active plane's scope
  /// hands a tool once it has decided which hits the tool may see.
  ToolInput withHits(List<GeoObject> hits) => ToolInput(
    position,
    hit: hits.firstOrNull,
    extraHits: hits.length > 1 ? hits.sublist(1) : const [],
    snapThreshold: snapThreshold,
    objects: objects,
    gridSnapStep: gridSnapStep,
    viewExtent: viewExtent,
    text: text,
    absolute: absolute,
    plane: plane,
    spaceParameterOn: spaceParameterOn,
    viewerSide: viewerSide,
  );

  /// Every in-threshold candidate, best first: [hit] (when non-null)
  /// followed by [extraHits].
  List<GeoObject> get hits => [?hit, ...extraHits];
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

/// The input was refused, and the user should be told why: a tool that
/// decides for itself what the active plane admits (the solids, whose
/// base must lie in it) answers this where a planar tool is refused by
/// the plane's scope before it is asked. Nothing changed.
class ToolRefused extends ToolResult {
  const ToolRefused(this.reason);

  final ScopeRefusal reason;
}

/// Why an input was refused.
enum ScopeRefusal {
  /// The tapped object is not in the active plane by construction.
  notInPlane,
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
/// Hover previews (`onHover` in the DECISIONS sketch) are deliberately absent
/// until the first tool needs them (Phase 6).
abstract interface class Tool {
  ToolResult onInput(ToolInput input);

  /// Whether the tool holds partially-collected input — i.e. [reset]
  /// would discard something. Drives two-stage cancel (Phase 59): Esc and
  /// undo consume the pending input first (tool stays active), and only
  /// act at app level — deactivate / pop the stack — when this is false.
  /// Single-shot tools are always false; progress state that isn't
  /// awaiting completion (a naming cursor) doesn't count.
  bool get hasPartialInput;

  /// Discards any partially-collected input. Must be safe to call at any
  /// time, including when nothing is collected.
  void reset();
}

/// Optional capability for multi-input tools: exposes the inputs
/// collected so far, so the canvas can render in-progress feedback.
/// Everything is read live — a collected existing point that moves (or
/// goes undefined and is skipped) is reflected on the next read.
///
/// An input that resolved to an *existing* object goes in
/// [previewObjectIds] and is haloed like a selection; position-only
/// inputs and not-yet-committed snap points (`IntersectionPoint` /
/// `PointOnObject` — those objects don't exist yet) go in
/// [previewPositions] and keep the dot+ring marker.
abstract interface class ToolInputPreview implements Tool {
  /// One position per collected input still worth marking; empty when the
  /// tool is idle.
  List<Vec2> get previewPositions;

  /// Ids of existing objects consumed as inputs so far; empty when the
  /// tool is idle.
  List<String> get previewObjectIds;
}

/// What a tool wants of objects that are not on the active plane's sheet
/// (intent 004, milestone 2).
enum ToolScope {
  /// The tool builds in the active plane with the planar kernel. An
  /// object from elsewhere reaches it only if it lies in the plane by
  /// construction, and then through an adapter; anything else is
  /// refused. Every tool that predates space is this, and it is the
  /// default.
  plane,

  /// The tool builds from space values and takes whatever is tapped:
  /// segment, line, ray, midpoint and parallel, which need no plane, and
  /// the tools that build planes and what planes give.
  space,

  /// A [plane] tool that also takes a line drawn from its space value
  /// as it is: the Point tool, whose glued point lives on its host and
  /// needs no plane (intent 004, milestone 3).
  planeAndSpaceLines,
}

/// Optional capability: a tool whose commit leaves something for the
/// selection, and steps aside for it. A solid pulled up from its base
/// hands over the point it rose to, whose lift handle is how its height
/// is set (intent 004, milestone 3).
abstract interface class HandsOverSelection implements Tool {
  /// The id to select after the commit just made, once; null when that
  /// commit leaves nothing to select.
  String? takeSelection();
}

/// Optional capability: a tool that says which [ToolScope] it is. A tool
/// that does not is [ToolScope.plane].
abstract interface class ScopedTool implements Tool {
  ToolScope get scope;
}
