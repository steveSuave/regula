# Dynamic Geometry App in Flutter

## Context

Build a cross-platform (web, Android, iOS) dynamic geometry application from scratch in an empty repo. The app is a constructive geometry tool: the user drops free points and builds derived objects (lines, circles, intersections, midpoints, triangle centers, …) on top of them. Dragging a free point must propagate updates to every dependent object correctly and instantly. The project will live in `$HOME/Code/var/regula/`.

Decisions confirmed up front:

- **State management:** Riverpod.
- **Persistence:** Local JSON files only (via `file_picker` — works on web via download/upload, on mobile via the native picker).
- **Undo/redo:** Full Command-pattern undo/redo.
- **Testing:** Unit + property-based + widget + golden tests.

The fundamental abstraction is a **construction graph**: a DAG of geometric objects where every derived object is a pure function of its parents. Free points are the only mutable roots. The same graph powers rendering, hit testing, undo/redo, and save/load.

## Architecture

### Layer separation

```
lib/
├── domain/          # Pure Dart, no Flutter imports — fully unit-testable
│   ├── math/        # Vec2, line/circle primitives, intersections, predicates
│   ├── construction/# GeoObject hierarchy + Construction (the DAG)
│   ├── tools/       # Tool state machines
│   └── commands/    # Undo/redo command interface + concrete commands
├── application/     # Riverpod providers, controllers, persistence I/O
│   ├── providers/
│   └── persistence/
├── presentation/    # Flutter widgets, painters, theme
│   ├── canvas/
│   ├── panels/      # toolbar, tool palette, attributes inspector, object tree
│   └── theme/
└── main.dart
```

The `domain/` layer must not import `package:flutter/*`. This is the boundary that makes the math testable without a widget tester and reusable across platforms.

### Construction graph (`domain/construction/`)

- `sealed class GeoObject` with `id`, `parents`, `attributes: ObjectAttributes`, and `void recompute()`. Sealing is at the *kind* level: `GeoPoint` / `GeoLine` / `GeoCircle` / `GeoAngle` are the sealed branches, concrete objects extend an open kind — Dart requires a sealed class's direct subtypes in the same library, which one-file-per-object rules out on the root. Kind switches are exhaustive; concrete-type switches are not.
- Kinds are *value shapes*, not visual shapes. A kind's geometry accessor is what intersection math and hit testing consume: `GeoPoint.position`, `GeoLine.line` (carrier `LineEq` — segments and rays reuse line∩x math through it, with extent clamps at the painter/hit-tester), `GeoCircle.circle` (carrier `CircleEq` — arcs and sectors reuse circle∩x math the same way, with *angular* extent clamps), `GeoAngle.angle` (an `AngleGeometry`: vertex, unit start direction, CCW sweep in [0, 2π) — angles are decorations plus a measure; nothing intersects them). Phases 37–39 add three more kinds that likewise take part in no intersection math: `GeoPolygon.polygonVertices` (the filled region's vertex loop), `GeoMeasurement.value`/`anchor` (a live number displayed as canvas text), and `GeoLocus.samples` (a sampled trace polyline; null entries mark gaps where the traced point was undefined). Every new kind must add its case to the eight exhaustive kind switches: painter `_drawObject`/`_drawFill`, hit tester (priority / band containment / distance), `label_anchor`, `fit_viewport`, `object_naming`, tree grouping, `object_kind_label`, codec.
- `parents` is a getter derived from typed parent fields (e.g. `Midpoint` holds `GeoPoint point1, point2`), so ill-typed constructions are unrepresentable rather than runtime errors.
- Derived objects support an *undefined* state (degenerate parent configuration — coincident points defining a line, curves that stopped intersecting mid-drag). Undefined objects stay in the graph, are skipped by painter/hit-tester, and recover when the degeneracy passes.
- Subclasses (one file each, grouped by kind):
  - **Points:** `FreePoint`, `PointOnObject` (constrained to a curve), `IntersectionPoint`, `Midpoint`, `Centroid`, `Orthocenter`, `Incenter`, `Circumcenter`, `SegmentRatioPoint`, and the four transformations (Phase 15): `ReflectedPoint` (about a line), `CentralReflectionPoint` (about a point), `RotatedPoint` (about a center by a fixed angle in radians, CCW), `TranslatedPoint` (by the live vector between two points) — ordinary derived points, so recompute, persistence and hit testing work unchanged.
  - **Lines:** `LineThroughTwoPoints`, `Segment`, `Ray`, `PerpendicularLine`, `ParallelLine`, `AngleBisectorLine`, `TwoLineBisectorLine` *(Phase 29b: two `GeoLine` parents plus a `branch` param 0/1 — two lines have two bisectors, a perpendicular pair through their intersection; the branch is baked at creation from the two tap positions, picking the bisector of the tapped wedge — direction `d̂1 + s·d̂2` with `s = +1` for branch 0, `−1` for branch 1; undefined while the carriers are parallel or a parent is undefined, recovers)*, plus (Phase 33): `PerpendicularBisectorLine` (two point parents; carrier through their midpoint, perpendicular to the join — a dedicated kind on the `AngleBisectorLine` precedent rather than a hidden Midpoint + PerpendicularLine macro, single-valued and continuous; undefined while the points coincide) and `TangentLine` (point + circle parents plus a `branch` param 0/1; both branches go undefined together while the point is strictly inside the circle and recover with sides preserved — the branch order is left/right of the center→point line, see `tangents.dart`; on the circle both branches collapse to the tangent at the point; the carrier is built point-direction through the tangent point perpendicular to the radius, which stays well-conditioned near the rim where a through-points form would degenerate).
  - **Circles & arcs:** `CircleCenterPoint`, `ThreePointCircle`, `CompassCircle` (two points defining radius + center), `Arc` (through three points: endpoints first and last, the arc is the carrier branch containing the middle point; undefined while collinear), `Sector` (center + rim point fixing radius and start angle + a third point fixing only the end angle; sweep is CCW from start to end), and (Phase 34) `FixedRadiusCircle` (center parent + a numeric `radius` param; constructor rejects non-positive/non-finite — serves the circle-by-radius tool directly and doubles as the segment-by-length macro's hidden circle).
  - **Angles:** `VertexAngle` (arm–vertex–arm points; sweep is CCW from the first arm's ray to the second's, so the two tap orders give the two complementary markers) and `LineAngle` (between two lines; vertex at the intersection, undefined while parallel). `LineAngle` originally always folded to the acute/right angle in (0, π/2]; from Phase 31 the marked wedge **follows the taps**: each tap picks the half of its line nearer the tap, giving half-directions d1′/d2′, and the wedge between rays(d1′, d2′) has sweep in (0, π) (start = whichever direction makes the CCW sweep < π) — so tapping with the obtuse pair between the taps yields the obtuse marker, and the right-angle square lands in the chosen quadrant instead of under the lines. The choice persists as two **sign flips relative to the canonical carrier directions** (baked at creation from the tap positions, so the wedge follows drags continuously; codec `params`, additive, no version bump). **Absent params = legacy always-acute mode**, so old saves decode and render byte-identically.
  - **Polygons (Phase 37):** `Polygon` — the first variable-arity object: `final List<GeoPoint> vertices` (≥ 3, constructor-enforced; the list is fixed for the object's lifetime, and `parents => vertices` keeps the typed-parents rule intact). Undefined when any vertex is; collinear/self-intersecting stays *defined* (it's a drawable outline — area math handles it in Phase 38). Draws its own closed outline and fill, deliberately emitting **no Segment edges**: the shape *macros* stay segment-based editable compositions, while `Polygon` is a single first-class region — which avoids N redundant objects per polygon and makes Phase 38's area target unambiguous. Migrating the macros onto `GeoPolygon` is explicitly out of scope. The tool bakes `fillAlpha: 0.25` into the created object (the attribute *default* stays null, so nothing else changes).
  - **Measurements (Phase 38):** `DistanceMeasurement` (two point parents; value = their distance, anchor = the midpoint; point–line distance deferred v1) and `AreaMeasurement` (a single `GeoObject subject` parent, constructor-enforced `GeoPolygon` or `GeoCircle` — the `PointOnObject.curve` precedent, so ill-typed saves normalize to `FormatException`; value = |shoelace signed area| or πr², anchor = vertex average / circle center). Measurements render as text only, riding the label machinery (see Canvas), so text dragging, `labelFontSize` presets and color styling come free.
  - **Loci (Phase 39):** `Locus` — parents `PointOnObject driver` + `GeoPoint traced` (the constructor validates by a pure parent-graph walk that `traced` transitively depends on `driver`); params `sampleCount` (default 128) plus, for line hosts, `center`/`halfSpan`. **Recompute is sweep-and-restore** over a `_chain` computed once at construction (the transitive ancestors of `traced` that themselves depend on `driver`, plus both endpoints, topologically ordered by post-order DFS over parent links): save `driver.parameter`, for each sample set it, recompute the chain in order, record `traced.position`; then restore the saved parameter and recompute the chain once. This is safe against every invariant: `GeoObject.recompute` never notifies (`Construction`'s single notification fires after the whole topological pass the locus runs inside), the restore is bit-exact because chain members are pure functions of parents + parameter, the locus sits after its ancestors in topological order so the chain has already settled before being perturbed, and a chain can never contain another locus (`PointOnObject` rejects non-line/circle hosts). A pleasing consequence: *sliding the driver does not change the locus* — the sweep domain is fixed. Sampling domain: circle host = one full closed turn; line host = `[center − halfSpan, center + halfSpan]` **baked at creation** (center = the driver's parameter, halfSpan = the visible world width via the additive `ToolInput.viewExtent`, fallback 100) — the locus sibling of `PointOnObject`'s analytic-parameter caveat. 128 uniform samples, no adaptivity v1; undefined samples become nulls → gaps in the polyline. Perf note: a drag frame costs sampleCount × chain-length recomputes — fine for realistic chains, revisit if manual testing disagrees.
- `class Construction` owns the DAG: insertion-ordered map of objects (insertion order doubles as topological order), topological recompute on dirty propagation, dependents lookup for cascading delete. It is pure Dart with a minimal hand-rolled listener API — *not* a Flutter `ChangeNotifier` (the domain layer must not import Flutter, and `ChangeNotifierProvider` is the legacy path in Riverpod 3 anyway). The application layer wraps it in a `@riverpod` `Notifier` that re-exposes state after each command. If that notifier ends up being the only listener by Phase 4, drop the listener API.
- `class ObjectAttributes`: `name`, `colorArgb` (raw ARGB int, `null` = theme default — the domain layer can't use Flutter's `Color`; presentation maps it), `visible`, `labelVisible`, `labelDx`/`labelDy` (label offset from the object's anchor in *screen* logical px so zoom never flings labels; defaults 6/−18 match the pre-Phase-17 hardcoded offset), `strokeWidth`, `dashPeriod` (0 = solid, > 0 = dashed with that period in logical px, dash = gap = period/2), `angleMarkerRadius` *(Phase 22 — angle-marker radius in screen px, default 20 = the pre-22 painter constant)*, `labelFontSize` *(Phase 28 — label size in logical px, default 12 = the pre-28 `label_layout.dart` constant; read by both `_drawLabel` and the shared `labelScreenRect` so paint and hit rect can't drift)*, `showValue` *(Phase 35 — default false; a segment appends its length and an angle its degree measure to its label; independent of `labelVisible`, which gates only the name part — composition rules under Canvas)*, plus per-type extras (point size, fill alpha — `fillAlpha` applies to sectors *and*, from Phase 22, to angle-marker wedges). Built with `freezed` for immutability + `copyWith`. All attribute fields are additive with defaults, so new ones need no save-format version bump.
- **Automatic naming (Phase 23).** New objects get an auto-name at creation: points `A…Z, A1…`; lines *and circles* share one lowercase pool `a…z, a1…`; angles `α…ω, α1…`. The allocator is a pure domain function (`domain/construction/object_naming.dart`, `nextAutoName(usedNames, object)`) doing a first-free scan over the names already in the construction — so deleted names are reused, File > Open just works (the scan sees whatever the file brought), and nothing keys off ids (uuid.v4 has no order). It runs in a single interceptor in `ToolNotifier.handleInput` — the one funnel every `AddObjectCommand` passes through — recursing into `MacroCommand.commands` and naming only objects with an empty name **and** `visible: true` (macro scaffolding is invisible, so it burns no letters). Because `AddObjectCommand` holds the object instance and redo re-adds it, a name baked in before the first apply is undo/redo-stable with no extra command state. Display convention: points and angles keep `labelVisible: true` (canvases show A, B, C by default); lines and circles are named but get `labelVisible: false` at assignment — the name shows in the tree/inspector, not on the canvas, until the user reveals it. Manual renames stay free-form; the allocator just skips whatever exists — except clashes (Phase 27): renaming to a taken name evicts the old holder to a numbered variant (pure helper beside `nextAutoName`), both renames in one multi-id `ChangeAttributesCommand` (the command already batches ids — no `MacroCommand` needed), so names stay unique without ever rejecting the user's chosen name. Phases 37–39: polygons, measurements and loci join the lowercase line/circle pool; polygons and loci get `labelVisible: false` at assignment like the other curves, while **measurements keep `labelVisible: true`** — their whole point is the on-canvas text, which reads best as `a = 3.42`.

### Pure math (`domain/math/`)

- `Vec2` with the usual ops, `dot`, `cross`, `norm`, `distanceTo`.
- `LineEq` / `CircleEq` value types for analytic forms.
- `intersections.dart`: line∩line, line∩circle, circle∩circle returning `List<Vec2>` (0/1/2). Each intersection object carries an `index` so the user's chosen branch is stable across drags.
- Caveat: the index is *deterministic*, not *continuous*. Line∩circle branches are ordered along the line's direction, so dragging a defining point past the other reverses the direction and the two branches visibly swap. Known wart, not a bug. If it bothers in Phase 5/6 manual testing, layer a runtime continuity heuristic (prefer the candidate nearest the previous position) on top — but the *persisted* branch stays the index; continuity is path-dependent and must never leak into the save format.
- `triangle_centers.dart`: closed-form centroid, orthocenter, incenter, circumcenter.
- `angle_geometry.dart`: `AngleGeometry` value type (vertex, unit start direction, CCW sweep) plus angle helpers — `ccwSweep(from, to)` in [0, 2π), and the arc-branch pick `sweepThrough(start, via, end)` (signed sweep from start to end passing via; feeds `Arc`).
- `tangents.dart` *(Phase 33)*: `tangentPointsToCircle(external, circle)` → 0/1/2 tangent points, built as the Thales circle over center–external ∩ the given circle (reusing `intersectCircleCircle`). That choice buys branch stability for free: the branch order is left/right of the directed center→point line, which is continuous under any drag of the external point — none of the line∩circle direction-reversal wart. On-circle → the point itself; strictly inside or degenerate radius → empty.
- `polygon_math.dart` *(Phase 38)*: `polygonSignedArea(List<Vec2>)` — shoelace, positive CCW. Consumers take the absolute value; a self-intersecting loop gets the shoelace absolute value (documented, GeoGebra-compatible enough).
- All functions are pure, take `Vec2`s, and have epsilon-tolerant predicates (`isParallel`, `isCollinear`).

### Tool system (`domain/tools/`)

- `abstract class Tool { ToolState onTap(...); ToolState onHover(...); Command? complete(...); }`
- One subclass per tool: `PointTool`, `LineThroughTwoPointsTool`, `MidpointTool`, `IntersectionTool`, `ThreePointCircleTool`, `AngleBisectorTool`, `CompassTool`, `SegmentRatioTool`, `SquareMacroTool`, `ParallelogramMacroTool`, `TrapeziumMacroTool`, `VisibilityTool` *(Phase 30)*, etc.
- A tool collects N hit-tested inputs (existing objects or new points), then emits a `Command`. Snap-to-object during input collection.
- **In-progress input display (Phase 29):** a tool input that resolved to an *existing* object is shown by drawing the selection-style halo on that object, not by dropping a temporary point marker on it. `ToolInputPreview` gains `previewObjectIds: List<String>` (default empty) beside `previewPositions`; `TwoLineTool` (which used to preview its first tap projected onto the line), `PointAndLineTool`, `TransformObjectTool`, `IntersectionTool` and `MultiPointTool`-when-the-ladder-reused-an-existing-point report ids, while position-only taps and not-yet-committed `IntersectionPoint`/`PointOnObject` snaps keep the dot+ring marker (those objects don't exist yet). The painter draws the ids with the existing halo pass (union with the selection).
- **Angle tools without by-product points (Phase 29b, user feedback on 29):** Phase 29 haloed *reused* inputs, but a tap on a curve still ran the Phase 20 ladder and permanently glued a `PointOnObject` — for the angle-shaped tools users read those as fake points that shouldn't outlive the gesture. Two changes, deliberately scoped to the angle tools only (for segments/circles/macros the gluing is a feature). **(1) Angle bisector** becomes a dedicated two-mode `AngleBisectorTool` (`domain/tools/angle_bisector_tool.dart`): the first tap decides — a line hit enters **two-line mode** (second line commits one `AddObjectCommand` of a `TwoLineBisectorLine.near(...)`, both lines haloed, zero points created; the GeoGebra two-line bisector, except we create only the tapped wedge's bisector — tap the other wedge for the other one); a point hit or empty canvas enters **point mode**, the old three-point flow except curve taps are *ignored* instead of gluing (existing points reuse + halo, empty canvas still drops free points). Modes don't mix: point taps in line mode and line taps in point mode are ignored. **(2) Angle at vertex** keeps its `ThreePointTool` but with a new `allowCurveTaps: false` flag on `MultiPointTool`: a tap whose hit set contains an in-threshold curve (and no point) is refused — no gluing, no crossing snap, no free point half-on-a-line; the two-line case is what Angle-between-lines is for. `TwoLineBisectorLine` is excluded from Phase 24 whole-object transforms like the other non-point-parent lines. one `VisibilityTool` (`domain/tools/visibility_tool.dart`) with two named-constructor variants (the `TransformObjectTool` precedent), replacing the old `H` hide-selection / `Shift+H` reveal-all actions. **Hide** (`H`): each tap on a visible object emits one `ChangeAttributesCommand` setting `visible: false` — the object disappears immediately; empty-canvas taps do nothing. **Show/Hide** (`Shift+H`): while active, hidden objects render *dimmed* (~35 % opacity, labels included) and are hit-testable, and each tap *toggles* the hit object's `visible` flag — a dimmed object reappears, tap again re-hides. Every tap = one command = one undo step. `Esc`/`V` deactivate like any tool; no toolbar flyout entry v1 (mobile keeps the object-tree per-row eyes); the inspector's Visible checkbox and the tree eyes remain the selection-based paths.
- **Unified point resolution (Phase 20):** every tap that a tool turns into a point goes through one shared ladder (`domain/tools/point_resolution.dart`): existing point within threshold → reuse it; two curves whose intersection branch is within threshold → new `IntersectionPoint` at the nearest branch; one curve within threshold → new `PointOnObject` glued to it; otherwise → new `FreePoint`. Used by `PointTool` and `MultiPointTool.collectVertex`, so the point tool, line/segment/circle, midpoint, angle bisector, transforms and macros all snap identically. The standalone Point-on-object tool is retired (subsumed by the smart Point tool). Deliberate consequence: a free point can no longer be dropped *exactly on* a curve — the tap glues instead; place off-curve and drag if a coincident-but-free point is really wanted. `ToolInput` carries the ranked in-threshold candidates (`extraHits`) plus the world-space `snapThreshold`; tools built to consume curves directly (perpendicular/parallel, angle-between-lines, intersection) are unaffected.
- Planned tool additions (Phases 13–16): `IntersectionTool` *(landed, Phase 13)* — pick two curves; creates the `IntersectionPoint` branch nearest the *second* tap, resolved by probing both branch objects so the choice rides the documented deterministic branch order; non-intersecting curves still commit branch 0 (undefined until dragged together). Transformation tools *(landed, Phase 15)* — reflect-about-line reuses `PointAndLineTool` (point + line in either order), reflect-about-point reuses `TwoPointTool` and translate reuses `ThreePointTool` (tap the point first, then the center / the vector's tail and tip), rotation is a small `RotatedPointTool` over `MultiPointTool` capturing its angle from a degrees dialog like the segment-ratio tool (a `TwoPointTool` closure would defeat the toolbar's builder-tear-off highlight), `AngleBySizeTool` *(landed, Phase 16)* — arm point, vertex, size dialog → a `RotatedPoint` plus a `VertexAngle` (GeoGebra convention; a negative size swaps the marker's arms so it measures |size| clockwise), and macro tools for equilateral / isosceles / right / random triangles and random / regular polygons (regular-polygon side count via dialog; "random" macros stamp randomized *free* points, fully editable afterwards).
- Macro tools (square, parallelogram, trapezium) are scripted compositions of primitive commands wrapped in a single undoable `MacroCommand`. Derived corners come from *hidden* scaffolding objects over the visible sides (perpendiculars + compass circles for the square, parallels for the parallelogram and trapezium), so macros introduce no new object kind — codec, painter and hit tester are untouched. Input schemes: **square** = 2 taps, adjacent corners A, B; the shape lies to the *left* of A→B (branch 1 of line∩circle along the perpendicular's direction — the AB carrier's CCW normal — which follows the points continuously, so the side never flips mid-drag). **Parallelogram** = 3 taps, consecutive corners A, B, C; D = A + (C − B) as the single-branch intersection of two hidden parallels. **Trapezium** = 3 taps for consecutive corners A, B, C plus a 4th *position-only* tap that places D as a `PointOnObject` projected onto the hidden parallel-to-AB through C — direct manipulation instead of a ratio dialog; AB ∥ CD by construction, and D inherits `PointOnObject`'s analytic-parameter caveat (translating the parallel along itself leaves D in place). The 4th tap never consumes an existing point — D must stay constrained to the parallel.
- **Whole-object transforms (Phase 24).** The four Phase 15 transforms extend from points to whole curves by *macro composition*: the image of a curve is the **same kind rebuilt over transform-point images of its defining points**, all in one `MacroCommand` — no new `GeoObject` kinds, so codec, painter and hit tester are untouched, and since all four transforms are isometries the image is automatically congruent (a rebuilt `CircleCenterPoint(image(center), image(rim))` has the right radius). Supported sources v1: every curve whose parents are all `GeoPoint`s — `Segment`, `Ray`, `LineThroughTwoPoints`, `CircleCenterPoint`, `CompassCircle`, `ThreePointCircle`, `Arc`, `VertexAngle`, and `Sector` except under reflect-about-line. The parents may themselves be derived points (transform kinds accept any `GeoPoint`), so the image tracks the source's full ancestry live with no recursion. `PerpendicularLine`/`ParallelLine`/`AngleBisectorLine`/`LineAngle`/`PointOnObject` (non-point parents) are excluded v1 — the tap is ignored; the future extension is object-level recursion (isometries preserve perpendicularity/parallelism/bisection, so `image(PerpendicularLine(P, l)) = PerpendicularLine(image(P), image(l))`), deferred because it materializes images of parent curves the user didn't ask for. Orientation, the one subtle point: line reflection reverses orientation — `Arc` is safe (the via-point image picks the branch), a reflected `VertexAngle` **swaps its arm points** so the marker measures the same wedge (no swap under the three orientation-preserving transforms; central reflection is a rotation by π, det +1), and `Sector` is excluded from reflect-about-line only (rebuilding gives the complementary wedge; swapping rim/end would break the radius — documented limitation). Tool UX: one `TransformObjectTool` (`domain/tools/transform_object_tool.dart`) parameterized per transform replaces the four flyout wirings; the **transformee is the first input**, and a slot-1 curve hit is consulted from `ToolInput.hit`/`extraHits` *before* the point-resolution ladder — otherwise Phase 20's smart resolution would glue a `PointOnObject` to the very curve being transformed (the reason this is a dedicated class rather than a patched `PointAndLineTool`). Point-mode behavior is preserved exactly, including reflect's point + line in either order; the `G` chords are unchanged and now accept curves. Image defining points are committed *visible* (usable geometry, auto-named once Phase 23 lands).
- Quadrilateral macros (Phase 18) follow the same rules. A shared helper `mirrorPointAcross` (in `domain/tools/`) reflects a point across a line using only existing kinds: hidden perpendicular through the point → hidden branch-0 line∩line foot → `SegmentRatioPoint(point, foot, ratio: 2)` = the exact mirror image. Circle-branch mirroring is deliberately *not* used — fixed branch indices swap sides when the point drags across the axis; the foot + ratio-2 form is single-valued and continuous. Input schemes: **rectangle** = 2 taps for side A, B + a position-only height tap (C = `PointOnObject.near` on the hidden perpendicular through B, D = branch-0 intersection of the hidden perpendicular through A with the hidden parallel-to-AB through C; inherits `PointOnObject`'s analytic-parameter caveat like the trapezium). **Right trapezium** = 3 taps A, B (base, right angle at A), C (far top corner); D = branch-0 intersection of the perpendicular through A with the parallel-to-AB through C. **Rhombus** = 2 taps for side A, B + a position-only direction tap; C = `PointOnObject.near` on a hidden `CompassCircle(A, B, center: B)` (polar parameter — drift-free), D via the parallelogram trick. **Isosceles trapezium** (a.k.a. equilateral trapezium) = 3 taps A, B (base), C (top corner); D = C mirrored across the perpendicular bisector of AB (hidden `Midpoint` + perpendicular axis + mirror scaffolding). **Kite** = 3 taps A (apex), B (side vertex), C (opposite apex); D = B mirrored across the hidden diagonal segment AC.
- Triangle & polygon macros (Phase 16), same rules — visible corners + side segments, derived corners from existing kinds, one `MacroCommand`. Input schemes: **equilateral triangle** = 2 taps, corners A, B; apex C = `RotatedPoint` (B about A by +60°) — no scaffolding, no branch to pick; the triangle lies to the *left* of A→B and follows drags continuously. **Isosceles triangle** = 2 base taps A, B + a position-only apex tap; apex C = `PointOnObject.near` on the hidden perpendicular bisector of AB (hidden `Midpoint` + hidden `PerpendicularLine` referencing the visible base) — |CA| ≡ |CB| by construction; a degenerate base (A≈B) falls back to parameter 0, and C inherits `PointOnObject`'s analytic-parameter caveat. **Right triangle** = 2 base taps A, B (right angle at B) + a position-only tap for C on the hidden perpendicular through B referencing the base — the rectangle's height-tap mechanics; legs AB and BC, hypotenuse CA. **Regular polygon** = 2 taps, adjacent vertices A, B + side count from a dialog (integer 3–100, anything else reads as cancel, like the other dialog tools); the remaining n−2 vertices chain as `RotatedPoint`s — v₍ₖ₊₁₎ = v₍ₖ₋₁₎ rotated about vₖ by 2π/n − π — so the polygon lies left of A→B and every derived vertex is single-valued and continuous; a dedicated `RegularPolygonMacroTool` class (a captured count would defeat the tear-off highlight, like rotation). **Random triangle / random quadrilateral** = one-tap stamps: vertices are randomized *free* points around the tap, joined by segments (stamp radius ≈ 10× the tap's world-space snap threshold ≈ 80 screen px at any zoom, falling back to 80 world units when the threshold is 0). The triangle stamps 3 vertices at sorted random angles and jittered radii (sorted angles keep the outline non-self-intersecting; any triangle is trivially convex). The quadrilateral *(Phase 21, replacing the Phase 16 4–7-vertex random polygon)* is **always strictly convex**: exactly 4 vertices on one circle — no radial jitter, since sorted distinct angles on a circle are always in convex position — with angles from the gap method (n uniform draws normalized onto 2π minus n·minGap, minGap 0.25 rad, prefix-summed from a random start; deterministic, no rejection loop), then one random anisotropic affine stretch about the tap (rotate by φ, scale axes by factors in [0.7, 1.3], rotate back) for variety — affine maps preserve convexity, so the invariant survives. Randomness is injected (a seedable `math.Random` constructor parameter) so tests are deterministic. The Phase 16 "menu-only, no chord" decision is reversed in Phase 21: `X` `3` = random triangle, `X` `4` = random quadrilateral (digit second strokes proven by `G` `3`).
- **Planned tool additions (Phases 33–39):** perpendicular bisector reuses `TwoPointTool` (a `buildPerpendicularBisector` tear-off in the Lines flyout). `TangentTool` collects point + circle **in either order** (the `PointAndLineTool` pattern with a circle slot; a circle hit is consulted from `hit`/`extraHits` before the point ladder) and one tap-pair emits **both** tangent lines in a single `MacroCommand` — the GeoGebra convention; the pair is the natural undo unit, and deleting one afterwards is trivial. `FixedRadiusCircleTool` is dialog-first (`askCircleRadius`, the rotation-dialog pattern; garbage/non-positive reads as cancel), then one tap resolves the center via the ladder — a dedicated class so the tear-off highlight survives, per the rotation precedent. `FixedLengthSegmentTool` (dialog length L): tap endpoint A via the ladder, then a **position-only** direction tap (the trapezium 4th-tap precedent) → one `MacroCommand` of hidden `FixedRadiusCircle(A, L)` + visible `PointOnObject.near` B + visible `Segment(A, B)` — length pinned by construction, direction draggable for free through the Phase 14 slide-drag (B inherits the analytic-parameter caveat; degenerate tap falls back to parameter 0). Chosen over a dedicated `PointAtDistance` kind, which would need a new mutable direction, mutation primitive and drag command. `PolygonTool` is variable-arity over `MultiPointTool`: taps resolve via the ladder and the polygon **closes by tapping the first vertex again** once ≥ 3 are collected (taps on other already-collected vertices are ignored — no self-touching rings; no dialog, no fixed count). `DistanceTool` = `MultiPointTool` with 2 fully-laddered taps → `DistanceMeasurement`. `AreaTool` = one tap consulting `hit`/`extraHits` for the topmost `GeoPolygon`/`GeoCircle`, never falling through to the point ladder; other taps ignored. `LocusTool`: tap 1 must hit a `PointOnObject` (slot-consult), tap 2 a `GeoPoint` whose parent walk reaches the driver (else ignored) → one `AddObjectCommand`. `ToolInput` gains an additive `viewExtent` (visible world width, default 0 — the `snapThreshold` precedent) so the locus tool can bake a line-host sampling window.

### Commands (`domain/commands/`)

- `abstract class Command { void apply(Construction c); void undo(Construction c); }`
- Concrete commands: `AddObjectCommand`, `DeleteObjectsCommand` (cascades to dependents — captures their full state for restore), `MoveFreePointCommand` (one command per drag gesture, not per frame), `TranslateObjectsCommand` (rigidly translates a *set* of free points by one delta in a single undo step — this is how dragging a derived object works, see canvas section), `ChangeAttributesCommand`, `MacroCommand` (groups N commands).
- Drag preview: during a gesture the construction is mutated directly per frame (no command per frame). The gesture must terminate by emitting exactly one command capturing start → end, or by rolling the preview back on cancel (Esc mid-drag). This is the one sanctioned mutation outside a command; CLAUDE.md states the invariant with this carve-out.
- `class CommandStack` (in `application/`) holds undo + redo stacks, exposed as a Riverpod `Notifier`.

### Canvas & interaction (`presentation/canvas/`)

- `GeometryCanvas` widget hosts a `CustomPaint` with a `GeometryPainter` and a gesture stack:
  - `Listener` for pointer events (mouse + touch).
  - `GestureDetector` for tap, pan, scale.
- `Viewport` value type: `Vec2 pan` + `double scale`. World↔screen transforms live here, including zoom-about-a-focal-point (the world point under the cursor stays fixed) and scale clamping.
- Viewport changes (pan, zoom, fit, reset) are *view* state, not construction state — they never go through `Command`s and are not undoable, for the same reason selection changes aren't: undo should replay edits to the document, not replay where the user was looking. The viewport is still snapshotted into the save format (Phase 9), just outside the undo history.
- `HitTester`: iterates visible objects, returns the closest under a screen-px threshold, with priority order points > arcs/circles > segments/rays/lines (loci join this tier in Phase 39, distance = min clamped distance over consecutive sample segments) > angles > measurements *(Phase 38 — world distance to the text anchor; the canvas tap handler additionally checks the text's `labelScreenRect` first, exactly as the label-drag path already does, so text dragged far from its anchor stays tappable)* > polygons *(Phase 37 — the interior hits at distance 0 via an even-odd ray cast but at lowest priority, so anything drawn inside still wins while an empty interior tap selects the region; outside, min clamped edge distance; band-select requires all vertices contained)*. Used by both tools (input picking) and the selection drag. The threshold is **pointer-kind-based** *(Phase 25)*: 16 px for `PointerDeviceKind.touch`, 8 px otherwise — kind-gated rather than platform-gated, so touch-screen laptops and an iPad with a mouse both do the right thing. The canvas records the device kind from the `Listener` events it already handles; the larger touch threshold flows automatically into hit testing, `ToolInput.snapThreshold`, the Phase 20 point-resolution ladder, and the random-stamp radius (a touch stamp is 2× — acceptable, arguably correct on a phone).
- Dragging (in the no-tool move/select mode): a free point moves directly (`MoveFreePointCommand`). Any *other* object drags as a rigid translation of its free-point ancestors — grab a circle's rim and the whole circle moves because its defining points do — emitting one `TranslateObjectsCommand` per gesture. Two planned exceptions (Phase 14): a `PointOnObject` slides along its host curve (new `SetPointOnObjectParameterCommand`, one per gesture, same preview/rollback contract as the other drags), and a `CompassCircle` drags by moving only its *center's* free ancestors — the radius-defining points stay put, because the radius is a measurement, not part of the rigid body. Fully-derived objects with no free ancestors (e.g. an intersection point) don't drag. (A dedicated Drag tool with a select-only no-tool default was considered and shelved — dragging stays in the no-tool mode.)
- `GeometryPainter` walks the construction in insertion order, applies the viewport transform, draws each object using its attributes. Labels rendered via `TextPainter` at the object's per-kind anchor plus the stored `labelDx`/`labelDy` offset, at the per-object `labelFontSize` *(Phase 28)*. Labels are plain text — LaTeX/rich-math label rendering was considered and **deferred** (revisit on demand). Phase 30's Show/Hide tool adds a `showHidden` painter flag: while that tool variant is active, hidden objects (and their labels) draw at reduced opacity and `CanvasHitTester` includes them (`includeHidden`); this is tool-scoped view state — nothing persisted, nothing in the save format, and PNG export never renders hidden objects regardless (same no-UI-chrome rule as halos and markers). Objects with `dashPeriod > 0` draw their stroke as a dashed `Path` (hand-rolled `dashPath` via `PathMetrics`, no dependency); angle markers and the selection halo stay solid — the halo is UI, not object style. Angle markers *(Phase 22)*: the wedge radius comes from `attributes.angleMarkerRadius` (screen px, per object) instead of a painter constant; an angle whose sweep is exactly π/2 (shared math epsilon — right angles from perpendicular constructions are fp-exact) **automatically draws the right-angle square** — the polyline `v + s·d1 → v + s·(d1 + d2) → v + s·d2`, s = 0.7 × radius — instead of the arc, for both `VertexAngle` and `LineAngle`. When `fillAlpha` is set, the wedge (or square) gets a fill pass at the object color under the stroke pass; the same pass finally implements `Sector` fill, which the attributes documented but the painter never read. Defaults (radius 20, unfilled) render existing constructions identically. Phase 37 extends the `_drawFill` pass to two more fillables: `GeoPolygon` (the closed vertex path) and `GeoCircle` (a filled disc); polygons and loci draw dash-capable outlines like the other strokes (a locus paints one polyline `Path` per non-null sample run — gaps where the traced point was undefined — closed for circle hosts when gapless).
- **Label text & show-value (Phase 35):** label composition moves into a shared `labelText(GeoObject)` helper beside `labelScreenRect`, consumed by *both* the painter and the hit rect so they can't drift (the Phase 28 rule). A label paints iff it has a value part or (`labelVisible` && named); the text is `name = value` when both parts show, the bare value when the name part is hidden, the bare name when `showValue` is off. `showValue` is deliberately **independent of `labelVisible`** — segments are auto-named with `labelVisible: false` (Phase 23), so gating the value behind it would make the inspector's checkbox look dead; a fresh measured segment shows `3.42`, revealing the name upgrades it to `AB = 3.42`. Formatting lives in `presentation/canvas/measure_format.dart` (display-only, so presentation — the `label_anchor` precedent): lengths at 2 decimals, angles in degrees at 1 decimal + `°`, areas reuse the length format (Phase 38); fixed decimals keep goldens deterministic. Values read straight off domain geometry (`Segment` endpoints' distance, `GeoAngle.angle.measure`) — no new domain API. Measurement objects (Phase 38) draw *no* geometry in `_drawObject`; their text rides this same label pass — always with a value part, `name = value` when named and label-visible — so text dragging, `labelFontSize` presets and color styling need zero new code. Values render in PNG export (object style, not UI chrome).
- **Axes & grid (Phase 36):** a background layer drawn first in `paint()`, behind every object: grid hairlines at each multiple of an adaptive step — the smallest `{1, 2, 5} × 10^k` spanning ≥ 48 screen px, via a pure `gridStep(scale, {minPx: 48})` helper in `presentation/canvas/grid_layout.dart` — and 1.5-px axes through the world origin, with tick labels (trailing zeros trimmed, a single `0` at the origin) drawn only while axes are on. The toggles are **document state, not object state**: a `DocumentSettings` value (`showAxes`/`showGrid`, both default false) in its own provider — like the viewport, *not undoable*, but persisted per document (see Persistence). Theme supplies grid/axis colors (the palette already reserves "axis lines"). Defaults render existing documents, goldens and smoke byte-identically. Grid and axes are not objects: hit testing, selection and fit ignore them.
- Label dragging (Phase 17, move/select mode only): the label's screen rect (shared `labelScreenRect` helper so painter and canvas can't drift) is hit-tested *before* object geometry on pan-start; the drag updates a painter preview override held as canvas widget state (no construction mutation), clamps the offset magnitude to 40 px radially, and commits exactly one `ChangeAttributesCommand` on release. Labels are screen-sized, so this lives in the canvas widget, not `CanvasHitTester` (which is deliberately viewport-free).
- Multi-touch on mobile: pinch = zoom, two-finger drag = pan. On web/desktop, pointer signals follow the Figma-style mapping (decided in Phase 14): **plain scroll = pan** (both axes, so a trackpad two-finger swipe pans naturally and a mouse wheel scrolls the canvas), **pinch = zoom about the cursor** (browsers deliver a trackpad pinch as a ctrl-flagged wheel event; the Flutter web engine detects that Ctrl isn't physically down and synthesizes a `PointerScaleEvent`, which the canvas handles separately), and **physical `Ctrl`/`Cmd` + scroll = zoom** too, so mouse users keep a wheel zoom. The pre-14 mapping (scroll = zoom) read as "panning also resizes" under trackpad swipes because zoom-about-cursor both scales and shifts when the cursor is off-center. A macOS three-finger drag (accessibility) is a synthetic mouse drag and still rubber-bands — out of scope. Native desktop builds (not a shipping target) deliver trackpad gestures as PointerPanZoom into the scale recognizer's navigation branch, which already pans/zooms correctly.

### Panels (`presentation/panels/`)

- **Toolbar / tool palette** — grouping (landed in Phase 13, in `presentation/panels/toolbar.dart`): **Points** (flyout: point — smart: snaps to curves and crossings per the Phase 20 resolution ladder, subsuming the retired point-on-object entry — midpoint, segment-ratio point, intersection, centroid, orthocenter, incenter, circumcenter), **Lines** (flyout, renamed from the two-point menu: line, segment, ray, perpendicular, parallel, angle bisector), **Circles** (flyout: circle center+rim — moved here from the two-point menu — three-point circle, compass, arc, sector), **Angles** (flyout: at vertex, between lines, by given size — the last landed in Phase 16), **Transform** (flyout: reflect about line, reflect about point, rotate around point, translate by vector), **Macros** (flyout: square, parallelogram, trapezium, rectangle, right trapezium, rhombus, isosceles trapezium, kite — *the last five landed in Phase 18* — plus, from Phase 16: equilateral / isosceles / right triangle, regular polygon, random triangle / random quadrilateral stamps — *the quadrilateral replaces Phase 16's random polygon in Phase 21*). The group icon highlights while its tool is active, so the current tool is always visible. Flyout rows show each tool's shortcut as dimmed trailing text (from the shortcut table's `display` strings, joined via `AppAction`); group-icon tooltips deliberately do *not* list keys (shipped in Phase 17, reverted in Session 20 — hints live next to the subtool names only). Mobile adaptation is resolved in Phase 25 (a bottom sheet was considered and dropped — see **Mobile layout** below). Builders are public top-level tear-offs shared with the keyboard switch; the Points highlight is a catch-all for builders no tear-off claims (the segment-ratio dialog's closure). Phases 33–39 grow the groups: **Lines** += perpendicular bisector, segment by length…, tangents from point; **Circles** += circle by radius…; **Macros** gains Polygon as row 1 (group tooltip reworded "Polygons & shape macros"); and a seventh group **Measure** (icon `straighten`, after Macros) holds distance, area and locus — the compact strip scrolls, so the extra group costs nothing on mobile.
- **Tool activation / deactivation** — (landed in Phase 13) the active tool's flyout group icon is highlighted; **double-clicking the highlighted group icon deactivates** the tool, and the group's tooltip appends "double-click to deselect" while active. The double-tap detector mounts only on the active group, so the double-tap delay on opening a flyout applies only there. `Esc` and `V` always deactivate. With no tool active the app is in move/select mode (select + drag — see Canvas & interaction).
- **Attributes inspector** — shown when ≥1 object is selected. Edits name, color, visibility, label visibility, stroke width, and dash style (Solid/Fine/Medium/Coarse presets → `dashPeriod` 0/4/8/16, strokes only) via `ChangeAttributesCommand`s (so attribute edits are undoable). Phase 22 adds an **angles slice** beside the existing points/strokes slices: marker-radius presets `S`/`M`/`L`/`XL` → `angleMarkerRadius` 12/20/28/36, and a "Fill" tristate checkbox over fillable kinds (angles + sectors) toggling `fillAlpha` null ↔ 0.25 (the alpha byte 64 expressed on the attribute's 0–1 scale). Phase 25 fixes the dash selector's label overflow (the four words wrap in the 280-px panel): short labels `–`/`S`/`M`/`L` with tooltips carrying the full word plus a `bodySmall` text style on the segmented buttons — matching the Phase 22 single-letter preset convention. Phase 23: the single-selection header shows *name + kind* (kind-only before). Phase 27: renames are clash-free — submitting a name another object already holds *evicts* the old holder, renaming it to the first free numbered variant (trailing digits stripped to get the base: evicted `A` → `A1`, evicted `A1` → `A2`); both renames ride one multi-id `ChangeAttributesCommand` = one undo unit, and renaming an object to its own name stays a no-op. Phase 28 adds a label-size preset row `S`/`M`/`L`/`XL` → `labelFontSize` 9/12/16/22 (shared `_PresetSelector`, shown for selections with labelable kinds, one `ChangeAttributesCommand` per tap). Phase 35 adds a "Show value" tristate checkbox over selections containing segments/angles (the Fill-checkbox pattern, one command per tap). Phase 37 widens `fillables` from angles + sectors to polygons and circles, and includes polygons in the stroke/dash and label-size rows.
- **Object tree** (collapsible) — flat list grouped by type, useful for selecting hidden objects. Phase 26: the group headers (Points / Lines / Circles / Angles) become tappable **select-by-kind** affordances — tap replaces the selection with every object of that kind (hidden included — that's the tree's raison d'être), shift-tap unions with the current selection, and **long-press unions on touch** (the mobile shift equivalent). No new provider API: the tree already computes per-kind groups and `selectMany(ids, additive:)` already exists. One display-only cheat-sheet gesture row documents it. Phase 32: rows gain a **long-press toggle** (the touch shift-tap, with `HapticFeedback.selectionClick` — same convention as the canvas long-press and the group headers), and the panel gains a **search field** pinned at the top: case-insensitive substring filter over each row's display label (name, or kind label when unnamed), non-matching rows and empty groups hidden, `×` clears; while a query is active the group headers' select-by-kind selects *only the filtered matches*. The existing `EditableText` focus guard already keeps typing in the field from firing shortcuts. Phases 37–39 add three groups — Polygons, Measurements, Loci — and select-by-kind rides free on the Phase 26 header machinery.
- **App bar** — file menu (new/open/save/save as; *"Export as PNG…" joins in Phase 19*), undo/redo, theme toggle, cheat-sheet toggle button (keyboard icon, sits between Reset and the theme toggle so the web-smoke script's "theme toggle is last" indexing survives). Phase 36 adds a grid/axes popup (grid icon, between Reset and the tree toggle; two checked items — Show axes / Show grid); the compact overflow absorbs both entries.
- **Mobile layout (Phase 25).** One gate: `isCompact = MediaQuery.sizeOf(context).shortestSide < 600` (the Material breakpoint), evaluated in the scaffold build. Compact mode: the app bar keeps File / undo / redo plus **one overflow popup** absorbing Fit, Reset, object tree, cheat sheet and theme (the six loose icon buttons don't fit a phone); the `GeometryToolbar` moves out of the app-bar actions into a 48-px strip under the app bar wrapped in a horizontal `SingleChildScrollView` — scrollable, never truncated — reusing the six flyout groups untouched (their 280-px flyouts already fit). The side panels become drawers: object tree → `Scaffold.drawer`, inspector → `endDrawer`, width `min(280, 0.85 × screen)`, panel widgets reused verbatim; the inspector does **not** auto-open on selection (it would interrupt construction flow) — a "style" icon at the strip's right end, shown while the selection is non-empty, opens it. On mobile targets (`!kIsWeb` + Android/iOS) `main()` hides the OS status bar via `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` and the body gets a `SafeArea` for notches. The wide layout is unchanged, byte for byte — desktop web smoke must be zero-diff.

### Theme (`presentation/theme/`)

- `ThemeData.light()` / `ThemeData.dark()` with a custom palette tuned for canvas contrast (canvas background, axis lines, default object colors per theme). Theme choice persisted in `shared_preferences`.

### Persistence (`application/persistence/`)

- JSON schema:
  ```json
  {
    "version": 1,
    "viewport": {"pan": [0,0], "scale": 1},
    "objects": [
      {"id": "p1", "type": "FreePoint", "parents": [], "params": {"x": 1.0, "y": 2.0}, "attributes": {...}},
      {"id": "m1", "type": "Midpoint", "parents": ["p1","p2"], "params": {}, "attributes": {...}}
    ]
  }
  ```
- Save: serialize each object in topological order (= the construction's insertion order).
- Load: parse, then construct in order — each constructor receives already-deserialized parents by id. Use `freezed`'s json support for attributes.
- Encode/decode both live in one hand-written codec (`application/persistence/construction_codec.dart`) that switches on concrete object type, rather than `toJson` methods spread across the domain classes: the type↔constructor registry must exist centrally for *decoding* anyway, keeping the encoder beside it means one file to update per new object kind, and the domain layer stays free of persistence concerns. The cost — a forgotten kind fails at runtime, not compile time — is covered by the round-trip test that instantiates every concrete kind.
- Decode failures (malformed file, unknown type, unknown version, ill-typed parents) throw `FormatException` with the offending object's id, so File > Open can show one dialog for any bad file.
- Schema version field from day one to allow future migrations. A file with a *newer* version than the app understands is rejected, not best-effort parsed.
- Phase 36 adds two additive top-level keys beside `viewport`: `"showAxes"` / `"showGrid"` (absent → false) — **no version bump**: the decoder reads only the keys it knows, so old files decode with defaults and old apps ignore the new keys. `DecodedDocument` gains a settings field; File > New resets to defaults. Like the viewport, the settings are persisted but never undoable.
- Phase 37's `Polygon` is the first object whose parents array has variable length. The codec's parents list already carries an id array, so encoding is untouched; decoding loops the typed `point(i)` helper over `parents.length` instead of fixed slots, with the constructor's ≥ 3 guard normalizing short lists to `FormatException`.

### Export (`application/export/`) — planned, Phase 19

Export the construction as an image, separate from the JSON save format.

- **PNG (committed).** Render off-screen via `ui.PictureRecorder` + the existing `GeometryPainter` — *not* a widget screenshot — so exports work at any resolution and never include UI chrome (selection halos, in-progress tool markers, band rectangle). Framing has three options: "fit construction" (default, via the existing `fittedViewport`), "current viewport", and a **drag-selected region** of the window. An options dialog picks framing, scale factor (1×/2×/4×) and background (theme canvas color vs **transparent**), and always shows the **exact output rectangle in pixels** ("Output: 1920 × 1080 px"), live-updated as framing and scale change. Encode with `ui.Image.toByteData(format: png)`; deliver bytes through a `savePngBytes` sibling of the existing save path in `application/persistence/file_io.dart` (already handles web download + native picker).
- **Region picking.** Choosing "Select region…" in the dialog closes it and arms a one-shot overlay stacked *on top of* `GeometryCanvas` (the canvas widget is untouched and receives no events while the overlay is up): drag draws a marquee rectangle, release captures it in canvas screen coordinates and reopens the export dialog with the region framing selected; Esc cancels back to the dialog. The region maps to a viewport by `pan = screenToWorld(rect.topLeft)` at the unchanged scale, output logical size = the rect's size — so what you see inside the marquee is exactly what exports.
- **Placement.** Orchestration in a new `lib/application/export/` beside `persistence/`, plus a small options dialog in presentation. The painter lives in `presentation/`, so the export code that calls it also stays outside `domain/` — no layer-rule impact.
- **Not a command.** Export is a read-only view operation: not undoable, nothing added to the save format (same reasoning as viewport changes not being undoable).
- **UI.** File menu → "Export as PNG…"; shortcut `Ctrl/Cmd + E` in the shortcut table + cheat sheet.
- **Axes & grid (Phase 36).** The options dialog gains one checkbox — "Include axes & grid (as shown)", default on when either toggle is on — passing the current document settings into the off-screen render. One flag, not two: the export either mirrors the canvas or strips decoration; per-flag control is dialog noise.
- **SVG (stretch, same phase, may slip).** Hand-written SVG writer walking the construction in insertion order, mirroring the painter's per-kind drawing (incl. `dashPeriod` → `stroke-dasharray`, labels as `<text>`). No dependency. Explicitly optional.
- **Out of scope.** PDF and clipboard-copy — revisit on demand.

## Critical files to create

| Path | Purpose |
|---|---|
| `pubspec.yaml` | Dependencies: `flutter_riverpod`, `freezed`, `json_serializable`, `file_picker`, `shared_preferences`, `uuid`. Dev: `build_runner`, `flutter_test`, `mocktail`, `golden_toolkit`, optionally `glados` (property-based tests). (`vector_math` was planned but dropped — the domain layer hand-rolls an immutable `Vec2`.) |
| `lib/domain/math/vec2.dart` | 2D vector ops. |
| `lib/domain/math/intersections.dart` | All intersection routines, with degenerate-case handling. |
| `lib/domain/math/triangle_centers.dart` | Centroid, orthocenter, incenter, circumcenter. |
| `lib/domain/construction/geo_object.dart` | Sealed base + `ObjectAttributes`. |
| `lib/domain/construction/objects/*.dart` | One file per object kind (~20 small files). |
| `lib/domain/construction/construction.dart` | DAG, topological recompute, dependents lookup, cascading delete. |
| `lib/domain/tools/tool.dart` | Tool interface + state. |
| `lib/domain/tools/*.dart` | One file per tool. |
| `lib/domain/commands/command.dart` + `*_command.dart` | Command interface + implementations. |
| `lib/application/providers/construction_provider.dart` | Riverpod provider exposing the `Construction`. |
| `lib/application/providers/selection_provider.dart` | Selection set state. |
| `lib/application/providers/tool_provider.dart` | Active tool + tool state. |
| `lib/application/providers/viewport_provider.dart` | Pan/zoom state. |
| `lib/application/providers/command_stack_provider.dart` | Undo/redo. |
| `lib/application/persistence/construction_codec.dart` | JSON encode/decode. |
| `lib/application/persistence/file_io.dart` | Save/load via `file_picker` (web + mobile). |
| `lib/presentation/canvas/geometry_canvas.dart` | The canvas widget. |
| `lib/presentation/canvas/geometry_painter.dart` | `CustomPainter`. |
| `lib/presentation/canvas/hit_tester.dart` | Hit testing logic. |
| `lib/presentation/canvas/viewport.dart` | Viewport value type + transforms. |
| `lib/presentation/panels/toolbar.dart`, `attributes_inspector.dart`, `object_tree.dart` | UI panels. |
| `lib/presentation/theme/app_theme.dart` | Light/dark themes. |
| `lib/main.dart` | App entry, `ProviderScope`, theme wiring, layout. |

## Test strategy

Tests mirror the source layout under `test/`. Coverage targets:

- **`test/domain/math/`** — exhaustive numeric tests on intersections (parallel, tangent, coincident, near-tangent), triangle centers (verify against known coords for canonical triangles), and edge cases (degenerate triangles, points coinciding). Property-based via `glados`:
  - midpoint of (A, B) is equidistant from A and B
  - circumcenter is equidistant from all three vertices
  - centroid = (A + B + C) / 3
  - line through (A, B) contains both A and B within epsilon
  - reflection across a perpendicular bisector swaps A and B
- **`test/domain/construction/`** — recompute correctness: build a chain (e.g., midpoint → perpendicular → intersection), drag a root, assert all dependents are consistent. Cascade delete: deleting a parent removes all dependents and is reversible.
- **`test/domain/commands/`** — every command's `undo(apply(c)) == c` for representative inputs.
- **`test/domain/tools/`** — tool state machines: feed a sequence of `onTap` calls, assert the resulting command.
- **`test/application/persistence/`** — JSON round-trip on a complex construction (several derived layers, all object kinds), incl. attributes and viewport.
- **`test/presentation/`** — widget tests for tool flows (tap-tap to make a segment, drag a free point and see the dependent update), and golden tests for rendering each object kind in light + dark theme.

CI-friendly: keep golden tests in their own tagged group so they can be skipped on platforms where rendering differs.

## Keyboard shortcuts

Tools are bound to single letters where possible; less-common variants use Shift+letter or a two-key chord. The one source of truth is a declarative `ShortcutTable` (`lib/presentation/shortcuts/shortcut_table.dart`): a list of bindings, each a one- or two-stroke key sequence plus a semantic `AppAction`, a human-readable label, and a cheat-sheet section. A pure `ShortcutResolver` consumes key strokes one at a time and handles the two-stroke leader chords (a pending leader is cancelled by Esc or any non-matching second stroke, which is swallowed rather than fired standalone); an `AppShortcuts` `Focus` widget at the editor root feeds it hardware key events, marks matches handled, and ignores everything while an `EditableText` has focus so typing a name can never trigger a tool. Flutter's stock `Shortcuts`/`Actions` tables are deliberately *not* used: chords and the focused-text-field guard don't fit `ShortcutActivator`'s single-stroke, always-on model. Mobile users obviously skip these, but on web/desktop they're essential.

Selection / app-level:
| Key | Action |
|---|---|
| `Esc` | Cancel current tool, return to Move/Select |
| `V` | Move/Select tool (pointer) |
| `Del` / `Backspace` | Delete selection (cascades to dependents) |
| `Ctrl`/`Cmd` + `Z` | Undo |
| `Ctrl`/`Cmd` + `Shift` + `Z` (also `Ctrl`/`Cmd` + `Y`) | Redo |
| `Ctrl`/`Cmd` + `A` | Select all |
| `Ctrl`/`Cmd` + `S` / `O` / `N` | Save / Open / New construction |
| `Ctrl`/`Cmd` + `E` | Export as PNG… *(Phase 19)* |
| `Ctrl`/`Cmd` + `D` | Toggle dark mode |
| `H` | Hide tool — tap objects to hide them *(Phase 30; was hide-selected)* |
| `Shift` + `H` | Show/Hide tool — hidden objects shown dimmed, tap toggles visibility *(Phase 30; was reveal-all)* |
| `Tab` | Cycle through selectable objects under cursor *(deferred — needs cursor-position tracking; Tab does focus traversal meanwhile)* |

Viewport:
| Key | Action |
|---|---|
| `+` / `=` · `-` | Zoom in / out |
| `0` | Reset zoom to 100 % |
| `F` | Fit construction to viewport |
| `Space` (held) + drag | Pan (any tool) |
| Arrow keys | Nudge viewport |
| `Shift` + `G` | Toggle grid *(Phase 36)* |
| `Shift` + `X` | Toggle axes *(Phase 36)* |

Tools (single-letter primary):
| Key | Tool |
|---|---|
| `P` | Point |
| `L` | Line through two points |
| `S` | Segment |
| `R` | Ray |
| `C` | Circle (center + point) |
| `M` | Midpoint |
| `I` | Intersection *(tool lands in Phase 13 — bind then; macros already build `IntersectionPoint`s internally)* |
| `B` | Angle bisector |
| `A` | Angle at vertex (`Shift` + `A` for angle between lines) |
| `T` | Perpendicular line (`Shift` + `T` for parallel) |
| `O` | Compass circle |
| `Shift` + `B` | Perpendicular bisector *(Phase 33)* |
| `Shift` + `S` | Segment by given length *(Phase 34)* |
| `Shift` + `C` | Circle by given radius *(Phase 34)* |
| `D` | Distance measurement *(Phase 38)* |
| `Shift` + `D` | Area measurement *(Phase 38)* |
| `Shift` + `L` | Locus *(Phase 39)* |

Chords (`G` = "geometry", a leader key for less-frequent constructions):
| Chord | Tool |
|---|---|
| `G` `C` | Centroid |
| `G` `O` | Orthocenter |
| `G` `I` | Incenter |
| `G` `U` | Circumcenter |
| `G` `3` | Three-point circle |
| `G` `R` | Segment-ratio point |
| `G` `A` | Arc (3-point) |
| `G` `S` | Sector |
| `G` `L` | Reflect about line |
| `G` `P` | Reflect about point |
| `G` `T` | Rotate around point ("turn" — `R` is taken) |
| `G` `V` | Translate by vector |
| `G` `D` | Angle by given size ("degrees" — `A` is taken) |
| `G` `N` | Tangents from point to circle ("ta**N**gent") *(Phase 33)* |

Macros (`X` leader for advanced shapes):
| Chord | Tool |
|---|---|
| `X` `S` | Square |
| `X` `P` | Parallelogram |
| `X` `T` | Trapezium |
| `X` `R` | Rectangle *(Phase 18)* |
| `X` `H` | Rhombus *(Phase 18)* |
| `X` `K` | Kite *(Phase 18)* |
| `X` `I` | Isosceles trapezium *(Phase 18)* |
| `X` `L` | Right trapezium *(Phase 18 — L for the right angle's shape)* |
| `X` `E` | Equilateral triangle |
| `X` `⇧ I` | Isosceles triangle *(plain `X I`/`X R` went to the Phase 18 quadrilaterals)* |
| `X` `⇧ R` | Right triangle |
| `X` `G` | Regular polygon |
| `X` `3` | Random triangle *(Phase 21 — digit = vertex count; reverses Phase 16's menu-only decision)* |
| `X` `4` | Random quadrilateral *(Phase 21)* |
| `X` `V` | Polygon — tap vertices, the first again to close ("**V**ertices") *(Phase 37)* |

Shifted single letters coexist with the leaders: `Shift`+`G` / `Shift`+`X` must resolve as their own bindings and never arm the `G`/`X` leader — `KeyStroke`'s shift matching is exact, but Phase 36 pins it with a dedicated resolver test.

The full table is rendered in a `?`-key cheat sheet overlay. Bindings live in `lib/presentation/shortcuts/shortcut_table.dart` and are tested with widget tests that send key events and assert the active tool / command.

## Build order (rough)

1. `pubspec.yaml`, `domain/math/`, full unit + property tests for math.
2. `domain/construction/` core (FreePoint, Midpoint, Line, Circle, Intersection) + recompute tests.
3. `domain/commands/` + `CommandStack` + tests.
4. Riverpod providers in `application/`.
5. Minimal `GeometryCanvas` + `GeometryPainter` + hit tester + one tool (PointTool); manual smoke test.
6. Round out remaining object types and tools (triangle centers, parallel/perpendicular, angle bisector, segment ratio, three-point circle, compass, arc, sector, angle).
7. Selection, attributes inspector, hide/show, delete-with-dependents.
8. Pan/zoom viewport.
9. Save/load + theme + shared_preferences.
10. Macro/advanced tools (square, parallelogram, trapezium) on top of the macro-command machinery.
11. Golden tests + widget tests for tool flows.
12. Toolbar rework & tool-selection UX: unified Points menu (incl. new intersection tool), Lines menu absorbs the line constructions, circle moves to the circles menu, deselect affordances. (TODO Phase 13)
13. Drag & gesture fixes: `PointOnObject` slide-drag, compass-circle center-only drag, trackpad pan mapping on web. (TODO Phase 14)
14. Transformations: reflect about line / about point, rotate around point, translate by vector. (TODO Phase 15)
15. Angle-by-given-size + triangle/polygon macros. (TODO Phase 16)
16. Discoverability & styling polish: cheat-sheet app-bar button, shortcut hints in toolbar flyouts, dashed stroke style, draggable labels. (TODO Phase 17)
17. Quadrilateral macros: rectangle, right trapezium, rhombus, isosceles trapezium, kite. (TODO Phase 18)
18. Export: off-screen PNG render + save via the existing file I/O; SVG writer as a stretch goal. (TODO Phase 19)
19. Random-stamp upgrades: convex random quadrilateral replaces the random polygon; `X 3`/`X 4` chords. (TODO Phase 21)
20. Angle-mark styling: per-object marker radius, automatic right-angle square, wedge/sector fill. (TODO Phase 22)
21. Automatic naming: pure allocator + command-funnel interceptor, per-kind label-visibility defaults, name in the inspector header. (TODO Phase 23)
22. Whole-object transforms: reflect/rotate/translate/central-reflect whole curves via macro composition. (TODO Phase 24)
23. Mobile ergonomics: compact chrome + scrollable toolbar strip + panel drawers, immersive status bar, touch snap radius, dash-selector overflow fix. (TODO Phase 25)
24. Select-by-kind via tappable object-tree group headers. (TODO Phase 26)
25. Rename clash resolution: evict-and-number via one MacroCommand. (TODO Phase 27)
26. Label size styling: `labelFontSize` attribute + inspector presets. (TODO Phase 28)
27. Tool-input highlighting: halo consumed existing objects instead of temporary point markers. (TODO Phase 29)
27b. Angle tools without by-product points: two-line bisector mode + curve taps refused in the angle point flows. (TODO Phase 29b)
28. Hide & Show/Hide tools: tap-driven visibility, dimmed hidden objects. (TODO Phase 30)
29. Line-angle wedge picked by taps: obtuse support + right-angle-square placement fix. (TODO Phase 31)
30. Object tree: long-press multi-select + search filter. (TODO Phase 32)
31. Perpendicular bisector + tangent lines: two new `GeoLine` kinds + tangent math. (TODO Phase 33)
32. Given lengths: `FixedRadiusCircle` kind, circle-by-radius + segment-by-length dialog tools. (TODO Phase 34)
33. Show-value labels: `showValue` attribute, shared `labelText`, measure formatting. (TODO Phase 35)
34. Axes & grid: painter background layer, per-document persisted toggles, export checkbox. (TODO Phase 36)
35. Polygon: `GeoPolygon` sealed kind + close-tap tool + circle/polygon fill. (TODO Phase 37)
36. Measurements: `GeoMeasurement` sealed kind, distance + area tools, Measure toolbar group. (TODO Phase 38)
37. Locus: `GeoLocus` sealed kind with sweep-and-restore sampling + locus tool. (TODO Phase 39)

## Multi-session workflow

This app spans many sessions. A fresh session has zero memory of prior ones, so we lean on four durable artifacts in the repo. Any new session should be productive within a minute of warm-up.

| File | Role | Cadence |
|---|---|---|
| `docs/PLAN.md` | Architecture, build order, decisions. The "what and why." | Read-mostly; edited only when scope or approach changes. |
| `docs/STATUS.md` | Append-only log of what happened each session. The "where are we." | One entry per session, written at session end. |
| `docs/TODO.md` | Live checklist mirroring the build-order phases. | Tick boxes during the session as items land. |
| `CLAUDE.md` (repo root) | Architectural invariants, common commands, conventions. Auto-loaded by Claude Code every session. | Edit only when invariants change. |

**Session-start ritual.** Open the project and say:

> *Read CLAUDE.md, docs/PLAN.md, docs/STATUS.md, docs/TODO.md. Tell me what's next and propose the first concrete change.*

This can be wrapped as `/continue-build` via `.claude/commands/continue-build.md` so it's one keystroke.

**Session-end ritual.**

1. Commit work-in-progress on a phase branch.
2. Tick completed boxes in `docs/TODO.md`.
3. Append a new entry to `docs/STATUS.md` (date, what was done, what's next, gotchas).

**Branching.** One feature branch per build-order phase (e.g., `phase-1-math`, `phase-2-construction-core`). Merge to `main` once the phase's tests are green and `flutter analyze` is clean.

**Anti-patterns to avoid.**
- Letting a session run too long — context quality degrades. End at a clean checkpoint and start fresh.
- Skipping the STATUS entry. The 30 seconds saved cost 10 minutes next session.
- Treating in-session memory as durable. Anything important must land in one of the four files above.

## Verification

End-to-end manual + automated checks once implementation lands:

- `flutter pub get && dart run build_runner build` succeeds.
- `flutter analyze` clean.
- `flutter test` green, including goldens.
- `flutter run -d chrome` — build a non-trivial construction (triangle + circumcircle + orthocenter + perpendicular from one vertex), drag a vertex, confirm everything updates smoothly.
- `flutter build apk` and `flutter build ios` succeed (build only — actual device run optional unless requested).
- Save the construction to JSON, clear, load it, confirm identical render.
- Toggle theme, confirm colors swap and persist across restarts.
- Undo a chain of operations including a drag, then redo — final state matches.
