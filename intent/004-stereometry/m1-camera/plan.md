# Plan: stereometry milestone 1 — the 3D view and its camera

Written 2026-11-24 from [spec](spec.md) · Status: awaiting approval · Branch: `intent-004-stereometry`

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

Nothing started. The intent was accepted on 2026-11-24 with two answers recorded in it (one-finger orbit; parallel projection only). This plan awaits approval.
