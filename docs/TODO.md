# Build TODO

Live checklist for the build phases described in `docs/PLAN.md`. Tick items as they land on `main` with `flutter analyze` clean and `flutter test` green.

Definition of done for each phase: code merged, tests passing, `docs/TODO.md` updated, `docs/STATUS.md` entry written.

## Phase 0 — Project scaffolding
- [x] Install Flutter (stable) and confirm `flutter doctor` (3.41.9; Xcode incomplete — iOS builds blocked until installed, web/Android fine)
- [x] `flutter create .` (web, Android, iOS targets)
- [x] Pin dependencies in `pubspec.yaml` (`flutter_riverpod`, `riverpod_annotation`, `freezed_annotation`, `json_annotation`, `vector_math`, `file_picker`, `shared_preferences`, `uuid`)
- [x] Pin dev dependencies (`build_runner`, `riverpod_generator`, `freezed`, `json_serializable`, `flutter_test`, `mocktail`, `golden_toolkit`, `glados`, `flutter_lints`)
- [x] `analysis_options.yaml` with strict lints
- [x] `git init`, initial commit, `.gitignore` review
- [x] CI placeholder workflow (`flutter analyze && flutter test`)

## Phase 1 — Pure math layer (`lib/domain/math/`)
- [x] `Vec2` + ops, with tests
- [x] `LineEq`, `CircleEq` value types
- [x] Intersections: line∩line, line∩circle, circle∩circle (degenerate cases handled)
- [x] Triangle centers: centroid, orthocenter, incenter, circumcenter
- [x] Property-based tests via `glados` for invariants
- [x] Layer rule check: no `package:flutter/*` imports (enforced by `test/domain/layer_rule_test.dart`, runs in CI)

## Phase 2 — Construction core (`lib/domain/construction/`)
- [x] Sealed `GeoObject` + `ObjectAttributes` (freezed) (sealed at the kind level — `GeoPoint`/`GeoLine`/`GeoCircle`; concrete objects stay one-per-file)
- [x] Minimal object set: `FreePoint`, `Midpoint`, `LineThroughTwoPoints`, `Segment`, `CircleCenterPoint`, `IntersectionPoint`
- [x] `Construction` DAG: insertion order, dependents lookup, topological recompute
- [x] Cascading delete with full restore data
- [x] Recompute correctness tests on chained dependencies

## Phase 3 — Commands & undo/redo (`lib/domain/commands/`)
- [x] `Command` interface
- [x] `AddObjectCommand`, `DeleteObjectsCommand`, `MoveFreePointCommand`, `TranslateObjectsCommand` (multi-point rigid translation — backs derived-object dragging), `ChangeAttributesCommand`, `MacroCommand`
- [x] `CommandStack` with undo + redo (plain class in `application/`; the Riverpod wrapper is Phase 4's `commandStackProvider`)
- [x] `undo(apply(c)) == c` round-trip tests
- [x] One drag = one command (not per-frame) — `MoveFreePointCommand`/`TranslateObjectsCommand` carry whole-gesture deltas; enforced at the gesture layer in Phase 5

## Phase 4 — Riverpod application layer (`lib/application/providers/`)
- [x] `constructionProvider` (revision-counting bridge over `Construction`'s listener API; `replace()` for File > New/Open)
- [x] `selectionProvider` (prunes deleted ids by listening to the construction)
- [x] `viewportProvider` (pan/zoom state only — transforms are Phase 5's `Viewport`)
- [x] `commandStackProvider` (watches the construction *instance*, so history survives mutations but resets on `replace`)
- [x] Provider tests (`ProviderContainer`-based; overrides not needed yet — no provider has an injectable dependency)
- toolProvider moved to Phase 5 — it needs the `Tool` interface, which Phase 5 designs

## Phase 5 — Canvas & first tool (`lib/presentation/canvas/`)
- [x] `Tool` interface (`lib/domain/tools/tool.dart`) + `toolProvider` (moved from Phase 4; `PointTool` landed with it to keep the interface honest — the Phase 5 smoke-test box below still covers wiring it to the canvas)
- [x] `Viewport` value type + transforms (landed as `CanvasViewport` — Flutter ships a `Viewport` widget; world is y-up, flip lives only here)
- [x] `GeometryPainter` (CustomPainter) (labels deferred to Phase 7 with the attributes work)
- [x] `HitTester` with priority order + 8 px threshold (landed as `CanvasHitTester` — flutter_test exports a `HitTester`)
- [x] `GeometryCanvas` widget with gesture stack (taps only; drag/zoom gestures are Phases 7–8)
- [x] `PointTool` end-to-end smoke test on web (headless Chrome via Playwright: 3 points placed, 2×undo, redo — all rendered correctly; plus widget tests for the same flow)

## Phase 6 — Object & tool coverage
- [x] Triangle centers (Centroid, Orthocenter, Incenter, Circumcenter) (objects + one `TriangleCenterTool` for all four via constructor tear-offs, incl. in-progress input markers — on branch `phase-6-objects`)
- [x] `PointOnObject` (point constrained to a curve) (fixed analytic parameter — `LineEq.pointAt`/`parameterAt`, `CircleEq.angleAt`; dragging *along* the curve re-sets the parameter and is Phase 7's business)
- [x] Two-point tools for the Phase 2 objects — line, segment, circle, midpoint (missing from the original list; one `TwoPointTool` + builder lambdas, needed to reach `PointOnObject` in-app)
- [x] Perpendicular & Parallel lines (`RelativeLine` template base; `PointAndLineTool` collects point + line in either order)
- [x] Angle bisector (`angleBisector` math + `AngleBisectorLine`; `ThreePointTool`, the reusable 3-point sibling of `TwoPointTool`)
- [x] Segment-ratio point (`SegmentRatioPoint`, fixed lerp parameter; reuses `TwoPointTool` — the ratio comes from a dialog before the tool activates, so the two-point menu's values are now async `TwoPointPick` factories)
- [x] Three-point circle, Compass circle (both reuse `ThreePointTool` from a new circles menu; app-bar highlights now key on canonicalized top-level builder tear-offs, resolving the Session 8 highlight gotcha)
- [x] Arc (3-point), Sector (both `GeoCircle` carriers with angular extent, mirroring `Segment`/`Ray` on `GeoLine`; new `math/angle_geometry.dart` sweep helpers; painter draws the branch/wedge, hit tester clamps to it)
- [x] Angle (between lines / at vertex) (`GeoAngle` — new 4th sealed kind, value = `AngleGeometry`; `VertexAngle` CCW arm→arm, `LineAngle` always acute at the crossing; marker wedge at fixed screen radius, picked at its vertex with lowest priority)
- [x] Ray (carrier `GeoLine` like `Segment`; painter half-line case + hit-tester extent clamp — segment/ray share one clamped-distance helper)
- [x] Tools for each of the above (arc/sector/vertex-angle reuse `ThreePointTool` from the circles + new angles menus; `TwoLineTool` collects two existing lines for `LineAngle`)

## Phase 7 — Selection & attributes
- [x] Multi-select (rubber band + shift-click) (tap selects / shift-tap toggles / empty tap clears; band from empty canvas takes what it *wholly* contains — infinite lines and rays never band; shift-band unions; halo drawn in theme tertiary)
- [x] Drag derived objects (rigid translation of free-point ancestors via `TranslateObjectsCommand`) (`DragSession` in `domain/tools/` previews per frame and rolls back before the one command commits; free point → `MoveFreePointCommand`; *derived points refuse to drag* — sliding `PointOnObject` along its curve is still open)
- [x] Attributes inspector panel (side panel, collapsed while nothing is selected; single selection shows kind + name editor — one `ChangeAttributesCommand` per rename; multi shows count + read-only list; hide/show and color/stroke controls land with their own items below)
- [x] Hide/show + label visibility (inspector checkboxes over the whole selection — tristate dash for mixed, one command per tap; painter now draws names beside a per-kind `labelAnchor`; hiding keeps the object selected, since the inspector is the only way back to un-hiding until the object tree lands)
- [x] Color, stroke width (swatch row — fixed palette + "Auto" for the theme-default null — and discrete width segments, so every tap is exactly one command; stroke width targets non-points, point size targets points, each control shown only when the selection has that kind)
- [ ] Cascading-delete UX with confirmation
- [ ] Object tree panel

## Phase 8 — Pan/zoom viewport
- [ ] Pinch-to-zoom on touch
- [ ] Scroll-to-zoom on web/desktop
- [ ] Two-finger pan / space-drag
- [ ] Fit / reset / nudge

## Phase 9 — Persistence & theme
- [ ] JSON codec (encode + decode in topological order, `version: 1`)
- [ ] Save / Open via `file_picker` (web download/upload + native picker)
- [ ] Light/dark theme palette tuned for canvas contrast
- [ ] Persist theme choice via `shared_preferences`
- [ ] Round-trip test on a complex construction

## Phase 10 — Macros / advanced shapes
- [ ] Square macro tool
- [ ] Parallelogram macro tool
- [ ] Trapezium macro tool
- [ ] Macro framework (groups primitive commands inside one undoable `MacroCommand`)

## Phase 11 — Keyboard shortcuts (`lib/presentation/shortcuts/`)
- [ ] `Shortcuts` / `Actions` wiring + central `ShortcutTable`
- [ ] All bindings from PLAN's shortcut tables
- [ ] Cheat-sheet overlay (`?`)
- [ ] Widget tests sending key events

## Phase 12 — Tests & polish
- [ ] Widget tests for representative tool flows
- [ ] Golden tests (light + dark) for each object kind
- [ ] Save/load round-trip on a non-trivial construction
- [ ] Manual cross-platform smoke (`flutter run -d chrome`, Android emulator, iOS simulator)
- [ ] `flutter build apk` and `flutter build ios` succeed
