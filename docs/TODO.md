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
- [ ] `Vec2` + ops, with tests
- [ ] `LineEq`, `CircleEq` value types
- [ ] Intersections: line∩line, line∩circle, circle∩circle (degenerate cases handled)
- [ ] Triangle centers: centroid, orthocenter, incenter, circumcenter
- [ ] Property-based tests via `glados` for invariants
- [ ] Layer rule check: no `package:flutter/*` imports

## Phase 2 — Construction core (`lib/domain/construction/`)
- [ ] Sealed `GeoObject` + `ObjectAttributes` (freezed)
- [ ] Minimal object set: `FreePoint`, `Midpoint`, `LineThroughTwoPoints`, `Segment`, `CircleCenterPoint`, `IntersectionPoint`
- [ ] `Construction` DAG: insertion order, dependents lookup, topological recompute
- [ ] Cascading delete with full restore data
- [ ] Recompute correctness tests on chained dependencies

## Phase 3 — Commands & undo/redo (`lib/domain/commands/`)
- [ ] `Command` interface
- [ ] `AddObjectCommand`, `DeleteObjectsCommand`, `MoveFreePointCommand`, `ChangeAttributesCommand`, `MacroCommand`
- [ ] `CommandStack` (Riverpod-backed) with undo + redo
- [ ] `undo(apply(c)) == c` round-trip tests
- [ ] One drag = one command (not per-frame)

## Phase 4 — Riverpod application layer (`lib/application/providers/`)
- [ ] `constructionProvider`
- [ ] `selectionProvider`
- [ ] `toolProvider`
- [ ] `viewportProvider`
- [ ] `commandStackProvider`
- [ ] Provider tests with overrides

## Phase 5 — Canvas & first tool (`lib/presentation/canvas/`)
- [ ] `Viewport` value type + transforms
- [ ] `GeometryPainter` (CustomPainter)
- [ ] `HitTester` with priority order + 8 px threshold
- [ ] `GeometryCanvas` widget with gesture stack
- [ ] `PointTool` end-to-end smoke test on web

## Phase 6 — Object & tool coverage
- [ ] Triangle centers (Centroid, Orthocenter, Incenter, Circumcenter)
- [ ] Perpendicular & Parallel lines
- [ ] Angle bisector
- [ ] Segment-ratio point
- [ ] Three-point circle, Compass circle
- [ ] Arc (3-point), Sector
- [ ] Angle (between lines / at vertex)
- [ ] Ray
- [ ] Tools for each of the above

## Phase 7 — Selection & attributes
- [ ] Multi-select (rubber band + shift-click)
- [ ] Attributes inspector panel
- [ ] Hide/show + label visibility
- [ ] Color, stroke width
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
