# Plan: stereometry milestone 2 — the space kernel, planes, and the active plane

Written 2026-11-24 from [spec](spec.md) · Status: approved 2026-11-24, in progress · Branch: `intent-004-stereometry`

Three stages. Each ends green on the full gate, with a look, and merges to `main`.

- **Stage A — points and lines in space.** Lift a point; segments, lines, rays, midpoints and parallels follow it.
- **Stage B — planes.** The plane kinds, what they intersect to, their patches and tools.
- **Stage C — the active plane.** Every 2D tool inside any plane.

## Files that change

| File | Change | Stage |
|---|---|---|
| `lib/domain/math/vec3.dart` | new view struct | A |
| `lib/domain/projective/space/point3.dart`, `plane3.dart`, `line3.dart`, `plane_frame.dart`, `space_metric.dart` | new: the kernel | A |
| `lib/domain/construction/geo_object.dart` | `sheet`, `spacePoint`, `spaceLine`, widened `isDefined`; the fourth exception in the class doc; `GeoPlane` (B) | A, B |
| `lib/domain/construction/objects/free_point.dart` | `height`, `chartPosition`, nullable `position`; `plane` (C) | A, C |
| `objects/segment.dart`, `ray.dart`, `line_through_two_points.dart`, `midpoint.dart`, `parallel_line.dart` | space value; 2D value only on a shared sheet | A |
| `lib/domain/construction/construction.dart` | `setFreePointHeight`; the seeding rule (C) | A, C |
| `lib/domain/commands/set_point_height_command.dart` | new | A |
| `lib/domain/tools/drag_session.dart` | a lifted point drags statically; a translation needs all free ancestors on one sheet, unlifted | A |
| `mutable_roots.dart`, the commands, other `FreePoint.position` callers | `chartPosition` | A |
| `objects/three_point_plane.dart`, `line_point_plane.dart`, `perpendicular_plane.dart`, `parallel_plane.dart`, `perpendicular_to_plane_line.dart`, `line_plane_intersection_point.dart`, `plane_intersection_line.dart` | new kinds | B |
| `lib/domain/tools/plane_tool.dart`, `perpendicular_to_plane_tool.dart`, `perpendicular_plane_tool.dart`, `parallel_plane_tool.dart`; `intersection_tool.dart` | new tools; line + plane, plane + plane | B |
| `lib/domain/construction/space_incidence.dart` | new: `liesIn` | C |
| `objects/chart_point.dart`, `chart_line.dart` | new: adapters | C |
| `lib/domain/tools/tool.dart`, `point_resolution.dart`, the six tools that build a `FreePoint` | `ToolInput.plane` | C |
| `lib/domain/tools/plane_scoped_tool.dart` | new: the wrapper | C |
| `lib/application/persistence/construction_codec.dart` | `h` and version 4 (A); plane kinds (B); `plane`, adapters, the shared-sheet check, orphan adapters dropped (C) | A, B, C |
| `lib/application/providers/active_plane_provider.dart` (+ `.g.dart`) | new | C |
| `lib/application/providers/tool_provider.dart`, `prover_provider.dart`, `construction_provider.dart` | new tools; the prover declines; the geometry switch is refused | B |
| `lib/presentation/canvas/canvas_viewport.dart` | `Vec3`; `pickPlane`; `sheetFor(frame)`; `hitRadius` widening removed | A, C |
| `lib/presentation/canvas/sheet_canvas.dart` | a general affine map | C |
| `lib/presentation/canvas/screen_figure.dart`, `space_hit_tester.dart` | new | A |
| `lib/presentation/canvas/geometry_painter.dart` | the space pass (A); patches (B); a group per sheet, active outline and grid (C) | A, B, C |
| `lib/presentation/canvas/lift_handle.dart` | new: geometry and paint of the handle | A |
| `lib/presentation/canvas/geometry_canvas.dart` | lift gesture, offset-plane drags, the screen hit test (A); plane taps (B); active-plane picks and the wrapper (C) | A, B, C |
| `label_obstacles.dart`, `label_layout.dart`, `fit_viewport.dart`, `space_view.dart` | screen primitives in the space view; fit and pivot over space bounds | A |
| `lib/presentation/panels/toolbar.dart`, `object_tree_panel.dart`, `object_kind_label.dart`, `attributes_inspector.dart` | the Space group; plane arms; internal objects filtered | B, C |
| `lib/main.dart` | open a version 4 document in the space view; the active-plane chip | A, C |
| every exhaustive kind switch (`object_naming.dart`, `label_anchor.dart`, `canvas_hit_tester.dart`, `transform_object_tool.dart`, `point_and_line_tool.dart`, and those above) | a `GeoPlane` arm | B |
| `docs/DECISIONS.md` | §"Sheets: a plane is a chart of one space" (A); §"Planes and structural incidence" (B, C); the M-3D note and Map; the version section gains v4 | A, B, C |
| `README.md` | the new tools | C |
| tests | below | |

## Order of work

**Stage A**

1. **Baseline** on a clean `main`: analyze, VM, browser, goldens. Counts recorded here.
2. **Kernel.** `Vec3` and `lib/domain/projective/space/`. Tests in `test/domain/projective/space/`:
   - join and meet against hand-computed cases; each exact degeneracy gives the zero vector and nothing near it does;
   - `glados`: (P ∨ Q) contains P and Q; (π ∧ σ) lies in both; line ∧ plane lies on both; `reciprocal` is zero for two lines through a common point and nonzero for a known skew pair;
   - `PlaneFrame`: `pull(lift(p)) == p`; `lift` preserves distances; pulling a line perpendicular to the plane gives the zero triple.
3. **Space values and the height** (one commit, no behaviour change: nothing sets a height). `sheet`, `spacePoint`, `spaceLine`, `isDefined`; `FreePoint.height` and `chartPosition`; `Construction.setFreePointHeight`; `SetPointHeightCommand`. Tests:
   - every kind in the kitchen-sink document has `spacePoint` or `spaceLine` equal to its 2D value at z = 0;
   - a lifted free point has null `projPoint` and `position`, a real `spacePoint`, and is defined; at height exactly 0 it is today's point, bitwise;
   - the command applies, undoes and redoes; dependents recompute once.
4. **The intrinsic kinds.** Tests per kind: on the base sheet the 2D value is bitwise what it was (the existing tests, unchanged); with one parent lifted, `projLine` is null and `spaceLine` is the join; a circle centred on the lifted point is undefined and returns when the height is set to 0.
5. **Codec.** `h`; `requiredFormatVersion` answers 4 for a nonzero height. Tests: a 2D document encodes to the bytes it did before (compared against a file written at step 1); a lifted document round-trips; the fixtures sweep is untouched; a version 5 file is refused as today.
6. **Painter space pass and the screen hit test** (one commit). `screen_figure.dart`, `space_hit_tester.dart`, the painter's pass for objects with no sheet, declutter obstacles from primitives, fit and pivot over space bounds, `hitRadius` widening removed. Tests:
   - goldens unchanged against step 1;
   - a lifted point's dot and a segment to it are drawn at `spaceToScreen` of their space values (recording canvas);
   - the hit test at Oblique picks a point by its screen distance along both axes, where the widened world radius picked the wrong one of two close points;
   - of two segments crossing on screen, the nearer is hit first;
   - with the space view off, `CanvasHitTester` is called exactly as before.
7. **Lift gesture.** `lift_handle.dart`, the canvas. Widget tests at wide and phone size: the handle appears for one selected free point at Oblique and not at Top; dragging the grip changes the height by the travel along the projected normal and leaves the point under the finger; release near the plane gives exactly 0; one command, and undo restores; dragging a lifted point keeps its height; a drawn segment follows.
8. **Open in the space view; DECISIONS; stage look.** A version 4 document turns the view on. Browser gate. Look per the stage rule below. Merge.

**Stage B**

9. **`GeoPlane` and the seven kinds**, with the arm in every exhaustive switch (planes are not yet painted: one commit that compiles and changes no picture). Tests per kind for value, for each exact degeneracy (collinear three points, point on the line, parallel planes, line parallel to plane), and for the frame's orthonormality and continuity under a small move.
10. **Patches, plane hit and selection.** Tests: patch corners contain the defining points with the padding; patches paint before strokes and back to front; a tap inside a patch hits the plane only when nothing else is in reach; goldens unchanged, plus one new golden of a plane through three points at Oblique.
11. **Tools and the toolbar group.** Tests per tool on the existing tool-test pattern; Intersection with line + plane and plane + plane; the Space group is absent with the view off and in a hyperbolic document; the prover declines and the geometry switch is refused with a plane present.
12. **Codec for planes; DECISIONS; `test/space_fixtures/pyramid_skeleton.rgl`** (square base, lifted apex, four edges, the plane OAB). Round-trip and version tests. Browser gate, look, merge.

**Stage C**

13. **`FreePoint.plane` and per-plane sheets.** `sheetFor(frame)`, general affine `SheetCanvas`, the painter grouped by sheet, `pickPlane`. Tests: for the base frame `sheetFor` is `flat` and `sheetMap` bitwise; a point drawn through a plane's sheet lands at `spaceToScreen` of its space value; a circle in a tilted plane has the projected ellipse's bounds; `pickPlane(spaceToScreen(lift(p))) ≈ p` and null in the band; goldens unchanged.
14. **Incidence and adapters.** `liesIn`, `ChartPoint`, `ChartLine`. Tests: each rule, and a point that coincides numerically but not by construction is refused; an adapter's value is the pull; adapters are skipped by the painter, hit test, naming and the tree.
15. **`ToolInput.plane` and `PlaneScopedTool`.** Tests: a point placed in an active plane is a `FreePoint` with that plane and moves with it; the circle tool in plane OAB on O and A builds a circle on that sheet through two adapters in one command, and one undo removes all three; a second circle reuses the adapters; a point not in the plane is dropped; the segment tool passes it through; two lines with a common plane intersect, two without are ignored.
16. **Active plane provider, chip, tap to activate, outline and grid.** Widget tests at both sizes: tap a plane, the chip names it; tap the chip, base again; New, Open, view off and undo of the plane all return to base.
17. **Tracing across sheets.** The seeding rule. Tests: a drag of a free point in a non-base plane across a tangent-and-chord configuration keeps its branch, as the same figure does in the base plane; a drag of a plane's defining point completes without a bail and with the plane's slots unseeded; `TraceDiagnostics` counts for a 2D corpus document are unchanged.
18. **Codec for `plane` and adapters; the acceptance figure.** In `pyramid_skeleton` with h = a/√2: in plane OAB, the perpendicular from O to AB meets it at H; H is the midpoint of AB and |OH| = a√3/2 to 1e-9, before and after a session-level drag of A.
19. **Browser gate, README, DECISIONS, look, close and ship.** Progress here, the status row, merge, push, `gh run list`, the deployed build. Ask the user to try the lift handle and a plane on their phone.

**Looks, each stage.** Ask before using Chrome and check `tabs_context_mcp` first; otherwise the headless release build with mouse and touch, at 1280 wide and at 400×800. Say plainly what was not seen.

## Risks

- **A last bit moves in 2D.** The widened `isDefined`, the intrinsic kinds' shared-sheet check and the painter's grouping all sit on the 2D path. Each takes the old branch first. A golden diff or a changed save byte is a stop.
- **`FreePoint.position` becoming nullable** reaches about ninety read sites outside presentation. Most want `chartPosition`. The ones that want "where it is drawn" must not get the foot. Step 3 goes through them one by one, not by replace-all.
- **The drag session assumes a free point has a 2D value.** A lifted point's drag must take the static path. If the session cannot be told that cheaply, the departure is recorded here.
- **The seeding rule may not be expressible where slots are chosen** (`construction.dart`, near the `doubleRootEpsilon` test). Fallback: a traced pass whose affected subgraph crosses a sheet bails to the static solve for the whole frame, and step 17's first test still holds because that drag crosses no sheet.
- **A general affine `Path.transform` on the web renderer.** Milestone 1 proved a squash. If shear differs, curves are sampled to polylines under a non-base sheet only.
- **The wrapper hides a tool's own duplicate checks from foreign objects**, so the same intersection could be built twice through two adapters. Adapter reuse per (object, plane) is what prevents it; step 15 tests it.
- **Stage size.** If stage C runs long, the tracing rule (step 17) can ship after the stage with the bail fallback in place.

## Proof

- Each step's tests green; the CI gate green at each stage end.
- Goldens unchanged from step 1 apart from the new files; a saved 2D document byte-identical to step 1's.
- `git diff main --stat -- test/fixtures test/v1_oracle` empty at every merge.
- The acceptance figure of step 18.
- The three stage looks and the deployed build.

## Progress and gotchas

- **Step 1, baseline** (`main` at `d252525`). Analyze clean; VM 3629 passed; goldens 35 passed; browser gate green.
- **Step 2, kernel.** 55 tests in `test/domain/projective/space/`. Notes:
  - The metric helpers are top-level functions in `space_metric.dart`, like `metric.dart`. The frame constructors are statics on `PlaneFrame` (`throughPoints`, `withAxis`, `horizontal`).
  - **The horizontal `u` is `ẑ × n`, not `n × ẑ`** as the spec first said: with it a vertical plane facing the viewer has `u` to the right and `v` up, and an upward horizontal plane gets the base axes. Spec amended.
  - `Line3.joinPoint` is oriented so the plane through a, b, c has its normal along ab × ac, the same hand as `PlaneFrame.throughPoints`.
  - The DECISIONS section is opened in this commit, because `decision_citations_test` needs a cited section to exist. It gains bullets as the steps land.
- **Steps 3 to 5, space values, the height, the intrinsic kinds, the codec** (one commit: the nullable `position` could not compile in parts). 24 new tests. Notes:
  - **`sheetFrame`, not `sheet`.** Until planes exist every object is on the base plane, so stage A carries only `GeoObject.sheetFrame` (the base frame). The sheet as an identity arrives with stage C, where something can differ.
  - **The intrinsic kinds' gate is "a parent has no value in the sheet"**, not "my own planar value is null". The second would have turned two coincident planar points into a defined space segment.
  - `FreePoint.position` nullable: 10 sites in `lib/`, about 440 in `test/`, fixed by a script driven by the analyzer's own error locations (`position!` at the declaration of a local where there was one, `chartPosition` for the setter). No test's meaning changed; every one of those points is unlifted.
  - `FreePoint.projPoint` is nullable too; `storedPoint` is the stored value whatever the height, for a pass that must save and restore it.
  - The byte-identity of a planar save is held by the existing v1 corpus (`kitchen-sink-v1.json` is compared against the live encoder) plus a test that no `h` is written.
  - `codec_v2_test`'s "v4 is refused" became "v5 is refused".
  - Until step 6 the painter and hit tester assumed `isDefined` meant a planar value. Nothing in the UI could lift a point yet.
- **Step 6, the space pass and the screen hit test.** 15 tests in `space_hit_tester_test.dart`, 2 in `geometry_painter_test.dart`, 5 in `drag_session_space_test.dart` (session level). VM 3729; goldens 35 with no diff. Notes:
  - **`screen_figure.dart` holds one function, `screenInkOf`,** and the label declutter was rebuilt on it instead of gaining a second copy. Planar ink is laid out in `viewport.flat` with the formulas the declutter always used and then carried through the sheet map, so with no tilt every number is the one it was, and under tilt a circle's obstacle is now the ellipse it is drawn as (milestone 1's declutter concern, closed).
  - **Depth decides only inside a 4 px distance band**, between objects of one priority. A plain (priority, distance, depth) order would never reach depth, since two distances are never equal.
  - **The plan view uses the screen tester too when something is lifted.** The spec said the world tester runs untouched with the view off; it does, for every document with nothing lifted. `CanvasHitTester` skips space-drawn objects so it cannot dereference a missing planar value.
  - `hitRadius` stays, as the snap threshold tools receive. Its widening is no longer a hit radius.
  - `SpacePoint` (a record) became `Vec3` throughout presentation.
  - A lifted point's drag reads the pointer at its height (`footScreen`), so nothing in the drag session changed. Rigid translation of an edge to a lifted point works as it is: all free points are on one sheet in stage A. The plan's "a translation needs all free ancestors on one sheet" belongs to stage C.
  - Fit with a lifted point frames the planar bounds' corners and the lifted points' images; a figure with nothing lifted takes the old code.
- **Step 7, the lift gesture.** 8 widget tests (group "the lift handle" in `geometry_canvas_test.dart`, mouse and touch), 6 in `lift_session_test.dart`, 10 in `lift_handle_test.dart`. VM 3753; goldens 35, no diff; browser 17. Notes:
  - The gesture's session is `LiftSession` in `lib/domain/tools/`, held by the tool notifier beside the drag session; `endDrag` and `cancelDrag` end whichever is live, so the canvas's pan end and cancel paths did not fork.
  - The reading is taken against the handle as it was when grabbed, from the pointer's start. Reading against the live handle would feed the grip's own motion back into the height.
  - The handle is checked before labels and objects in `_panStart`, and a tap on the grip is swallowed so it cannot clear the selection that shows it.
  - **The snap is 8 px, not the hit threshold** the spec named. On touch the threshold is 16 px, and a point that will not leave its plane for the first 16 px of a drag feels stuck.
  - The hint chip (`LiftedPointHint`) sits where the name-points chip sits; the two never show together, since one needs a tool and the other needs none.
  - Gotcha: in the widget harness the default camera puts the first test point 54 px from the top of the canvas, so its grip is off screen. The handle tests use the second point.
  - **Not tested: File > Open turning the space view on** for a version 4 document. `hasSpaceContent` is tested; the open path goes through the platform file picker, as in milestone 1.
- **Step 8, stage A look.** The release wasm build on 127.0.0.1 in a separate headless Chrome over the DevTools protocol, with real mouse and touch events, read from screenshots. The Chrome extension was not used.
  - Seen at 1280 wide: a quadrilateral ABCD and a point E inside it, joined by eight segments; the 3D button tilts it; a tap on E shows the grip above it with its stem; dragging the grip 150 px up raises E by 150 px and the four edges to it follow, with a dashed drop line and a ring at the foot; a drag on empty canvas turns the pyramid about its own centre (55° on the compass); dragging E by its body moves it under the pointer at the same height, the foot moving with it.
  - Seen at 400×800 with touch: Fit frames the whole pyramid, apex included; a touch drag of the grip raises the apex, with 16 px of sideways travel ignored; a second touch drag lowers it again.
  - **Not seen in a browser**: the snap back to exactly 0, the hint chip, opening a version 4 file, and the plan view with a lifted point. Those rest on the widget and unit tests.
  - Fit on the phone leaves the pyramid at about a third of the canvas height: it frames the corners of the planar bounds' axis-aligned box, which is wider than the base itself once the camera has turned. Correct, and looser than it could be.
  - Gotcha, again: the phone metrics override dies with the DevTools session, the layout goes wide, and the app bar's scroll offset resets. A run that scrolls the bar must tap in the same run.
- **Stage A closed 2026-11-24.** Final gate: analyze clean; VM 3753 (baseline 3629); goldens 35, no diff; browser 17; `flutter build web --wasm` built. `git diff main --stat -- test/fixtures test/v1_oracle` is empty.

- **Stage A shipped**: merged and pushed to `main` (`65bc15b`); Deploy and Benchmarks green.
- **Steps 9 to 12, planes** (stage B, in one working pass, committed together). Tests: 19 in `plane_kinds_test.dart`, 17 in `plane_tools_test.dart`, 15 in `plane_patch_test.dart`, 3 in `space_fixture_test.dart`, 3 more in `codec_space_test.dart`, the space kinds added to the codec's round-trip sweep, 3 toolbar tests, 2 canvas tests, 1 prover and 1 geometry-menu test; one new golden, `space_kinds_light`. VM 3815; goldens 36, the old 35 unchanged. Notes:
  - **Steps 9 and 10 were not separated.** A plane with no picture is not a state worth a commit, and the arms in the exhaustive switches are where the picture is decided.
  - `hasSpaceContent` moved to `lib/domain/construction/space_content.dart` so the prover provider can read it without importing presentation; `space_view.dart` re-exports it.
  - **A third kitchen-sink builder, `buildSpaceKinds`**, beside `buildPostV1Kinds` and for the same reason: its documents are version 4, and the other two must stay version 1.
  - The patch is the bounding box in the plane's *frame*, so a face whose frame is oblique to its triangle (`u` along OA) gets a patch larger than the triangle needs. Seen in the golden. Correct; a tighter rule (the hull, or a frame chosen for the patch) is a later choice.
  - Shortcuts: `G W` plane, `G ⇧ W` parallel plane, `G J` perpendicular to a plane, `G ⇧ J` plane perpendicular to a line.
  - **Not done from the plan: the `attributes_inspector` arm.** The inspector shows the common attributes for a plane (colour, stroke, fill, name, visibility) through its existing generic rows; nothing kind-specific was needed.
  - Gotcha: with the space view on and the Space group present, the app bar is one button wider than the 1280 px test window shows, and Redo, the last button, is past the edge. A widget test that taps Redo there misses silently and fails later; go through the command stack.
  - The fixture `test/space_fixtures/pyramid_skeleton.rgl` already reads the base-to-face dihedral as arctan √2 off the face's normal.

**Next: stage B close** (browser gate, look, merge), then **stage C, step 13**.

