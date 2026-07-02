# Status Log

Append-only journal of working sessions. Newest entries on top. Each entry should answer three questions in 5–15 lines: **what was done**, **what's next**, **gotchas / open questions**.

Write a fresh entry at the end of every session, before stopping. Do not edit older entries — if something turned out wrong, note it in the next entry.

---

## Session 10 — 2026-07-02

**Done**
- Phase 6 finished. PLAN updated first (per CLAUDE.md) with the kind story: arcs/sectors are `GeoCircle`s with a carrier + *angular* extent (the circle-side twin of `Segment`/`Ray` on `GeoLine`); angles are a genuinely new 4th sealed kind `GeoAngle` whose value is an `AngleGeometry` (vertex, unit start direction, CCW sweep) — decorations plus a measure, no intersection math.
- `math/angle_geometry.dart`: `ccwSweep` (in [0, 2π)), `sweepThrough` (signed arc-branch pick), `AngleGeometry` with `fromRays` (directed, arm order picks the marker) and `betweenLines` (always acute/right, in (0, π/2]).
- `Arc` (start/via/end, signed sweep = branch containing via) and `Sector` (center + rim fixing radius/start angle + a point fixing only the end angle, CCW sweep): painter draws the branch via `drawArc` (world angles negate on screen, y-flip), hit tester clamps to the branch — off-branch falls back to endpoint distance (arc) or the two radius edges (sector).
- `GeoAngle` + `VertexAngle`/`LineAngle`. Adding the kind fanned out compiler-driven to every exhaustive switch: painter (marker wedge at fixed 20 px screen radius), hit tester (priority 3, picked at its *vertex* — the tester has no viewport, so it can't know the marker's world size), `PointOnObject`, `IntersectionPoint`, `PointAndLineTool`.
- Tools/chrome: arc + sector joined the circles menu (`ThreePointTool`); new angles menu (`Icons.square_foot`) with vertex angle (`ThreePointTool`) and `TwoLineTool` (new tool: collects two distinct existing lines, ignores everything else, previews the first tap projected on its carrier). Highlight logic extended to the new builder tear-offs.
- 336 tests green, `flutter analyze` clean. Merged `phase-6-objects` into `main`.

**Next**
- Phase 7 — Selection & attributes: multi-select (rubber band + shift-click), dragging derived objects via `TranslateObjectsCommand`, attributes inspector, hide/show, color/stroke, cascading-delete UX, object tree panel. Start a `phase-7-selection` branch.

**Open questions / gotchas**
- `VertexAngle` is *directed* (CCW from arm1's ray to arm2's): the two tap orders mark the two complementary angles. Deliberate — GeoGebra-style — and documented in the class; don't "fix" it to always-interior.
- `LineAngle` is undefined while its lines are parallel (no vertex to mark), even though "angle = 0" would be answerable. Also its vertex can sit outside a segment/ray parent's drawn extent (carrier semantics, same wart as `IntersectionPoint`).
- Angle hit testing is vertex-only, priority last. If Phase 7 selection makes that feel too small a target, the fix needs the viewport's zoom (marker radius is screen-space) — plumb a world-radius hint into `CanvasHitTester` rather than hardcoding one.
- `Sector.endRim` is a *computed* rim point (end projected onto the circle); `startRim` is the parent's own position. Painters/hit-testers must not assume `end.position` is on the circle.
- Screen-vs-world angle sign: `drawArc` needs both start angle and sweep *negated* (world y-up → screen y-down). Both call sites live in `_drawCarrierBranch`/`_drawAngleMarker`; keep any future angle drawing on that path.
- Dart's `%` on doubles is already Euclidean (non-negative for a positive divisor), but a tiny negative difference can round to exactly 2π — `ccwSweep` guards that edge; reuse it instead of inlining `% (2 * pi)`.

## Session 9 — 2026-07-02

**Done**
- Phase 6 continued on `phase-6-objects` (6 more commits, 18 total, still unmerged). Three object families landed end to end, each with domain tests, editor chrome and widget tests:
- `SegmentRatioPoint` (fixed lerp parameter along point1→point2; ratio outside [0,1] extrapolates deliberately). No new tool — a `TwoPointTool` builder captures the ratio. The two-point menu's values became async `TwoPointPick` factories so the ratio item can show a dialog (accepts `0.25` or `1/4`) before the tool exists; cancel or garbage input activates nothing.
- `ThreePointCircle` (circumcircle; undefined while collinear) and `CompassCircle` (radius = distance of two points, centered on a third; zero radius OK like `CircleCenterPoint`) — both reuse `ThreePointTool` from a new circles app-bar menu. The Session 8 highlight gotcha is resolved: builders are top-level functions, and the line/circle menu highlights compare `activeTool.build` against those canonicalized tear-offs.
- `Ray` (origin + through; carrier `GeoLine` like `Segment`): painter draws the half-line from the parent points' direction, hit tester got the predicted extent clamp — segment and ray now share one `_clampedDistance` helper (t in [0,1] vs [0,∞)).
- 286 tests green, `flutter analyze` clean.

**Next**
- Remaining Phase 6: arc (3-point), sector, angle (between lines / at vertex) + their tools. These likely need a new `GeoObject` kind (the sealed kinds are point/line/circle only) — per CLAUDE.md, update PLAN first and decide the kind/attribute story before coding.

**Open questions / gotchas**
- Dart won't infer lambda parameter types through an async closure's `FutureOr<TwoPointBuilder?>` return context — hence the `_pick` helper (typed parameter restores inference) and the typed local function in the ratio item. Don't "simplify" them back to bare lambdas.
- Disposing a `TextEditingController` right after `showDialog` returns crashes the dialog's exit animation; `_RatioDialog` is a StatefulWidget owning its controller for exactly that reason.
- Menu-highlight-by-builder relies on top-level function tear-offs being canonicalized (`==` across separate tear-offs). Inline lambdas would break it silently — keep `_build*` functions top-level.
- `Ray` painting/hit-testing must use the parent points, not `line.direction` — the carrier's direction is normalized independently of parent order. Noted in the class doc.
- `PointOnObject`'s line parameter is arc-length along the *unit* direction (parameter 1 ≠ "at the second defining point") — tripped up a test this session; worth remembering when writing expectations.

## Session 8 — 2026-07-02

**Done**
- Phase 6 started on branch `phase-6-objects` (3 commits, not yet merged — the phase is far from done). Triangle centers landed end to end: `TriangleCenterPoint` base (three `GeoPoint` vertices + undefined-state plumbing) with `Centroid`/`Orthocenter`/`Incenter`/`Circumcenter` as thin subclasses over `math/triangle_centers.dart`; one `TriangleCenterTool` covers all four via a `buildCenter` constructor tear-off (`Centroid.new`, …).
- First multi-input tool, so the supporting machinery landed with it: taps on existing points collect them (duplicates ignored), taps elsewhere create free points held privately until the third vertex, then everything commits as one `MacroCommand` (single undo unit). `ToolInputPreview` (domain) exposes collected positions; `GeometryPainter` draws dot+ring markers for them; minimal app-bar `PopupMenuButton` activates each center kind.
- New safety net: undo/redo and `constructionProvider.replace` now call `ToolNotifier.resetInProgress()` — without it, undoing a collected parent mid-collection made the eventual commit throw (`Construction.add`: parent not in construction). Covered by provider + widget tests.
- Second stint, same session: `PointOnObject` (stores a fixed parameter in the curve's *analytic* parameterization — new math APIs `LineEq.pointAt`/`parameterAt`, `CircleEq.angleAt` with property tests; `PointOnObject.near()` projects a tap). The collect-N logic then moved from `TriangleCenterTool` into an abstract `MultiPointTool`; `TwoPointTool` (builder lambda, positional args because param names differ per object) gives line/segment/circle/midpoint tools nearly for free — those two-point tools were missing from TODO entirely (added, ticked). `PointOnObjectTool` is stateless like `PointTool`. All wired into the app-bar chrome.
- Third stint: perpendicular/parallel lines and the angle bisector. `RelativeLine` template base (point + reference-line parents; subclass picks the direction from the reference carrier's unit normal/direction) with `PerpendicularLine`/`ParallelLine`; segments work as references through their carrier. The predicted new collect pattern landed as `PointAndLineTool`: two typed slots filled in either order (point slot also fills from an empty-canvas tap, MacroCommand-grouped like `MultiPointTool`; filled-slot input and circles ignored; line preview marker = tap projected onto the live carrier). Angle bisector: `math/angle_bisector.dart` (direction = û+v̂, falling back to (û−v̂)⊥ near straight angles — for unit vectors the two are orthogonal and never both small; null when an arm sits on the vertex) + `AngleBisectorLine` + `ThreePointTool` (positional-builder sibling of `TwoPointTool`, will also serve three-point circle/arc). The line_axis menu now carries `Tool Function()` factories so both tool types share it.
- 266 tests green, `flutter analyze` clean (12 commits on the branch).

**Next**
- Remaining Phase 6 items: segment-ratio point, three-point circle (reuse `ThreePointTool`), compass circle, arc, sector, angle, ray — each with its tool. Sector/angle may need a new `GeoObject` kind or attribute story — check PLAN before starting those.

**Open questions / gotchas**
- Constructor tear-off equality/constness is load-bearing in the editor menu (`PopupMenuItem(value: Centroid.new)` is const); the tear-offs all conform to `TriangleCenterBuilder` because extra optional params (`attributes`) don't break function-type assignability.
- `ToolInputPreview implements Tool` deliberately — an unrelated capability interface wouldn't type-promote after `tool is ToolInputPreview` (Dart promotes only to subtypes).
- `package:flutter/rendering.dart` does *not* re-export `listEquals`; the painter imports `foundation` for it.
- `TriangleCenterTool` allows coincident vertex *positions* (center goes undefined, recovers on drag apart) but rejects the same point *object* twice.
- `PointOnObject`'s parameter rides the *analytic* form (LineEq anchor/direction), not the defining points: translating a line along itself leaves the constrained point in place. Deterministic and documented in the class doc — same spirit as the intersection-branch wart. Revisit only if Phase 7 manual dragging makes it feel wrong.
- Dart flow analysis can't promote `GeoObject?` through `hit is! GeoLine && hit is! GeoCircle` — `PointOnObjectTool` needs the explicit `hit == null ||` first.
- Web smoke was not repeated this session (widget tests cover the flows); the Playwright drive script from Session 7 lived in that session's scratchpad and is gone — recreate it next time a real browser check is needed.
- The editor's line-constructions highlight treats any `ThreePointTool` as "this menu's tool" — once `ThreePointTool` also builds circles/arcs from another menu, the highlight must inspect the builder, not the type (comment in `main.dart`).
- `angleBisector` always returns the *internal* bisector; the external one (û−v̂ direction) is not exposed. If a future tool wants both, extend the math function rather than negating an arm at the call site.

## Session 7 — 2026-07-02

**Done**
- Phase 5 complete on branch `phase-5-canvas` (5 commits). `lib/domain/tools/`: `Tool` interface (`ToolInput` = world position + optional hit object; sealed `ToolResult` Accepted/Committed/Ignored; `reset()` for cancel/switch) + `PointTool` (stateless, ignores taps on existing points, injected `newId`). `lib/application/`: `object_ids.dart` (`newObjectId()`, the app's one UUID source) + `toolProvider` (`ActiveToolState` = nullable tool + revision, mirroring `ConstructionState`; `handleInput` funnels committed commands into `commandStackProvider`). `lib/presentation/canvas/`: `CanvasViewport`, `CanvasHitTester`, `GeometryPainter`, `GeometryCanvas`. `main.dart`: `ProviderScope` + minimal `EditorScreen` (point-tool toggle, undo/redo) — the real toolbar panel is Phases 6–7.
- 191 tests green, `flutter analyze` clean. Web smoke test done for real: `flutter run -d web-server` + Playwright/headless Chrome — 3 points placed under the cursor, undo×2, redo, all rendered, no console errors.

**Next**
- Phase 6 (object & tool coverage): triangle centers, `PointOnObject`, perpendicular/parallel, angle bisector, segment-ratio, three-point/compass circles, arc, sector, angle, ray — and a tool per object. First multi-input tools will exercise `ToolAccepted`/preview state for the first time; the painter needs in-progress input markers then too.

**Open questions / gotchas**
- Naming: PLAN's `Viewport`/`HitTester` collide with Flutter (`Viewport` widget) and flutter_test (`HitTester`) — landed as `CanvasViewport`/`CanvasHitTester`.
- World coordinates are **y-up**; the flip happens only in `CanvasViewport`. Default viewport puts world origin at the canvas top-left, so visible world y is negative until Phase 8's fit/center lands.
- `GeometryPainter.shouldRepaint` keys on construction *instance* + revision (+ viewport/color): `replace()` resets revisions, so instance identity alone distinguishes a swapped-in construction. `Construction.objects` returns a fresh iterable per call — never use it for identity.
- `toolProvider.handleInput` is the single entry point for canvas taps; presentation never touches commands directly. No active tool → `ToolIgnored` (a Phase 7 concern: that's where selection taps go).
- Web smoke gotcha for future driving: enabling Flutter's semantics tree reroutes canvas clicks through the GestureDetector's semantics node — `onTapUp` then reports the node *center*, not the cursor. Drive by raw coordinates with semantics off (script pattern in scratchpad `drive.js`; consider `/run-skill-generator` if we do this often).
- Infinite lines are drawn with far endpoints under a `clipRect`, reach scaled to anchor distance + canvas size — revisit only if extreme zoom-out shows artifacts.

## Session 6 — 2026-06-12

**Done**
- Phase 4 on branch `phase-4-providers` (2 commits + docs), merged to `main`. `lib/application/providers/` holds: `constructionProvider` (owns the `Construction`, bridges its listener API via a revision-counting `ConstructionState`; `replace()` swaps constructions for File > New/Open), `commandStackProvider` (wraps `CommandStack`; exposes `(canUndo, canRedo)` record), `selectionProvider` (selected-id set; prunes deleted ids), `viewportProvider` (`ViewportState` pan/scale only).
- 152 + 9 = 161 tests green, `flutter analyze` clean.
- `toolProvider` deferred to Phase 5 (TODO updated): the `Tool` interface doesn't exist yet, and designing it without Phase 5's canvas-input types would be guesswork.

**Next**
- Phase 5 (`lib/presentation/canvas/` + `lib/domain/tools/`): `Tool` interface + `toolProvider`, `Viewport` value type + transforms, `GeometryPainter`, `HitTester`, `GeometryCanvas`, `PointTool`, web smoke test.

**Open questions / gotchas**
- `@Riverpod(name: 'constructionProvider')` gives PLAN's provider names despite notifier classes being `ConstructionNotifier` etc. (a notifier class can't be called `Construction` — clashes with the domain class).
- `select` is not exported by `riverpod_annotation` — files needing it import `flutter_riverpod`. Fine in `application/`, never in `domain/`.
- Riverpod forbids touching `state` inside life-cycle callbacks (`ref.onDispose`): `ConstructionNotifier` keeps a `_construction` field mirroring `state.construction` for unsubscription. Keep the two in sync in `replace()`.
- `commandStackProvider` depends on the construction *instance* via `select` — NOT the revision — so undo history survives mutations but is dropped when `replace()` swaps constructions (undoing against a construction a command never touched would corrupt it). Don't "simplify" to a plain watch.
- `viewportProvider` stores state only; world↔screen transforms, zoom-about-focal-point, and scale clamping are deliberately left to Phase 5/8 gesture code. The presentation `Viewport` should be *built from* `ViewportState`, not duplicate it.
- Provider tests use plain `ProviderContainer()` + `addTearDown(dispose)`; no overrides were needed since providers wire to each other, not to injectables.

## Session 5 — 2026-06-12

**Done**
- Phase 3 complete on branch `phase-3-commands` (5 commits), merged to `main`. `lib/domain/commands/` holds: `Command` (abstract interface; LIFO-undo + replayable-apply contract documented), `AddObjectCommand`, `MoveFreePointCommand`, `DeleteObjectsCommand`, `TranslateObjectsCommand`, `ChangeAttributesCommand`, `MacroCommand`. `CommandStack` (plain class) lives in `lib/application/command_stack.dart`.
- New `Construction.setAttributes(id, attributes)` primitive so attribute edits notify listeners; covered in `construction_test.dart`.
- 139 tests green, `flutter analyze` clean.

**Next**
- Phase 4 (`lib/application/providers/`): `constructionProvider`, `selectionProvider`, `toolProvider`, `viewportProvider`, `commandStackProvider` — `@riverpod` code-gen (first riverpod_generator use; remember `dart run build_runner build --delete-conflicting-outputs`), bridging `Construction`'s listener API into a Notifier. Provider tests with overrides.

**Open questions / gotchas**
- Commands that capture state in `apply` (`DeleteObjectsCommand` batches, `TranslateObjectsCommand` before-positions, `ChangeAttributesCommand` previous values) are replay-safe: redo recaptures from the then-current construction. Don't share one command instance across two stacks.
- `DeleteObjectsCommand.undo` restores batches in *reverse* removal order — that's what makes cross-batch parent/child dependencies (select a parent and an unrelated root whose dependents interleave) restore validly. Don't "simplify" to forward order.
- `TranslateObjectsCommand` snapshots pre-move positions rather than applying `-delta`: float round-trip (`(x+d)-d ≠ x`) would break exact undo.
- `AddObjectCommand.undo` asserts (debug-only) that no dependents exist — out-of-order undo is a stack bug, not a user state.
- Commands validate up front (all-or-nothing): a bad id throws before anything mutates, so `CommandStack.execute` records nothing on failure.
- Mid-drag preview frames (direct `moveFreePoint` calls, no command) still notify listeners per frame — fine for repaint; Phase 5's gesture code must emit exactly one command per gesture on top of that.

## Session 4 — 2026-06-12

**Done**
- Phase 2 complete on branch `phase-2-construction-core` (3 commits), merged to `main`. `lib/domain/construction/` now holds: `ObjectAttributes` (freezed + json, first build_runner use — generated files are committed since CI doesn't run codegen), `GeoObject` base, the six minimal objects (`objects/` one file each), and the `Construction` DAG (insertion order = topological order; dependents lookup; cascade delete returning removed objects parents-first for restore; minimal pure-Dart listener API).
- 111 tests green, `flutter analyze` clean. Integration test: compass perpendicular-bisector construction (4-deep chain) tracks (A+B)/2 under dragging and survives degeneracy round-trips.

**Next**
- Phase 3 (`lib/domain/commands/`): `Command` interface, `AddObjectCommand`, `DeleteObjectsCommand` (holds `removeWithDependents` output), `MoveFreePointCommand`, `ChangeAttributesCommand`, `MacroCommand`; `CommandStack` lives in `application/` per PLAN.

**Open questions / gotchas**
- The hierarchy is sealed at the *kind* level (`GeoPoint`/`GeoLine`/`GeoCircle` in `geo_object.dart`), not on every concrete class — Dart's `sealed` requires same-library subtypes, which would conflict with one-file-per-object. Kind switches are exhaustive; concrete-type switches aren't.
- `Construction` is NOT a Flutter `ChangeNotifier` (domain layer can't import Flutter, contra PLAN's wording) — it has a hand-rolled `addListener`/`removeListener`. Phase 4 bridges it to Riverpod.
- `ObjectAttributes.colorArgb` is a raw ARGB int, null = theme default. Map to `Color` in presentation only.
- `IntersectionPoint` clamps its branch index at tangency (both branches sit on the single point) so branches separate cleanly again after a drag through tangency. Line∩circle branch identity is fixed by parent *type*, not argument order.
- Segments intersect via their infinite carrier line for now; clipping intersection points to segment extent is deferred (noted in `IntersectionPoint` doc).
- `Construction.restore` appends — z-order is not preserved across delete/undo. Revisit if/when z-order becomes user-visible.

## Session 3 — 2026-06-12

**Done**
- Phase 1 complete on branch `phase-1-math` (3 commits), merged to `main`. `lib/domain/math/` now holds: `Vec2` (+ shared `defaultEpsilon`), `LineEq` (normalized implicit form, unit normal → signed distance is one multiply-add), `CircleEq`, `intersections.dart` (line∩line/line∩circle/circle∩circle, all degenerate cases), `triangle_centers.dart` (centroid always defined; circumcenter/orthocenter/incenter return `null` on degenerate input).
- 74 tests green, `flutter analyze` clean. glados property tests use shared integer-grid generators in `test/domain/math/generators.dart` (no NaN, good shrinking) — reuse these.
- `test/domain/layer_rule_test.dart` enforces the no-Flutter-imports-in-domain invariant in CI from now on.

**Next**
- Phase 2 (`lib/domain/construction/`): sealed `GeoObject` + `ObjectAttributes` (freezed — first build_runner use), minimal object set (`FreePoint`, `Midpoint`, `LineThroughTwoPoints`, `Segment`, `CircleCenterPoint`, `IntersectionPoint`), then the `Construction` DAG with topological recompute.

**Open questions / gotchas**
- Two-point intersection results have a *documented deterministic order* (along line direction; first point left of the directed c1→c2 center line). Phase 2's `IntersectionPoint` must store its branch index against that contract.
- Triangle centers return `Vec2?` (null = degenerate). The construction layer needs an "undefined" object state to consume this — objects must survive a drag through a degeneracy and come back.
- Coincident lines/circles intersect in the empty list by design (no constructible point).
- Property tests gate out needle-thin triangles (`|cross| >= 1`) — the formulas are fine, the conditioning isn't; don't "fix" by loosening tolerances globally.

## Session 2 — 2026-06-11

**Done**
- Phase 0 complete on branch `phase-0-scaffolding` (3 commits): `flutter create . --empty` (web/android/ios, project name `fgex`), all runtime + dev deps pinned, strict `analysis_options.yaml`, GitHub Actions CI (`flutter analyze && flutter test --exclude-tags golden`), widget smoke test, committed `.claude/commands/continue-build.md`.
- CI gate verified locally: `flutter analyze` clean, `flutter test` green.

**Next**
- Merge `phase-0-scaffolding` to `main`, then start Phase 1 (`lib/domain/math/`): `Vec2`, `LineEq`/`CircleEq`, intersections, triangle centers, with unit + glados property tests.

**Open questions / gotchas**
- Riverpod codegen version dance: `riverpod_annotation` must stay at 4.0.2 (4.0.3 conflicts with `riverpod_generator` 4.0.3's analyzer bounds). Resolved set: `flutter_riverpod` 3.3.1 / annotation 4.0.2 / generator 4.0.3.
- `golden_toolkit` is discontinued (eBay archived it). Works today at 0.15.0; revisit before Phase 12 goldens — `alchemist` or plain `matchesGoldenFile` are candidate replacements.
- `flutter doctor`: Xcode installation incomplete, CocoaPods missing → iOS builds blocked until installed. Web + Android toolchains fully green; doesn't bite until the Phase 12 iOS smoke.
- Package name question from Session 1 settled: `fgex`.

## Session 1 — 2026-05-09

**Done**
- Brainstormed scope and architecture for the dynamic geometry app.
- Wrote `docs/PLAN.md` (architecture, layer separation, object catalog, persistence, test strategy, keyboard shortcuts, build order).
- Established the multi-session workflow: PLAN / STATUS / TODO / CLAUDE.md.
- Created `docs/TODO.md` (checklist mirroring the plan's build order) and `CLAUDE.md` (invariants + commands + session rituals).

**Next**
- Phase 0: install Flutter, initialise the project (`flutter create .` in the repo root), pin dependencies in `pubspec.yaml`, configure `analysis_options.yaml`, init git, set up CI placeholder.
- Then start Phase 1 (`lib/domain/math/`) — `Vec2`, line/circle types, intersections, triangle centers, plus their tests.

**Open questions / gotchas**
- Flutter is not yet installed on this machine. Install before next session (stable channel).
- Confirm package names: `flutter_riverpod` vs `riverpod_annotation` (we want code-gen providers via `@riverpod`).
- Decide repo name for `pubspec.yaml`'s `name` field — `fgex` or something more descriptive (e.g., `fgex_geometry`)?
- No git history yet — the next session should `git init` and make the first commit before any code is written.
