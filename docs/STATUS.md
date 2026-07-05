# Status Log

Append-only journal of working sessions. Newest entries on top. Each entry should answer three questions in 5–15 lines: **what was done**, **what's next**, **gotchas / open questions**.

Write a fresh entry at the end of every session, before stopping. Do not edit older entries — if something turned out wrong, note it in the next entry.

---

## Session 25 — 2026-07-05

**Done**
- **Planning-only session** — no code. Enriched `docs/PLAN.md` + `docs/TODO.md` with six new phases (21–26) covering the 11 user-requested features/fixes, every design validated against the actual code first (three parallel exploration passes + one design pass):
- **Phase 21** random stamps: the 4–7-vertex random polygon is *replaced* by an always-strictly-convex random quadrilateral (gap-method angles on one circle — no radial jitter — plus a convexity-preserving affine stretch); `X 3`/`X 4` chords reverse Phase 16's menu-only decision.
- **Phase 22** angle-mark styling: `angleMarkerRadius` attribute (default 20 = today's constant), *automatic* right-angle square at exactly π/2, wedge fill via the existing-but-never-painted `fillAlpha` (same pass finally implements Sector fill); inspector angles slice with S/M/L/XL presets. Additive attributes — no version bump.
- **Phase 23** automatic naming: pure first-free allocator (`A…` points, shared `a…` lines+circles, `α…` angles) applied in a single interceptor at `ToolNotifier.handleInput` — the one `AddObjectCommand` funnel — naming only visible objects (macro scaffolding burns no letters); undo/redo-stable for free since `AddObjectCommand` re-adds the same instance. Lines/circles named but `labelVisible: false`; points show A, B, C by default.
- **Phase 24** whole-object transforms by macro composition (same kind rebuilt over transform-point images; no new kinds); orientation decided: reflected `VertexAngle` swaps arms, `Sector`+reflect-about-line excluded; new `TransformObjectTool` with transformee-first slot rule (curve hits must beat the Phase 20 point ladder).
- **Phase 25** mobile: compact gate (shortest side < 600), immersive status bar, toolbar as a scrollable 48-px strip, panels as drawers, pointer-kind snap radius (16 px touch / 8 px mouse), dash-selector overflow fix (–/S/M/L + bodySmall).
- **Phase 26** select-by-kind via tappable object-tree group headers (tap = replace, shift-tap = additive, long-press = additive on touch — user-requested).
- User decisions recorded in PLAN: replace (not keep) the random polygon; right-angle square is automatic, no toggle; select-by-kind lives on tree headers with long-press for mobile.

**Next**
- Open queue: Phase 19 (export, last pre-existing spec) and the new Phases 21–26 — 21 is the smallest starter; 23 (naming) should land before 24 (transforms) so image points get names without rework. Phase 12's two environment-blocked boxes (iOS build, Android emulator) still gate Phase 25's real-device smoke — its acceptance is widget tests + Chrome device emulation.

**Open questions / gotchas**
- Phase 25 must keep the wide layout byte-identical (desktop web smoke zero-diff); drive.js indexing assumptions (icon count, "theme toggle is last") will need re-checking when the compact chrome lands.
- Phase 21 removes the "Random polygon" Macros row — drive.js's macro section only touches Square (row 1), so it should survive, but re-verify.
- Phase 22 goldens: any existing golden scene containing an exact right angle will change (square replaces arc) — regenerate deliberately.

## Session 24 — 2026-07-04

**Done**
- Merged `phase-20-smart-point-placement` to `main`, then **Phase 16 complete** on `phase-16-angle-macros` (6 commits). In landing order:
- `AngleBySizeTool` (arm point, vertex; size from a degrees dialog): emits a `RotatedPoint` + a `VertexAngle` in one undo unit. A negative size swaps the marker's arms so it measures |size| on the clockwise side instead of the 2π complement. Angles flyout row + `G D` chord (settled in PLAN first — "degrees", `A` was taken); the rotation dialog generalized to `_askDegrees(title)` serving both tools.
- Triangle macros (PLAN input schemes first): **equilateral** = 2 taps, apex = `RotatedPoint` by +60° — no scaffolding, no branch, left of A→B; **isosceles** = 2 base taps + position-only apex projected onto the hidden perpendicular bisector (hidden `Midpoint` + `PerpendicularLine`); **right** = the rectangle's height-tap mechanics, right angle at B. All one `MacroCommand`, degeneracy round-trips tested.
- `RegularPolygonMacroTool` (side count via dialog, integer 3–100 else cancel): vertices chain as `RotatedPoint`s — v₍ₖ₊₁₎ = v₍ₖ₋₁₎ about vₖ by 2π/n − π — regular, continuous, scaffolding-free. `RandomShapeStampTool` (one class, 3–3 and 4–7 ranges): one tap stamps free points at *sorted* random angles (non-self-intersecting) and jittered radii scaled ≈10× the snap threshold; injected `math.Random` keeps tests deterministic; menu-only.
- Wiring: 6 new Macros rows, `X E`/`X ⇧I`/`X ⇧R`/`X G` chords (`_x` helper grew a `shift` flag for the second stroke), 4 `AppAction`s + main.dart cases, side-count dialog. 703 tests green (33 new), analyze clean, web smoke re-run on a fresh release build: **SMOKE PASS**, zero console errors (no drive.js changes needed — no new app-bar icons, Square stays the Macros menu's row 1).

**Next**
- Phase 19 (export) is the last speced phase; the two environment-blocked Phase 12 boxes (iOS build, Android emulator smoke) remain open. Consider a v0.1 tag after Phase 19.

**Open questions / gotchas**
- The Macros flyout (14 rows) now overflows the 600-px widget-test screen — menu taps on later rows need `scrollUntilVisible` (the sweep test does this now).
- The random stamps read the tap's `snapThreshold` to size the stamp (≈80 screen px at any zoom); a `ToolInput` built without it (tests, programmatic) falls back to 80 world units.
- `X I` (isosceles trapezium) vs `X ⇧I` (isosceles triangle) rely on the resolver's per-stroke shift matching; the table test's ambiguity sweep covers the pair.
- drive.js not extended with Phase 16 sections (widget + domain tests cover the flows — the parallelogram precedent).

## Session 23 — 2026-07-04

**Done**
- **Phase 20 complete** on `phase-20-smart-point-placement` (4 commits). User request: merge Point / Point-on-object and fix "snap to line doesn't work for the angle bisector" — exploration showed *no* point-collecting tool glued to curves (shared `MultiPointTool.collectVertex` only snapped to existing points), so one fix covers both.
- New shared resolver `domain/tools/point_resolution.dart` — the ladder: existing point → `IntersectionPoint` at the nearest in-threshold branch (GeoGebra-style crossing snap, user opted in) → `PointOnObject` on the ranked-best curve → `FreePoint`. Used by `PointTool` and `collectVertex`, so point/line/segment/circle/midpoint/angle-bisector/transforms/macros all snap identically. `IntersectionTool`'s private `_nearestBranch` generalized into the resolver's `nearestIntersectionBranch` (returns null when disjoint; the tool maps null → 0 to keep committing non-intersecting pairs).
- `ToolInput` gains `extraHits` + `snapThreshold` (defaults keep all ~85 existing call sites bit-identical; `snapThreshold: 0` disables crossing snap). `CanvasHitTester.hitTestAll` returns the ranked in-threshold list; `hitTest` is now its `firstOrNull`. `_handleTap` passes the full ranked list + threshold. `PointOnObjectTool` deleted; toolbar row removed (it had no shortcut/action, so `main.dart`/`shortcut_table` untouched).
- 670 tests green (analyze clean): new `point_resolution_test.dart` (14 cases incl. branch picking, threshold fall-through, rank-order tie-break), point/two-point/triangle-center tool tests flipped to the glued expectation, `hitTestAll` ordering tests. drive.js extended with a Phase 20 section (glue + crossing snap verified through the saved doc's object types): **SMOKE PASS**, zero console errors.
- Deliberate behavior change (in PLAN): a free point can no longer be dropped *exactly on* a curve — place off-curve and drag if wanted.

**Next**
- Merge `phase-20-smart-point-placement` to `main`. Then Phase 16 (angle-by-size + triangle/polygon macros) or Phase 19 (export) as before.

**Open questions / gotchas**
- drive.js: File > New pops the discard-confirmation dialog whenever the construction is non-empty — a scripted click sequence that assumes the menu just closes silently eats the next clicks. The Phase 20 section clears the canvas with Ctrl+Z instead.
- A macro corner glued to a curve routes the macro's rigid drag through that curve's free ancestors (consistent with existing derived-parent semantics, but new for macros).
- `PointOnObject`/`IntersectionPoint` still bind to infinite carriers, so a P-tap near a crossing just *past* a segment's endpoint can snap to a point off the drawn extent — same pre-existing wart as `IntersectionTool`.
- Crossing snap reuses the 8 px hit threshold; if it feels too eager/timid, tune the `snapThreshold` the canvas passes — no domain change needed.

## Session 22 — 2026-07-04

**Done**
- **Phase 15 complete** on `phase-15-transforms` (3 commits), merged to `main`. In landing order:
- Four transformation point kinds, planned names kept: `ReflectedPoint` (point + `GeoLine` mirror, via new `LineEq.reflect`), `CentralReflectionPoint` (half-turn about a center), `RotatedPoint` (fixed CCW angle in radians about a center, via new `Vec2.rotated`), `TranslatedPoint` (by the live vector between two points). All ordinary derived `GeoPoint`s — painter/hit-tester/drag untouched. Codec entries with no version bump (`RotatedPoint.angle` rides `params`); kitchen-sink round-trip covers all four. Math helpers glados-tested (double reflection identity, perpendicular-bisector swap — the PLAN test-strategy property — rotation preserves length and composes additively).
- Tools: reflect-about-line reuses `PointAndLineTool`, reflect-about-point `TwoPointTool`, translate `ThreePointTool` (tap the point first, then center / vector tail+tip); rotation is a dedicated `RotatedPointTool` over `MultiPointTool` because a `TwoPointTool` closure capturing the dialog angle could never be a canonicalized tear-off, which the toolbar highlight keys on. Angle dialog takes degrees (CCW, negative = clockwise), stores radians, shared by flyout + chord like the ratio dialog.
- New Transform flyout (`Icons.flip`, between Angles and Macros per PLAN); Points catch-all and Lines highlights now exclude the transform builders. Chords `G L`/`G P`/`G T`/`G V` (PLAN updated first; `G T` = "turn", `R` taken); the failed-chord resolver test moved from `G P` to still-unbound `G Q`.
- 652 tests green (37 new), analyze clean. Web smoke re-run on a fresh release build: **SMOKE PASS**, zero console errors — drive.js re-indexed for 11 icons (Macros moved to `icons[6]`), and the File menu now opens *right*-aligned (button sits left of the midline with 11 icons), so the Save click moved to `fileX + 30`.
- Housekeeping: `devtools_options.yaml` (user-deleted, tool-regenerated) is now gitignored.

**Next**
- Phase 16 — angle-by-size (`AngleBySizeTool` = arm point, vertex, size dialog → `RotatedPoint` + `VertexAngle`; rotation dependency now landed) + triangle/polygon macros (input schemes to spec in PLAN first). Then Phase 19 (export). The two environment-blocked Phase 12 boxes remain open.

**Open questions / gotchas**
- Menu-open alignment is now split across the app bar: File (left of the window midline) opens right-aligned, the flyout groups farther right open left-aligned. Any smoke click into a menu must pick the side per button — the old "every menu opens left" note no longer holds.
- The transform flyout/highlight relies on builder tear-off identity like the rest of the toolbar; `RotatedPointTool` must stay a distinct class (see the PLAN tool-system note) or its highlight falls into the Points catch-all.
- Tap order convention chosen for transforms: the point being transformed is always the *first* tap (then center, or vector tail → tip). GeoGebra-compatible; flyout labels spell it out.

## Session 21 — 2026-07-04

**Done**
- **Phase 14 complete** on `phase-14-drag` (3 commits), merged to `main`. In landing order:
- `PointOnObject` slide-drag: `Construction.setPointOnObjectParameter` (the constrained-point sibling of `moveFreePoint` — recomputes the point itself *then* its dependents) + `SetPointOnObjectParameterCommand` (from/to parameters, float-exact replay). `DragSession` refactored into an abstract base with `_TranslateDragSession` (the old behavior, unchanged) and `_SlideDragSession`: the host curve's analytic form is captured once at grab (the drag can't change the curve), the pointer projects onto it per frame with a grab offset so the point rides the pointer instead of jumping under the cursor. `PointOnObject.parameter` is now a mutable field. tool_provider/canvas needed zero changes — they only know the `DragSession` interface.
- `CompassCircle` center-only drag: one special case in `DragSession.start` — the translated set is `freePointAncestors(target.center)`. Radius points stay put (the radius is a measurement); a derived/constrained center drags its own free ancestors.
- Web trackpad mapping decided and shipped (PLAN updated first): Figma-style. Plain scroll = pan (content moves against the wheel delta — document-like for wheels, content-follows-fingers for natural trackpads), pinch = zoom about cursor via `PointerScaleEvent`, physical Ctrl/Cmd+scroll = zoom. Cheat-sheet gesture rows reworded.
- 615 tests green (13 new domain + 4 canvas widget tests incl. slide-on-circle, compass drag, scroll-pan/Ctrl-zoom/`PointerScaleEvent`), analyze clean. Web smoke reworked (zoom section holds Ctrl; new plain-scroll pan check asserts translation without spread change) and re-run on a fresh release build: SMOKE PASS, zero console errors.
- Post-merge user report, second stint (`phase-14-arrow-nudge`, merged): arrow-key nudge flipped from camera to **content semantics** — pressing → now moves the drawing right. The Phase 11 camera direction wasn't a regression, but the new content-follows scroll pan made it read as inverted; now every pan gesture moves content with the gesture. Widget test + smoke assertion flipped (shift +32 px), SMOKE PASS again.

**Next**
- Phase 15 — transformations: four derived-point kinds (reflect about line/point, rotate by fixed angle, translate by vector) + tools + codec entries + invariant tests. Then Phase 16 (angle-by-size, triangle/polygon macros) and Phase 19 (export). The two environment-blocked Phase 12 boxes remain open.

**Open questions / gotchas**
- `pannedByScreen` is *content-follows* ("content follows a rightward/downward delta" — its doc), not camera semantics: the scroll handler negates the wheel delta. Sign errors here read as inverted scrolling; the canvas test pins both axes.
- On the ±π atan2 cut of a circle host, a slide-drag's stored parameter can legitimately come back as −π where +π went in (same rim position — the parameter is periodic); tests assert position, not raw parameter, there.
- The angular grab-offset normalization keeps circle parameters within one turn of the principal range; without it, repeated grabs near the cut could accumulate +2π per gesture.
- A compass circle whose center's free ancestors overlap the radius pair's (e.g. center = midpoint of the radius points) *does* change radius when dragged — deliberate, the rule is "the center's ancestors".
- Playwright can't fake a browser pinch (the engine synthesizes `PointerScaleEvent` only for ctrl-flagged wheels with no physical Ctrl down; `keyboard.down('Control')` makes it a real Ctrl+scroll) — the pinch path is widget-tested, the smoke covers Ctrl+scroll.

## Session 20 — 2026-07-04

**Done**
- Plan-only session: **Phase 19 — Export** specced in PLAN/TODO, no code. PLAN gained an "Export (`application/export/`)" subsection after Persistence: PNG committed (off-screen `PictureRecorder` + existing `GeometryPainter` — never a widget screenshot, so no UI chrome; fit-vs-current-viewport framing via `fittedViewport`; 1×/2×/4× scale; theme vs transparent background; bytes out through the existing `saveFile(bytes:)`), SVG as an explicit stretch (hand-written writer mirroring the painter), PDF/clipboard out of scope. Export is read-only view work — no `Command`, not undoable, no save-format change.
- Build-order item 18, `Ctrl/Cmd + E` in the shortcut table (marked Phase 19), and the app-bar file-menu mention added; TODO gained the Phase 19 checklist (renderer, dialog + menu + shortcut, delivery/platform verify, tests, SVG stretch).
- Reverted the Phase 17B group-tooltip keys line (user request): group-icon tooltips no longer list shortcut keys — the dimmed trailing hints next to the flyout subtool names are the only place keys show. Dead `keys` computation removed from `_ToolGroup`, tooltip test updated, PLAN's toolbar bullet corrected. Analyze clean, toolbar tests green (6).

**Next**
- Phase 14 remains the top open *implementation* phase (slide-drag, compass-circle drag, trackpad pan); Phase 19 queues behind 14–16 unless the user pulls it forward.

**Open questions / gotchas**
- `Ctrl/Cmd + E` verified unbound today — re-check for collisions when Phase 15/16 bindings land, since those are still proposals.

## Session 19 — 2026-07-04

**Done**
- Phases 17 & 18 planned from user feedback (5 items: draggable labels, dashed lines, shortcut hints on tools, cheat-sheet icon, rectangle/isosceles-trapezium + more quad macros). PLAN/TODO updated first; user confirmed rhombus, kite and right trapezium join Phase 18, shortcut hints as trailing menu text, labels free-but-clamped, dash presets discrete.
- **Phase 17 complete** on `phase-17-polish` (5 commits). In landing order:
- 17A: cheat-sheet toggle `IconButton` (keyboard icon) between Reset and the theme toggle — placement keeps drive.js's "theme toggle is last enabled icon" indexing valid; only its order comment changed.
- 17B: `shortcutDisplayFor(AppAction)` over the shortcut table (first cheat-sheet-visible binding wins, hidden alternates like Ctrl+Y never surface); toolbar flyout tuples grew an `AppAction?`; rows render the key as dimmed trailing text inside a fixed-width `SizedBox` row (popup menus size intrinsically — `Spacer` misbehaves there); group tooltips list their keys on a second line.
- 17C: `ObjectAttributes.dashPeriod` (0 = solid, dash = gap = period/2, additive → no codec version bump); hand-rolled `dashPath` via `PathMetrics` (no dependency); painter routes all stroked kinds through it (angle markers + selection halo deliberately solid); inspector "Line style" Solid/Fine/Medium/Coarse = 0/4/8/16 on the strokes slice. Goldens regenerated (decorations scene gained a dashed segment + dashed circle).
- 17D: `labelDx`/`labelDy` screen-px attributes (defaults = the old hardcoded (6, −18), so old saves render identically); shared `labelScreenRect` in `label_layout.dart` keeps painter and grab rect in lockstep; label drag lives in move/select mode, hit-tests labels *before* geometry on pan-start (reverse insertion order = topmost), previews via a painter `labelDragPreview` override held as canvas widget state, clamps the offset radially to 40 px, commits exactly one `ChangeAttributesCommand` (cancel just drops the state).
- 564 tests green, `flutter analyze` clean, web smoke SMOKE PASS (10 enabled icons, zero console errors).
- **Phase 18 complete** too, same session, on `phase-18-quad-macros` (2 commits): `mirrorPointAcross` (`domain/tools/mirror_point_scaffolding.dart`) reflects a point across a line as hidden perpendicular → branch-0 line∩line foot → `SegmentRatioPoint` ratio 2 — single-valued and continuous when the point drags across the axis, which circle-branch mirroring can't be (fixed branch indices swap sides). Five `MultiPointTool` subclasses over it and the existing primitives, all pure compositions (codec/painter/hit-tester untouched, one `MacroCommand` each): **Rectangle** (2 taps + position-only height tap → C on the hidden perpendicular through B, D closes via parallel ∩ perpendicular), **Right trapezium** (3 taps, D = perpendicular-through-A ∩ parallel-through-C), **Rhombus** (2 taps + position-only direction tap → C rides a hidden `CompassCircle(A,B,center:B)` so |BC| ≡ |AB|, D via the parallelogram trick), **Isosceles trapezium** (3 taps, D = C mirrored across AB's perpendicular bisector), **Kite** (3 taps, D = B mirrored across the hidden diagonal segment AC). Macros flyout, `AppAction` switch and X R/H/K/I/L chords wired; PLAN's Phase-16 triangle chord proposals moved to `X ⇧I`/`X ⇧R`.
- 596 tests green (32 new domain tests: geometry invariants re-checked after drags incl. across-axis crossings, one-undo-unit, degeneracy round-trips, hidden scaffolding, position-only taps never consuming points; + a toolbar activation sweep), analyze clean, web smoke re-run on the final build: SMOKE PASS.

**Next**
- Phase 14 (drag & gesture fixes: `PointOnObject` slide-drag, compass-circle center-only drag, web trackpad pan mapping) is now the top open phase; then Phases 15–16 (transformations, angle-by-size + triangle/polygon macros). The two environment-blocked Phase 12 boxes remain open.

**Open questions / gotchas**
- The dash selector pushed the inspector's read-only multi-selection list below the 600-px test fold — `scrollUntilVisible` needed in one more test (the delete-button idiom).
- Widget-test label drags must beat the recognizer's pan slop (~36 px): a 20 px `moveTo` never fires `onScaleStart` and the test passes vacuously. The label tests move 30/30.
- Dashed *infinite* lines walk the full extended path (reach ≈ anchor distance + canvas size) through `PathMetrics` every frame — fine today; revisit only if a screenful of dashed lines ever drags.
- drive.js not extended with Phase 17 pixel sections (label drag needs inspector-driven naming first — heavy UI scripting); widget tests cover the flows, parallelogram precedent.

## Session 18 — 2026-07-04

**Done**
- **Phase 13 complete** on `phase-13-toolbar` (4 commits), merged to `main`. In landing order:
- `IntersectionTool` (`domain/tools/intersection_tool.dart`): collects two distinct curves — lines *or* circles, carriers count — like `TwoLineTool`, then commits one `IntersectionPoint`. Branch disambiguation: the branch nearest the *second* tap wins, resolved by constructing both branch objects as throwaway probes so the choice rides the documented deterministic branch order (no duplicated intersection dispatch). Non-intersecting curves still commit a branch-0 point (undefined until dragged together). The previously deferred `I` binding landed with it. 11 domain tests + editor-wiring and canvas-flow widget tests.
- Toolbar regrouped into five flyouts and extracted from `main.dart` (940→600 lines) to `presentation/panels/toolbar.dart` per PLAN's layout table: Points / Lines / Circles / Angles / Macros. Standalone Point, Point-on-object (and the hours-old Intersection) buttons plus the line-constructions and triangle-centers menus retired. Builders are now *public* canonicalized tear-offs shared by menus and the keyboard switch; the Points highlight is a catch-all for any `TwoPointTool` builder no tear-off claims (the segment-ratio closure captures its ratio, so it can never be one).
- Deselect affordances: double-clicking the active (highlighted) group icon deactivates its tool; the `GestureDetector` mounts *only while active*, so the double-tap-timeout delay on opening a flyout applies only then; the active tooltip appends "double-click to deselect". New `toolbar_test.dart` (4 tests) + a rewritten deactivation canvas test.
- Cheat sheet: `V` unhidden (was a deliberate Esc twin — user asked for it); new display-only `GestureRow` list renders Space+drag / scroll / two-finger / pinch rows in the Viewport section — the resolver never sees them.
- Web smoke re-indexed and re-run against a fresh release build: **SMOKE PASS**, zero console errors. 548 tests green, `flutter analyze` clean.

**Next**
- Phase 14 — drag & gesture fixes: `PointOnObject` slide-drag via a new `SetPointOnObjectParameterCommand`, `CompassCircle` center-only drag, and the trackpad pan-mapping decision for web (no drag-to-pan exists in the browser today; see the Phase 14 TODO entry for the full diagnosis). Start a `phase-14-drag` branch.
- The two environment-blocked Phase 12 boxes (iOS build, Android emulator smoke) remain open.

**Open questions / gotchas**
- With only 9 enabled app-bar icons the whole action cluster sits right of the window midline, so **every** `PopupMenuButton` menu — File included — now opens *left-aligned* to its button (Flutter grows menus toward the side with more room). drive.js clicks left of every icon; any future menu test near the right edge needs the same treatment.
- Opening a flyout whose tool is active waits out the double-tap timeout (~300 ms) before the menu appears — the accepted cost of the double-click-to-deselect affordance; it exists only on the active group. In widget tests, `pumpAndSettle` alone won't fire the delayed tap: `pump(kDoubleTapTimeout)` first (see `toolbar_test.dart`).
- `find.text('Point')` is ambiguous in widget tests when the inspector is open (kind header) — use `.last` for the flyout item.
- The `hit == null ||` guard in `IntersectionTool.onInput` is load-bearing: Dart flow analysis won't promote `GeoObject?` through `hit is! GeoLine && hit is! GeoCircle` alone (same as the Session 8 gotcha).
- PLAN's "adapt the toolbar to mobile with a bottom sheet" remains open — not scoped into any phase yet.

## Session 17 — 2026-07-04

**Done**
- Docs-only session: hands-on user feedback (11 items) folded into the plan as **Phases 13–16**. No code changed.
- `docs/TODO.md`: four new phases — Phase 13 toolbar rework & tool-selection UX (intersection tool + `I`, unified Points flyout, Circle → circles menu, two-point menu → Lines absorbing perpendicular/parallel/bisector, deselect affordances), Phase 14 drag & gesture fixes (`PointOnObject` slide-drag, compass-circle center-only drag, trackpad pan-zoom bug below), Phase 15 transformations (reflect about line/point, rotate, translate by vector), Phase 16 angle-by-size + triangle/polygon macros.
- `docs/PLAN.md` updated to match: Panels toolbar grouping rewritten (Points / Lines / Circles / Angles / Transform / Macros) + new tool activation/deactivation paragraph; Canvas dragging bullet gains the `PointOnObject` and `CompassCircle` exceptions; Points subclass list gains the four planned transformation points; Tool system gains the planned tools; `I` un-deferred, proposed `X E`/`X I`/`X R`/`X G` chords; Build order extended 12–15.
- Mid-session revision: the dedicated Drag tool (and a select-only no-tool default) was cut after discussion — dragging stays in the no-tool move/select mode, `V` unchanged. New web finding logged instead: three-finger trackpad pan on macOS also resizes the drawing on top of moving it (expected pure pan) → Phase 14. First hypothesis (`details.scale` drift in `_scaleUpdate`'s nav branch) was wrong — on web, trackpad swipes arrive as browser wheel events → `_handlePointerSignal` → zoom-about-cursor, which scales *and* shifts the drawing when the cursor is off-center; and a macOS three-finger drag is a synthetic mouse drag that rubber-bands. So there is no trackpad drag-to-pan on web at all (Space+drag / arrow keys only) — Phase 14 is a gesture-mapping decision, not a recognizer bug.

**Next**
- Start Phase 13 on a `phase-13-toolbar` branch. First concrete step: `IntersectionTool` (object already exists; tool + toolbar entry + `I` binding), then the menu regrouping in `lib/main.dart`.
- The two environment-blocked Phase 12 boxes (iOS build, Android emulator smoke) remain open and independent of Phases 13–16.

**Open questions / gotchas**
- Assumptions baked into the docs, to correct if wrong: "normal polygon" = regular polygon (n via dialog); "random" macros = one-tap stamps of randomized free points; angle-by-size = GeoGebra convention (arm point, vertex, size → rotated point + `VertexAngle`), which makes Phase 16 depend on Phase 15's rotation.
- Native desktop builds deliver trackpad gestures as PointerPanZoom into the scale recognizer's nav branch (not wheel events like the browser), so the Phase 14 mapping decision must be checked on both paths — they can end up with different behavior for the same physical gesture.
- `V` is bound to move/select but hidden from the `?` cheat sheet (`showInCheatSheet: false`, a deliberate Esc twin) — user noticed; surfacing it plus the pointer-gesture pan rows is now a Phase 13 item.
- Transformation-point class names (`ReflectedPoint`, `CentralReflectionPoint`, `RotatedPoint`, `TranslatedPoint`) are placeholders; refine at implementation per the naming convention.

## Session 16 — 2026-07-04

**Done**
- Phase 12 started on `phase-12-polish` (3 commits, merged to `main`) — everything except the two environment-blocked items landed.
- Goldens: the Session 2 decision resolved — `golden_toolkit` (discontinued) removed from `pubspec.yaml`, plain `matchesGoldenFile` instead, zero new dependencies. `test/presentation/goldens/object_kinds_golden_test.dart`: five scenes (points / lines / circles / angles / decorations — the last covers labels, custom color/stroke/point-size, a filled sector, selection halos, preview markers) × light + dark = 10 goldens, every concrete object kind rendered. Scenes framed by `fittedViewport`, background painted inside the `RepaintBoundary` (the real canvas paints over the scaffold, so the boundary needs its own `ColoredBox`). New `dart_test.yaml` declares the `golden` tag; CI's `flutter test --exclude-tags golden` verified to still run the other 520.
- Tool-flow widget tests: audit first — 15 sessions of per-phase coverage were already dense (creation flows with undo units, selection, drags, pan/zoom, file menu, every shortcut path). The one missing PLAN scenario landed in `geometry_canvas_test.dart`: circumcircle via the circles menu, apex vertex dragged — the circle recomputes per preview frame, lands equidistant from all three vertices, undo restores the dependent. Save/load round-trip box ticked with no new work (Phase 9's kitchen-sink codec test + `file_menu_test` + browser save check already cover it).
- Builds/smoke: `flutter build apk` ✓ (49.5 MB release, first Gradle run installed CMake). Full web smoke re-run on this branch against a fresh release build: SMOKE PASS, zero console errors. 531 tests green locally (520 in CI mode), `flutter analyze` clean.

**Next**
- The two remaining Phase 12 boxes are blocked on the environment, not code: (1) iOS — install Xcode from the App Store, `sudo xcode-select --switch`, `sudo xcodebuild -runFirstLaunch`, install CocoaPods, then `flutter build ios` + simulator smoke; (2) Android emulator smoke — approve a multi-GB system image (`sdkmanager "system-images;android-XX;google_apis;arm64-v8a"`), `flutter emulators --create`, then `flutter run -d emulator`. After those, Phase 12 (and the plan) is done; consider a v0.1 tag.
- Optional backlog if development continues: intersection *tool* (unblocks the `I` binding), sliding `PointOnObject` along its curve, angle hit-target world-radius hint, pending-leader indicator.

**Open questions / gotchas**
- Goldens are macOS-rendered pixels — regenerate with `flutter test --update-goldens --tags golden` on a Mac only; other platforms will diff. CI keeps excluding the tag.
- Golden labels render in the test framework's default Ahem font (solid boxes): label *position and metrics* are locked, glyph shapes are not. Don't chase font loading unless glyph regressions ever matter.
- `dart_test.yaml` now exists at the repo root; new tags must be declared there or `flutter test` warns.
- The decorations golden's filled sector at `fillAlpha: 0.25` is faint on the light canvas — deliberate (it matches the app), not a rendering bug.

## Session 15 — 2026-07-04

**Done**
- Phase 11 complete on `phase-11-shortcuts` (6 commits), merged to `main`. PLAN updated first: the stock `Shortcuts`/`Actions` sketch was replaced by a declarative `ShortcutTable` + pure `ShortcutResolver` + one root-`Focus` `AppShortcuts` widget — two-stroke leader chords (`G`/`X`) and the "stand down while an `EditableText` has focus" guard don't fit `ShortcutActivator`'s single-stroke model.
- Table (`shortcut_table.dart`): every PLAN binding incl. modifier axes (`shift: null` = don't-care for `=`/`+`; `primary` = Ctrl *or* Cmd), hidden alternates (numpad twins, Backspace, Ctrl+Y), `repeats` for viewport keys, cheat-sheet labels/sections. Table tests reject ambiguous bindings and leaders shadowed by single strokes. Deferred per PLAN: `I` (no intersection tool exists — users currently can't build one; macros do it internally) and Tab-cycle (needs cursor tracking).
- Resolver: single strokes win; leaders go pending (no timeout); Esc or a missed second stroke *swallows* the chord rather than firing the stroke standalone; pure-modifier presses don't cancel a pending leader. Key auto-repeat bypasses the resolver (a held leader would cancel its own chord) and only drives `repeats` bindings.
- EditorScreen owns the one exhaustive `AppAction` switch (a new binding without wiring fails to compile). Arrow-key nudge (camera semantics, 32 px) finally wires `CanvasViewport.pannedByScreen` from Phase 8; `=`/`-` zoom about the canvas center; `0` = 100 % keeping the center pinned (unlike Reset). Del/Backspace shares the inspector's cascade-confirmation via extracted `deleteSelectionWithConfirmation`. Two-point menu builders became top-level functions shared with the keyboard path.
- Cheat sheet (`?`): in-tree overlay, deliberately not a dialog route (a route's focus scope cuts `AppShortcuts` off from keys, so `?` couldn't toggle it closed). Esc only closes the sheet — the active tool survives; any other shortcut closes it and executes.
- 520 tests green, `flutter analyze` clean. Web smoke extended (real browser key events): Ctrl+Z removes the whole square macro in one step, `=`×2 spread ratio 1.440 vs 1.44 expected, ArrowRight −32.0 px, `?` barrier 765→459 luminance. SMOKE PASS, zero console errors.

**Next**
- Phase 12 — tests & polish: golden tests light+dark per object kind (remember the Session 2 decision point: `golden_toolkit` is discontinued — pick `alchemist` or plain `matchesGoldenFile` first), representative tool-flow widget tests, cross-platform smoke (`flutter build apk` / iOS — Xcode was incomplete in Session 2, check `flutter doctor` before betting on iOS). Start a `phase-12-polish` branch.

**Open questions / gotchas**
- Clicking the canvas refocuses the shortcut layer via `AppShortcuts.refocus` (a `Listener` wrapper in `EditorScreen`) — plain `unfocus()` would strand key events on a focus scope that isn't an ancestor of the shortcut node, killing all shortcuts. Keep that wrapper if the canvas gets rehosted.
- Shift+H (reveal all) also reveals hidden macro scaffolding — "all" means all, and it's one undoable command. Revisit only if it confuses in practice.
- `?` arrives as `question` on some platforms and shifted `slash` on others; the table carries both (the twin is cheat-sheet-hidden). Same pattern for any future punctuation binding.
- Browser-reserved combos (Cmd+N new window, possibly Cmd+D) can't be intercepted on web even though Flutter preventDefaults handled keys; the bindings still work on desktop and in the widget tests. Not worth chasing.
- No pending-leader UI: after pressing `G`/`X` nothing indicates the chord is armed. Add an indicator if chords prove hard to trust.
- Still open from earlier phases: intersection *tool* (now also blocks the `I` binding); sliding `PointOnObject` along its curve; angle hit-target world-radius hint.

## Session 14 — 2026-07-04

**Done**
- Phase 10 started on `phase-10-macros` (4 commits, unmerged — parallelogram/trapezium still to come). Square macro landed end to end.
- Framework first: `MultiPointTool.buildObjects` now returns a `List<GeoObject>` (one `AddObjectCommand` per object inside the same single `MacroCommand`; list must be in dependency order). The three existing subclasses wrap their single object — no behaviour change, all 462 prior tests untouched.
- `SquareMacroTool` (2 taps): tapped points are adjacent corners A, B; C and D are *derived* — branch-1 `IntersectionPoint`s of a hidden `PerpendicularLine` (through B resp. A, referenced on the visible side `Segment` AB) with a hidden `CompassCircle` of radius |AB|. Pure composition of existing kinds: codec, painter, hit tester all untouched. Branch 1 along the carrier's CCW normal ⇒ the square lies to the *left* of A→B; tap order picks the side, and the side follows drags continuously (the carrier direction comes from parent order and is never re-canonicalized — checked against `LineEq` before coding).
- App bar: new shape-macros menu (`Icons.crop_square`), highlighted while a `SquareMacroTool` is active. 469 tests green (`flutter analyze` clean): tool geometry, one-undo-unit, drag stays square, degeneracy round-trip, hidden-scaffolding attributes, plus a widget test driving menu → two taps.
- Web smoke extended (`tool/web_smoke/drive.js`, release build served statically per the Session 13 rule): square renders all four sides + corner dots; hidden perpendiculars leave no pixels past the side extents (side BC lies *on* perpB's carrier, so beyond-extent pixels are the discriminator); hidden circles invisible; interior empty. SMOKE PASS.
- Second stint: `ParallelogramMacroTool` (2 more commits, 6 total). Three taps = consecutive corners A, B, C; D = A + (C − B) as the single-branch line∩line intersection of two hidden `ParallelLine`s referenced on the visible sides AB/BC — no side ambiguity, unlike the square. Collinearity leaves D undefined and it recovers. Joined the shapes menu (highlight covers both macros). 474 tests green, analyze clean. Parallelogram is widget-tested only — the browser smoke's macro section still drives just the square (same machinery; extend if a regression ever suggests it).

- Third stint: trapezium — **Phase 10 complete** (10 commits), merged to `main`. PLAN updated first with the point story: 3 corner taps + a *position-only* 4th tap that projects D onto the hidden parallel-to-AB through C via `PointOnObject.near` (direct manipulation over a ratio dialog). To host a trailing non-point input, `MultiPointTool`'s collect and commit steps became callable hooks (`collectVertex` / `commitCollected`; base `onInput` unchanged) — `TrapeziumMacroTool` overrides `onInput`, holds the 4th tap in a field alive only inside the commit turn. The 4th tap never consumes an existing point (D must stay constrained; tested). Degenerate collections (A≈B ⇒ parallel undefined) fall back to `parameter: 0` instead of `.near`'s undefined-curve throw — and since the parameter rides the analytic form, D recovers *exactly in place* after a degeneracy round-trip (test asserts the exact position). 481 tests green, analyze clean, web smoke re-run: PASS.

**Next**
- Phase 11 — keyboard shortcuts (`lib/presentation/shortcuts/`): `Shortcuts`/`Actions` wiring, central `ShortcutTable` (PLAN has the full binding tables), cheat-sheet overlay on `?`, widget tests sending key events. Arrow-key viewport nudge wiring (`CanvasViewport.pannedByScreen` has waited since Phase 8). Start a `phase-11-shortcuts` branch. PLAN's macro chords (`X` `S`/`P`/`T`) now have all three tools to bind to.

**Open questions / gotchas**
- Popup menus that would overflow the right window edge open shifted *left* of their button — the smoke script clicks left of the icon for the shapes menu, unlike the file menu. Any future menu near the right edge needs the same treatment.
- The shapes menu added an enabled app-bar icon: drive.js now indexes the theme toggle from the *end* of the enabled-icon row instead of a fixed index (fresh app: 12 enabled icons, undo/redo greyed out). Keep the order comment in drive.js synced with `main.dart`.
- `Sector`'s fill-alpha styling precedent may matter if macros ever want filled interiors; the square deliberately has none (interior-empty is smoke-asserted).
- Still open from earlier phases: sliding `PointOnObject` along its curve; angle hit-target world-radius hint.

## Session 13 — 2026-07-04

**Done**
- Phase 9 complete on `phase-9-persistence` (5 commits), merged to `main`. PLAN updated first: encode + decode live in *one* centralized codec (`application/persistence/construction_codec.dart`) instead of per-class `toJson` — the type↔constructor registry must exist centrally for decoding anyway, and the domain layer stays persistence-free. The cost (a forgotten kind fails at runtime) is covered by a kitchen-sink round-trip test instantiating every concrete object kind.
- Codec: `version: 1` stamped, files with a newer version rejected; objects written in insertion (= topological) order, parents resolved by id on decode; viewport snapshotted outside undo history per the Phase 8 decision. Every decode failure — malformed JSON/UTF-8, unknown type, unknown/ill-kinded parent, duplicate id, constructor-level `ArgumentError` — normalizes to `FormatException` with the offending object's id, so File > Open shows one dialog for any bad file.
- File menu (app bar): New confirms before discarding a non-empty construction (replace drops undo history) and centers the world origin — closing the Session 12 open question; app *launch* is unchanged (no size before first frame). Save hands bytes to `FilePicker.saveFile` (writes on all platforms, download on web). Widget tests override `FilePickerPlatform.instance` with a hand-rolled fake (the mocktail route fails `verifyToken`).
- Theme: `AppTheme` pins primary (default object color) and tertiary (selection) with ≥ 3:1 WCAG contrast against the canvas (= scaffold background) in both themes, test-enforced. `main()` awaits `SharedPreferences` once, injects via ProviderScope override; `themeModeProvider` reads the stored choice synchronously, defaults to system, persists explicit choices; app-bar toggle flips against the *rendered* brightness.
- 462 tests green, `flutter analyze` clean. Real-browser smoke extended in-repo (`tool/web_smoke/drive.js`): Save's download parses as a version-1 doc carrying the placed points and the zoomed viewport (scale 1.822 = e^0.6); theme toggle drops canvas luminance 765→73 and survives a reload.

**Next**
- Phase 10 — macros: square / parallelogram / trapezium tools over the existing `MacroCommand` machinery. Start a `phase-10-macros` branch. (Phase 11 shortcuts and Phase 12 goldens after that; remember the `golden_toolkit` replacement decision from Session 2.)

**Open questions / gotchas**
- **Do not smoke-test against `flutter run -d web-server`**: the debug DWDS server wedges after the first Playwright session disconnects and then serves blank white pages. Serve `flutter build web --release` statically (README updated). Cost real debugging time this session.
- The smoke script indexes app-bar icons by *enabled* glyph runs — disabled undo/redo sit below the darkness threshold. The theme toggle is the last enabled icon (after fit/reset), not before them; keep drive.js's order comment in sync with `main.dart`'s actions row.
- `PopupMenuButton` items in the smoke script are hit by coordinates (menu opens over the button, 48 px rows, ~8 px top padding) — works, but recheck if menu contents change.
- Codec decode wraps constructor `ArgumentError`s (bad branch index, self-intersection, duplicate id) into `FormatException` at the `Construction.add` call site — new object kinds with constructor validation get file-error handling for free, but a new kind must be added to *both* codec switches (encode + decode); the kitchen-sink test fails loudly if forgotten.
- `ObjectAttributes.fromJson` throws `TypeError` (not `CheckedFromJsonException`) on ill-typed fields — the codec catches all `Object` there deliberately.
- File > Open keeps the *file's* viewport; Fit remains the recovery if a file was saved zoomed into nowhere. Still open from earlier phases: sliding `PointOnObject` along its curve; angle hit-target world-radius hint.

## Session 12 — 2026-07-04

**Done**
- Phase 8 complete on `phase-8-viewport` (4 commits), merged to `main`. PLAN updated first with the decision the Session 11 entry teed up: viewport changes are *view* state — never `Command`s, never undoable (same reasoning as selection); the viewport still gets snapshotted into the Phase 9 save format, just outside undo history.
- Scroll-zoom: `CanvasViewport.zoomedAbout` pins the world point under the cursor, scale clamped 0.05–50 px/unit; factor is e^(−dy·0.002) so scroll up/down round-trips exactly; wired through `Listener.onPointerSignal` + `PointerSignalResolver`.
- Pinch + pan: canvas moved from pan to *scale* callbacks (Flutter forbids both on one detector; scale also receives trackpad pan-zoom, which reports as ≥2 pointers). Two fingers or held space = navigation: `CanvasViewport.pinning` solves zoom+pan each frame from a per-gesture baseline (no accumulated error). Navigation latches until every pointer lifts; a band/drag interrupted by a second finger cancels, never commits.
- Fit / reset: pure `fittedViewport` over per-kind world bounds (points, full circle discs, angle vertices; lines contribute nothing — their defining points already count; single point centers at 100 %). App-bar Fit + Reset buttons; canvas size read via a `GlobalKey` at tap time. `CanvasViewport.pannedByScreen` backs nudge; arrow-key wiring is Phase 11's shortcut table.
- 420 tests green, `flutter analyze` clean. Real-browser smoke (Playwright + `flutter run -d web-server`): 3 wheel notches measured spread ×1.820 vs e^0.6 ≈ 1.822 expected, focal point pinned within 0.5 px, zero console errors.
- The Playwright drive script now lives **in-repo** at `tool/web_smoke/drive.js` (+README) — Session 7's died with its scratchpad; extend it per phase instead of rewriting.

**Next**
- Phase 9 — persistence & theme: JSON codec (`version: 1`, topological order), Save/Open via `file_picker`, light/dark canvas palette, theme choice in `shared_preferences`, round-trip test on a construction using every object kind. Start a `phase-9-persistence` branch.

**Open questions / gotchas**
- `ScaleGestureRecognizer` reports the focal point only at *acceptance* (past ~18 px slop) — the canvas `Listener` records the true down position for the band anchor and drag hit test. `dragStartBehavior` is back to the default `.start`: the anchor no longer comes from the recognizer, and `.start` re-baselines `details.scale` at acceptance so a pinch can't open with a jump.
- The scale gesture has no cancel callback; pointer-cancel rollback lives in `Listener.onPointerCancel`, and the recognizer's trailing `onEnd` then finds nothing to commit (`endDrag` without a session is a no-op — relied upon).
- On finger add/remove the recognizer fires `onEnd` + fresh `onStart`; `ScaleEndDetails.pointerCount` 0 vs >0 is what separates "gesture over" from "reconfiguring". Don't collapse the two paths.
- Widget-testing multi-touch: per-finger moves are sequential events, so the span breathes mid-frame. Separate the fingers *perpendicular* to the drag direction (span ≈ constant) or the accept-time baseline bakes a spurious zoom into the assertions.
- Default viewport still puts the world origin at the canvas top-left; Fit is the recovery. If Phase 9's File > New should open centered instead, decide it there.
- Still open: sliding `PointOnObject` along its curve when dragged; angle hit-target world-radius hint now that zoom exists (marker is screen-sized, tester is world-space).

## Session 11 — 2026-07-03

**Done**
- Phase 7 finished, all on `phase-7-selection` (8 commits), merged into `main`. In landing order:
- Click selection (tap selects / shift-tap toggles / empty tap clears; taps while a tool is active never touch the selection) + selection halos in theme tertiary; rubber band from empty canvas takes what it *wholly* contains (infinite lines/rays never band), shift-band unions.
- Dragging: free point → `MoveFreePointCommand`; derived object → rigid translation of its free-point *ancestors* via `TranslateObjectsCommand`. `DragSession` (domain/tools) previews per frame and rolls back before the single commit — one command per gesture, per the CLAUDE.md carve-out. Derived *points* refuse to drag (sliding `PointOnObject` still open).
- Attributes inspector (right panel, exists exactly while something is selected): kind header, name field (single only), visible/label tristate checkboxes, color swatches (fixed palette + "Auto" = null = theme default), discrete stroke-width/point-size segments (stroke targets non-points, size targets points; each shown only when the selection has that kind). Every tap = exactly one `ChangeAttributesCommand`; mixed state = dash / no highlight.
- Cascading-delete UX: Delete button in the inspector; confirmation dialog *only* when the cascade reaches beyond the selection, listing the unselected casualties; always one `DeleteObjectsCommand`. `Construction.transitiveDependentsOf` added (public, non-mutating) for the preview.
- Object tree panel (left, toggled from the app bar, hidden by default): flat list grouped by sealed kind in insertion order; rows select on tap / toggle on shift-tap; per-row eye flips `visible` one command per tap — hidden objects are now reachable again.
- Painter now draws labels beside a per-kind `labelAnchor`. 401 tests green, `flutter analyze` clean.

**Next**
- Phase 8 — pan/zoom viewport: pinch, scroll-zoom, two-finger pan / space-drag, fit/reset/nudge. Start a `phase-8-viewport` branch. `viewportProvider` and `CanvasViewport` already exist; the work is gestures + commands-or-not decision (view state is not construction state — probably *not* undoable, mirror the selection's reasoning and note it in PLAN if confirmed).

**Open questions / gotchas**
- Selection pruning listens to the construction and can lag a build by one frame — panels must null-filter `construction.byId(id)` instead of assuming selected ids exist (both panels do; keep the idiom).
- Freezed `copyWith` uses the `freezed` sentinel, so `copyWith(colorArgb: null)` genuinely sets null — that's how "Auto" works; don't replace it with a hand-rolled copyWith.
- `SegmentedButton` with `emptySelectionAllowed: true` models the mixed state; a tap on the already-selected segment arrives as an *empty* selection — treat as no-op, not "clear the width".
- Inspector/tree are lazy `ListView`s: widget tests must `scrollUntilVisible` anything below the 600-px fold (see the delete-button test) or the finder comes up empty.
- Shift detection is `HardwareKeyboard.instance.isShiftPressed` in both canvas and tree — keep them consistent if a third selection surface appears.
- Still open from Phase 6/7: sliding `PointOnObject` along its curve when dragged; angle hit-target world-radius hint for `CanvasHitTester` if vertex-only picking feels too small in practice.

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
