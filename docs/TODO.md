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
- [x] Cascading-delete UX with confirmation (Delete button in the inspector; a dialog appears only when the cascade reaches *beyond* the selection, listing the unselected casualties by name/kind — a self-contained selection deletes immediately; always one `DeleteObjectsCommand` = one undo step)
- [x] Object tree panel (toggled from the app bar, hidden by default; flat list grouped by sealed kind in insertion order; rows select on tap / toggle on shift-tap — canvas semantics, so hidden objects are finally reachable — plus a per-row eye flipping `visible`, one command per tap)

## Phase 8 — Pan/zoom viewport
- [x] Pinch-to-zoom on touch (canvas gestures moved from pan to scale callbacks — scale is the superset that also receives trackpad pan-zoom, which reports as ≥2 pointers; `CanvasViewport.pinning` solves zoom+pan per frame from a per-gesture baseline so error can't accumulate; the `Listener` records the true down position since the recognizer only reports the post-slop acceptance focal)
- [x] Scroll-to-zoom on web/desktop (exponential per-pixel factor about the cursor via `CanvasViewport.zoomedAbout` — the focal world point stays pinned; scale clamped 0.05×–50×; wired through `PointerSignalResolver`; viewport changes are deliberately *not* undoable, noted in PLAN) (exponential per-pixel factor about the cursor via `CanvasViewport.zoomedAbout` — the focal world point stays pinned; scale clamped 0.05×–50×; wired through `PointerSignalResolver`; viewport changes are deliberately *not* undoable, noted in PLAN)
- [x] Two-finger pan / space-drag (both are the same navigation baseline with `details.scale == 1`; a gesture that starts navigating stays navigation until every pointer lifts, and a band/drag interrupted by a second finger cancels rather than commits)
- [x] Fit / reset / nudge (app-bar Fit button — pure `fittedViewport` over per-kind world bounds: points/circle discs/angle vertices, lines contribute nothing; Reset button = origin at 100 %; nudge's viewport op landed as `CanvasViewport.pannedByScreen`, its arrow-key wiring belongs to Phase 11's shortcut table)

## Phase 9 — Persistence & theme
- [x] JSON codec (encode + decode in topological order, `version: 1`) (one centralized codec in `application/persistence/construction_codec.dart` — PLAN updated first; every decode failure normalizes to `FormatException` with the offending id; files newer than the app are rejected)
- [x] Save / Open via `file_picker` (web download/upload + native picker) (`saveFile(bytes:)` writes on every platform; File > New confirms before discarding a non-empty construction and centers the world origin — app *launch* still starts at top-left; widget tests fake `FilePickerPlatform.instance`)
- [x] Light/dark theme palette tuned for canvas contrast (`AppTheme` pins primary = default object color and tertiary = selection to explicit values with ≥ 3:1 WCAG contrast against the canvas in both themes, enforced by test)
- [x] Persist theme choice via `shared_preferences` (`main()` awaits the instance once and injects it via ProviderScope override so `themeModeProvider` reads synchronously; fresh installs follow the OS, the app-bar toggle flips against the rendered brightness)
- [x] Round-trip test on a complex construction (kitchen-sink test instantiates every concrete object kind — also the safety net for kinds missing from the codec — plus a real-browser check: Save downloads a valid document, dark theme survives a reload)

## Phase 10 — Macros / advanced shapes
- [x] Macro framework (groups primitive commands inside one undoable `MacroCommand`) (`MacroCommand` existed since Phase 3; the missing piece was `MultiPointTool.buildObjects` returning a *list* — one `AddObjectCommand` per object, dependency order, single undo unit)
- [x] Square macro tool (two taps = adjacent corners A, B; corners C, D are branch-1 intersections of hidden perpendiculars with hidden compass circles over the visible side AB — pure composition of existing kinds, so codec/painter/hit-tester untouched; square lies left of A→B and tracks drags continuously)
- [x] Parallelogram macro tool (three taps = consecutive corners A, B, C; D = A + (C − B) via two hidden `ParallelLine`s over the visible sides AB/BC and a single-branch line∩line `IntersectionPoint`; collinear taps leave D undefined until they separate)
- [x] Trapezium macro tool (PLAN updated first with the point story: three corner taps + a *position-only* fourth tap projecting D onto the hidden parallel-to-AB through C as a `PointOnObject` — AB ∥ CD by construction; the 4th tap never consumes an existing point; degenerate collections fall back to parameter 0 instead of `PointOnObject.near`'s throw)

## Phase 11 — Keyboard shortcuts (`lib/presentation/shortcuts/`)
- [x] `Shortcuts` / `Actions` wiring + central `ShortcutTable` (landed as a root `Focus` + pure `ShortcutResolver` instead — PLAN updated first: leader chords and the focused-text-field guard don't fit `ShortcutActivator`'s single-stroke model; the table stays the single source of truth)
- [x] All bindings from PLAN's shortcut tables (tools, G/X chords, undo/redo on either primary modifier, select-all, hide/reveal, Del/Backspace via the extracted `deleteSelectionWithConfirmation`, file, theme, zoom/fit/nudge — arrow-key nudge finally wires `CanvasViewport.pannedByScreen`; deferred per PLAN: `I` (no intersection tool exists) and Tab-cycle (needs cursor tracking))
- [x] Cheat-sheet overlay (`?`) (in-tree overlay, not a dialog route — a route's focus scope would cut `AppShortcuts` off from keys; Esc only closes the sheet, any other shortcut closes it *and* fires)
- [x] Widget tests sending key events (18 editor wiring tests + 4 cheat-sheet tests + table/resolver units; web smoke extended with a real-browser keyboard section — SMOKE PASS)

## Phase 12 — Tests & polish
- [x] Widget tests for representative tool flows (audit found 15 sessions of per-phase coverage already dense — creation flows, undo units, selection, drags, pan/zoom, file menu, every shortcut path; the one missing PLAN scenario landed: a circumcircle recomputing live under a real vertex-drag gesture, restored by undo)
- [x] Golden tests (light + dark) for each object kind (Session 2 decision resolved: discontinued `golden_toolkit` dropped for plain `matchesGoldenFile` — five scenes ×2 themes framed by `fittedViewport`, tagged `golden` via new `dart_test.yaml`; CI's `--exclude-tags golden` still skips them, regenerate with `flutter test --update-goldens --tags golden`)
- [x] Save/load round-trip on a non-trivial construction (already covered since Phase 9: the codec kitchen-sink test round-trips every concrete kind + attributes + viewport, `file_menu_test` drives Save/Open at the widget level, and the browser smoke parses a real downloaded document — no new work needed)
- [ ] Manual cross-platform smoke (`flutter run -d chrome`, Android emulator, iOS simulator) (web done — full `tool/web_smoke/drive.js` suite SMOKE PASS on a release build, zero console errors; Android emulator needs an AVD first, and no system image is installed — a multi-GB `sdkmanager` download to approve; iOS simulator blocked on the incomplete Xcode install)
- [ ] `flutter build apk` and `flutter build ios` succeed (`flutter build apk` ✓ — 49.5 MB release APK; `flutter build ios` still blocked: Xcode incomplete + CocoaPods missing since Session 2 — needs an App Store install and `sudo xcode-select --switch`, then `sudo xcodebuild -runFirstLaunch`)

## Phase 13 — Toolbar rework & tool-selection UX
- [x] `IntersectionTool` + toolbar entry + `I` shortcut (collects two distinct curves like `TwoLineTool` but accepting circles too; the branch nearest the *second* tap wins, resolved by probing both `IntersectionPoint` branches — no duplicated intersection dispatch; non-intersecting curves commit an undefined branch-0 point; standalone `join_inner` button for now, folds into the Points flyout below)
- [x] Unified **Points** flyout: free point, midpoint, segment-ratio point, intersection, point-on-object, centroid, orthocenter, incenter, circumcenter — retire the standalone Point and Point-on-object buttons and the Triangle-centers menu (toolbar extracted to `presentation/panels/toolbar.dart` per PLAN's layout table; builders are public canonicalized tear-offs shared with the keyboard switch)
- [x] Move Circle (center + rim point) from the two-point menu into the circles menu
- [x] Rename the two-point menu to **Lines** (line, segment, ray) and absorb perpendicular / parallel / angle bisector — retire the separate line-constructions menu
- [x] Deselect affordances: double-click on a flyout group icon deactivates its tool (deactivation `GestureDetector` mounts only while the group is active, so the double-tap delay on opening the menu applies only then); every tool now lives in a group, so the group-icon highlight is the one consistent indicator; the active group's tooltip appends "double-click to deselect"
- [x] Discoverability in the `?` cheat sheet: unhide `V` (bound to move/select but `showInCheatSheet: false` as an Esc twin) and add display-only rows for the pointer gestures (Space+drag pan, scroll zoom, two-finger pan, pinch) via a new `GestureRow` list the resolver never sees
- [x] Update the shortcut table, cheat sheet, and any goldens/smoke assertions touched by the toolbar change (goldens untouched — the scenes have no app bar; drive.js re-indexed for 9 enabled icons and re-run: SMOKE PASS. New gotcha: with 9 icons the whole action cluster sits right of the window midline, so *every* popup menu — File included — now opens left-aligned to its button; the script clicks left of the icons)

## Phase 14 — Drag & gesture fixes
- [x] `PointOnObject` slides along its host curve via new `SetPointOnObjectParameterCommand` (one command per gesture, preview/rollback per the existing `DragSession` contract — closes the open item carried since Phase 7; `DragSession` became an abstract base with translate + slide implementations; the pointer projects onto the curve's analytic form captured at grab time, with the grab offset normalized to a turn at atan2's ±π cut for circle hosts; `Construction.setPointOnObjectParameter` is the new mutation primitive, the constrained-point sibling of `moveFreePoint`)
- [x] `CompassCircle` drag moves only its center's free-point ancestors; the radius-defining points stay put (one special case in `DragSession.start`; a derived or constrained center drags through its own free ancestors — which may overlap the radius pair's, e.g. center = midpoint of the radius points, and then the radius does change: the rule is "the center's ancestors", not "anything but the radius points")
- [x] Trackpad pan mapping on web (decided: Figma-style — plain scroll = pan on both axes, content moves against the wheel delta; pinch = zoom about the cursor via the `PointerScaleEvent` the web engine synthesizes from a browser pinch's ctrl-flagged wheel; physical Ctrl/Cmd+scroll = zoom for mouse users; PLAN updated first, cheat-sheet gesture rows reworded, web smoke re-run with a Ctrl-held zoom section + a new plain-scroll pan check: SMOKE PASS. Native desktop is not a shipping target; its PointerPanZoom path already navigates correctly. macOS three-finger accessibility drag still rubber-bands — out of scope)

## Phase 15 — Transformations
- [ ] Four derived-point objects + tools: reflect about line (`ReflectedPoint`), reflect about point (`CentralReflectionPoint`), rotate around point by a fixed angle (`RotatedPoint`, angle via dialog), translate by vector (`TranslatedPoint`, vector given by two points) — names refinable at implementation
- [ ] Codec entries for the new kinds (+ version bump only if the schema shape changes); tests for every new `domain/` API — invariants: double reflection = identity, rotation preserves distance to center, translation preserves the vector

## Phase 16 — Angle-by-size & shape macros
- [ ] `AngleBySizeTool`: arm point, vertex, size dialog → `RotatedPoint` + `VertexAngle` (GeoGebra convention; depends on Phase 15's rotation)
- [ ] Triangle macros: equilateral, isosceles, right (input schemes to spec in PLAN before coding, like the square/parallelogram/trapezium)
- [ ] Random triangle + random polygon (one-tap stamps placing randomized *free* points, fully editable afterwards)
- [ ] Regular polygon (side count via dialog; "normal polygon" in the original feedback assumed to mean regular — correct here if wrong)
- [ ] New `X` chords (`E`/`⇧ I`/`⇧ R`/`G` proposed in PLAN — plain `X I`/`X R` went to Phase 18's quadrilaterals) + cheat-sheet entries

## Phase 17 — Discoverability & styling polish
- [x] Cheat-sheet app-bar button (keyboard icon between Reset and the theme toggle — keeps drive.js's "theme toggle is last" indexing; toggles the same `_showCheatSheet` state as `?`; widget test)
- [x] Shortcut hints in toolbar flyouts (`shortcutDisplayFor(AppAction)` lookup over the shortcut table — first cheat-sheet-visible binding wins; flyout item tuple gains an `AppAction?`; rows show dimmed trailing key text in a fixed-width row; group tooltips list their keys)
- [x] Dashed stroke style (`dashPeriod` on `ObjectAttributes`, 0 = solid, dash = gap = period/2; hand-rolled `dashPath` via `PathMetrics`; painter draws dashed strokes as Paths — angle markers and selection halo stay solid; inspector Solid/Fine/Medium/Coarse presets 0/4/8/16; codec kitchen-sink + golden updates)
- [x] Draggable labels (`labelDx`/`labelDy` screen-px attributes defaulting to the old (6, −18) constant; shared `labelScreenRect` in `label_layout.dart`; label hit before geometry hit on pan-start in move/select mode; preview as canvas widget state, offset clamped radially to 40 px; exactly one `ChangeAttributesCommand` per gesture; canvas widget tests + codec round-trip)
- [x] Verification: analyze + tests green, goldens regenerated (dash + label scenes), web smoke re-run with drive.js icon comment updated (564 tests, SMOKE PASS with 10 icons; the Phase 17 features themselves are widget-tested — drive.js pixel sections not extended, per the parallelogram precedent)

## Phase 18 — Quadrilateral macros
- [x] `mirrorPointAcross` scaffolding helper (hidden perpendicular + branch-0 foot + `SegmentRatioPoint` ratio 2 — continuous under drags across the axis, unlike circle-branch mirroring; own test file)
- [x] `RectangleMacroTool` (2 corner taps + position-only height tap; hidden perpendiculars through A/B + parallel-to-AB through C; D = branch-0 line∩line; documents the `PointOnObject` analytic-parameter caveat)
- [x] `RightTrapeziumMacroTool` (3 taps A, B, C; D = branch-0 intersection of perpendicular-through-A with parallel-to-AB-through-C)
- [x] `RhombusMacroTool` (2 side taps + position-only direction tap; C = `PointOnObject.near` on hidden `CompassCircle(A, B, center: B)`; D via the parallelogram trick; zero-radius/center-tap degeneracies fall back to parameter 0)
- [x] `IsoscelesTrapeziumMacroTool` (3 taps A, B, C; D = C mirrored across the perpendicular bisector of AB; UI label "Isosceles trapezium", equilateral-trapezium synonym noted in PLAN)
- [x] `KiteMacroTool` (3 taps apex A, side vertex B, apex C; hidden diagonal segment AC as the mirror axis; D = B mirrored; B on the diagonal = flat kite, not an error)
- [x] Wiring: Macros flyout rows + `macrosActive` check, `AppAction` entries, `X R`/`X H`/`X K`/`X I`/`X L` chords, cheat sheet auto-updates
- [x] Tests per tool (tap flow, invariant checked numerically and after dragging each free corner incl. across-axis drags, one undo unit, degeneracy round-trip, hidden scaffolding) + toolbar widget test + web smoke re-run (596 tests green, SMOKE PASS — Square stays the Macros menu's row 1, so drive.js's macro section is untouched)

## Phase 19 — Export
- [ ] Off-screen PNG renderer in `lib/application/export/` (`PictureRecorder` + `GeometryPainter`; fit-vs-current-viewport framing via `fittedViewport`; scale factor 1×/2×/4×; theme-color vs transparent background; no UI chrome — selection halos, in-progress markers, band never render)
- [ ] Export options dialog + File-menu "Export as PNG…" entry + `Ctrl/Cmd + E` shortcut + cheat-sheet row (export is read-only view work: no `Command`, not undoable, no save-format change)
- [ ] Delivery via existing `saveFile(bytes:)` in `file_io.dart`; verify on web (download) and Android (native picker)
- [ ] Tests: pixel check on exported PNG bytes for a known scene (decode + spot-check, or golden-style compare); widget test for the menu → dialog → save flow
- [ ] Stretch: hand-written SVG writer mirroring the painter per kind (`dashPeriod` → `stroke-dasharray`, labels as `<text>`) + "Export as SVG…" entry — may slip; PDF and clipboard-copy stay out of scope
