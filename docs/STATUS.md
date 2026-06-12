# Status Log

Append-only journal of working sessions. Newest entries on top. Each entry should answer three questions in 5–15 lines: **what was done**, **what's next**, **gotchas / open questions**.

Write a fresh entry at the end of every session, before stopping. Do not edit older entries — if something turned out wrong, note it in the next entry.

---

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
