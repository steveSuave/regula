# Plan: stereometry milestone 1 — the 3D view and its camera

Written 2026-11-24 from [spec](spec.md) · Status: done 2026-11-24 · Branch: `intent-004-stereometry`

## Files that change

| File | Change |
|---|---|
| `lib/application/providers/viewport_provider.dart` (+ `.g.dart`) | `ViewportState` gains `tilt` and `panZ` |
| `lib/application/providers/space_view_provider.dart` (+ `.g.dart`) | new session `bool` |
| `lib/presentation/canvas/canvas_viewport.dart` | tilt-aware transforms, `pickBasePlane`, `sheetMap`, `flat`, `orbitedAbout`, capped `visibleWorldBox` |
| `lib/presentation/canvas/sheet_canvas.dart` | new: the painter's adapter |
| `lib/presentation/canvas/geometry_painter.dart` | draws through `SheetCanvas`; flat visible rectangle |
| `lib/presentation/canvas/label_layout.dart` | anchors through the sheet map, if not already covered by `worldToScreen` |
| `lib/presentation/canvas/geometry_canvas.dart` | orbit gesture, `pickBasePlane` at taps and drags, tilt-scaled hit radius |
| `lib/presentation/canvas/fit_viewport.dart` | fit at a given tilt |
| `lib/application/export/png_exporter.dart` | carries tilt through its framings |
| `lib/main.dart` | the 3D button, the Views menu, Fit and Reset in the space view, off on New and Open |
| `test/application/providers/viewport_provider_test.dart`, `space_view_provider_test.dart` | state defaults, equality |
| `test/presentation/canvas/canvas_viewport_test.dart` | the transform tests below |
| `test/presentation/canvas/sheet_canvas_test.dart` | new |
| `test/presentation/canvas/geometry_painter_test.dart`, `geometry_canvas_test.dart`, `fit_viewport_test.dart` | tilt cases |
| `test/presentation/space_view_flow_test.dart` | new: the button, presets, gestures end to end, wide and phone |
| `test/presentation/app_bar_layout_test.dart` | the row with the new buttons |
| `test/web/web_renderer_test.dart` | tilted dashed circle, pixel probe |
| `test/presentation/goldens/` | two new goldens (oblique, front); the existing ones untouched |
| `docs/DECISIONS.md` | new §"The space view is a camera over one document" and a Map entry |
| `README.md` | one line on the 3D view |
| `intent/README.md`, this folder | status, progress |

## Order of work

1. **Baseline**, from a clean worktree at `main`: `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`, and the golden suite (`flutter test --tags golden`). Record the counts here.
2. **Camera state and transforms** (one commit, no behaviour change: nothing sets a tilt yet). `ViewportState`, `CanvasViewport`. Tests:
   - at tilt 0, every transform equals the pre-change result on random states (`glados`), compared bit for bit against a copy of today's formulas kept in the test;
   - `pickBasePlane(worldToScreen(p)) ≈ p` at random tilts outside the edge-on band; null inside it;
   - `worldToScreen` of a base-plane point equals `sheetMap` applied to `flat.worldToScreen`;
   - `orbitedAbout` keeps the pivot's screen position, including at tilt 90°;
   - `pannedByScreen` and `pinning` move the picture by exactly the requested screen delta at tilt 90° (the `panZ` case);
   - `visibleWorldBox` stays within its cap at tilt 89.9°.
3. **`SheetCanvas` and the painter** (one commit, no behaviour change at tilt 0). Tests:
   - at identity, the adapter's recorded calls equal the calls the painter made before, for one document of every kind;
   - under tilt, a circle's drawn path has the squashed bounds, its stroke width is unchanged, and a point's dot radius is unchanged;
   - dash segment lengths are equal along a tilted circle, within tolerance;
   - the golden suite has no diff against step 1.
4. **Gestures** (one commit). `spaceViewProvider`, orbit, picks, hit radius. Tests in `geometry_canvas_test`:
   - space view off: an empty-canvas drag opens the band, exactly as today;
   - on: the same drag changes rotation and tilt, opens no band, and the figure centre's screen position holds;
   - on, tool active: a drag orbits; a tap places a point whose screen image is the tap position;
   - on: dragging a free point leaves it under the finger and commits one command; undo restores it;
   - on, tilt 89°: a tap places nothing and a drag on a point moves nothing;
   - two-finger pan and pinch pin the focal at tilt 60° and at 90°;
   - orbit end snaps a near-level tilt to exactly 0.
5. **App bar, presets, Fit, Reset, export, DECISIONS** (one commit). `space_view_flow_test` at wide and phone sizes: the button toggles; on goes to Oblique; each preset sets its angles; off returns tilt to 0 with the centre point held; New and Open turn it off; Fit at Oblique leaves every object's screen image inside the canvas. `app_bar_layout_test` passes at phone width with the view on. Exporter test: a tilted export's pixel at a known point's projected position is that point's colour.
6. **Browser gate and goldens** (one commit). The `test/web` case; the two new goldens, generated on macOS.
7. **README** (one commit).
8. **Looks.** Ask before using Chrome, and check `tabs_context_mcp` first. `flutter run -d chrome` in a narrow real window: orbit, presets, place and drag a point at Oblique, pinch. Then the parked phone smokes: check for an AVD and a complete Xcode with CocoaPods; run the Android emulator and iOS simulator smokes if they exist, and say plainly if they do not.
9. **Close and ship.** Progress and gotchas here, status row in `intent/README.md`, merge to `main`, push, `gh run list`, and a look at the deployed build. Ask the user to try orbit on their phone at the deployed URL, since a touch feel cannot be judged from a test.

## Risks

- **A float differs at tilt 0.** Any `* cos(0)` or `+ 0 * x` on the hot path can flip a last bit and move a golden. The early return in step 2 and the bit-for-bit test are the guard; a golden diff in step 3 is a stop, not a regenerate.
- **`Path.transform` on arcs differs between renderers.** If the browser gate shows it, the adapter samples in-plane arcs to polylines under tilt only (the `_drawLargeCircleRim` precedent), and this plan records the departure.
- **Dashing after the transform changes a dash phase at identity.** The adapter must not re-dash at identity; it forwards the painter's already-dashed path. Covered by the identity call-log test.
- **Orbit steals a gesture.** A one-finger drag that starts a few pixels off a point orbits instead of dragging it. The hit radius is the existing touch radius, widened under tilt; the user's phone trial in step 9 is the real check.
- **The scale recognizer's slop** (about 18 px) delays orbit start, as it delays the band today. Orbit is computed from the recorded first-down position, so the camera does not jump when the gesture is accepted.
- **Phone toolchain missing.** The parked item says an AVD and a full Xcode install are needed. If absent, step 8 reports it and the phone proof is the browser's touch emulation plus the user's own device.

## Proof

- Steps 2 to 5 tests green; the full CI gate green.
- The golden suite unchanged between step 1 and step 6, apart from the two new files.
- `git diff main --stat -- lib/domain test/fixtures lib/application/persistence` is empty.
- Step 8's looks, and the deployed build after step 9.

## Progress and gotchas

- **Step 1, baseline** (clean worktree at `main`, `b74dfa2`). Analyze clean; VM 3566 passed; goldens 32 passed.
- **Step 2, camera state and transforms.** 12 new tests in `canvas_viewport_test.dart`. Departures from the plan:
  - **The visible-region cap is the pick floor, not eight diagonals.** `flatFrame` pulls the canvas back through the sheet map with `|cos tilt|` held at `pickFloor` (0.05), so the frame is exact wherever the plane can be picked and at most twenty canvas heights tall inside the edge-on band. One constant now answers both "can this be picked" and "how far is the clip bound".
  - **The pan is kept on the base plane away from edge-on.** `pinning` slides the pan along the view direction to `panZ == 0` whenever the plane is pickable, so `panZ` is nonzero only inside the edge-on band and the sheet map is a pure squash everywhere else.
  - **Random states come from a seeded `Random`, not `glados`**: no presentation test uses glados, and the bit-for-bit comparison wants a fixed sample.
  - `spaceUnder` anchors two-finger gestures: the base-plane point when pickable, else the point on the camera-facing plane through the pan (the spec said "at the pivot's depth"; the pan's depth needs no pivot and pins the same picture).
- **Step 1, browser baseline**: 15 passed (retaken on its own; the first run's last line was a link, not a count).
- **Step 3, `SheetCanvas` and the painter.** Goldens 32 passed with no diff; `test/presentation` 700 before the new tests. 8 tests in `sheet_canvas_test.dart`, 4 in `geometry_painter_test.dart`. Notes:
  - The painter keeps its `Size size` parameters. What changed type is the canvas (`SheetCanvas`), and each use of "the canvas rectangle" goes through `_frame(size)`, which is `Offset.zero & size` when not tilted.
  - **`-margin` versus `0 - margin`.** `flatFrame` at the identity returns `0 - margin`, because `-0.0` as a rectangle corner is not the `Offset.zero` the planar painter used. No golden moved either way, but the arithmetic is now the same.
  - **Inside the edge-on band the clip bounds are widened to the figure's bounds** (`_bandBox`, from `visibleWorldBounds`). There the whole plane is on screen as one line, so no pull-back of the canvas bounds what is visible, and a conic or locus would otherwise be trimmed off that line.
  - Labels and tick labels are placed with the true viewport and painted on the real canvas. An angle's label is placed in the planar frame and carried through the sheet map, since its marker lies in the plane (`label_layout.dart`).
  - The hyperbolic wash is a screen rectangle with the disc's sheet image cut out by even-odd, the Phase 126d formulation; at the identity it is still `outsideDiscPath`.
  - Gotcha: the arc length of a dash extracted from a transformed oval reads up to 0.13 px off its nominal 8 px (a flattened conic's metric). The dash test allows 0.3; cut before the map, the same dashes would be 4.3 px on the squashed side.
  - Gotcha: Dart records compare `List` fields by identity, so a recording canvas that logs `(name, [args])` records never equals an expected literal. The test canvas logs plain lists.
- **Step 4, gestures.** 10 widget tests in `geometry_canvas_test.dart` (group "the space view"), 2 provider tests; `test/presentation` 722. Notes:
  - `spaceViewProvider` only holds the flag. Moving the camera when it flips needs the canvas size, so that lives in presentation (`space_view.dart`, completed in step 5).
  - Orbit direction: dragging right turns the figure counterclockwise seen from above (its near side follows the finger); dragging down lowers the tilt (the camera climbs). Half a degree per pixel, measured from the first-down position, so the recognizer's slop costs no travel.
  - With a tool active, any one-finger drag orbits, including one that starts on an object: no drag moves an object while a tool is active.
  - An interrupted orbit (a second finger lands, or the pointer is cancelled) keeps the camera where it got to and does not settle.
  - `hitRadius` on `CanvasViewport` carries the tilt-widened radius; it also feeds `ToolInput.snapThreshold`, so snapping widens with it.
  - Departure: a tap inside the edge-on band returns before the label-rectangle check, so a measurement or text cannot be selected by its label there either. Simpler than a second path for a view in which the figure is a line.
  - Gotcha: in a two-finger widget test the fingers move one after the other, so the scale recognizer's baseline catches them a step apart and reports a pinch of about 1.1. The pan tests assert on the point between the fingers and allow that.
- **Step 5, app bar, presets, Fit, Reset, export, DECISIONS.** 12 widget tests in `space_view_flow_test.dart` (six at wide, six at phone), 6 in `space_view_test.dart`, 3 in `fit_viewport_test.dart`, 3 in `png_exporter_test.dart`. Notes:
  - **Leaving turns about the figure's centre**, like entering and the presets, not about the point at the canvas centre as the spec first said. It is total at edge-on and it makes "on, then off" return exactly the view the user started from. Spec requirement 4 is amended.
  - The app bar scrolls horizontally on a phone (the Phase 47 unified bar), so the two new buttons cannot overflow it; the risk in the spec did not apply. The flow tests scroll the bar to each control.
  - Fit export in the planar view keeps exporting the level plan (it never passed the rotation). In the space view it is given the camera's rotation and tilt.
  - "Straighten the view" on the compass chip levels the azimuth and keeps the tilt.
  - `fittedToAbsolute` takes the tilt too: a disc's width does not foreshorten under a turntable tilt, so the same scale frames it.
  - **Not tested: File > Open turning the view off.** It is the same two lines as New, which is tested; Open goes through the platform file picker.
  - `decision_citations_test` failed until the DECISIONS section existed, as it should.
- **Step 6, browser gate and goldens.** `test/web` 17 passed (15 + 2): on the real renderer a circle through the sheet map is the ellipse it should be, at full stroke width, and a dashed one is inked along about half its rim in a dozen runs. Three new goldens rather than two: `space_oblique_light`, `space_oblique_dark`, `space_below_light` (the view from below, where the squash is negative and the figure is mirrored, in place of a front view, which for a planar figure is a line). `--update-goldens` rewrote the existing 32 to the same bytes: `git status` showed only the three new files.
- **Step 7, README.**
- **Step 8, looks.**
  - **The Chrome extension was not connected**, so the look through it did not happen. Instead: the release wasm build served on 127.0.0.1, driven in a separate headless Chrome (158, temporary profile) over the DevTools protocol with real mouse and touch events, and read from screenshots.
  - Seen at 1280 wide: two circles drawn with the circle tool; the 3D button turns them into ellipses with round dots and upright labels and shows the Views button; a mouse drag of (120, −40) on empty canvas turns the azimuth to 60° on the compass and flattens the figure.
  - Seen at 400×800 with touch: a circle drawn by taps; the bar scrolled to the 3D button and it tapped on; a one-finger swipe of (90, 40) gives 45° on the compass and a rounder ellipse, the centre point staying put; a touch drag of the rim point ends with the point exactly under the finger (CSS 330, 340); two fingers moving together pan the figure; the Views menu lists Top, Front, Side, Oblique.
  - **Not seen in a browser**: choosing a preset, turning the view off, and the edge-on refusal. Those rest on the widget tests.
  - Gotcha: a device-metrics override belongs to the DevTools session and is gone when it detaches, so each scripted run sets it again; and a menu left open by one run swallows the next run's first inputs.
  - Gotcha: coarse two-finger steps (10 px per event) read as a twist, because the two pointers' moves arrive one after the other; at 1.5 px per event the rotation holds. That is the scale recognizer's behaviour in the planar view as well.
  - **Phone smokes did not run.** `flutter emulators` lists none, and Xcode is the command-line tools only (no `xcodebuild`, no `simctl`, no CocoaPods). The parked item stays parked with the same trigger; the phone evidence is the touch run above and the user's own device on the deployed build.
- **Step 9.** Final gate before the merge: analyze clean; VM 3629 passed (baseline 3566); browser 17; goldens 35; `flutter build web --wasm` built. `git diff main --stat -- lib/domain test/fixtures lib/application/persistence` is empty.

**Carried to milestone 2:** the screen-space hit test (the tilt-widened world radius is a stopgap); label declutter on projected shapes; a sheet map per plane; the save-format question; whether the rubber band needs a way back in the space view.
