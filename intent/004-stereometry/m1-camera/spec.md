# Spec: stereometry milestone 1 — the 3D view and its camera

Written 2026-11-24 from [intent](../intent.md) · Status: drafted, awaiting plan approval

Milestone 1 of five. It adds no object, tool or kernel type. An existing planar document can be turned around in space, and everything the user can do to it today still works while it is turned.

## Requirements

1. **A 2D/3D button** in the app bar toggles the space view. It is session state, off at launch and off after File > New or Open.
2. **Off is today's app.** With the space view off, every transform, gesture, paint call and hit test is the one `main` has now. The existing goldens are byte-identical.
3. **The camera is a turntable under parallel projection.** Two angles: the existing view `rotation` (the azimuth about the vertical through the figure) and a new `tilt` (0 looks straight down at the base plane, which is today's view; 90° is edge-on; up to 180° looks from below). Vertical stays vertical on screen at every camera position.
4. **Turning the view on** moves to the oblique preset (requirement 9) at the current rotation. **Turning it off** returns tilt to 0 and keeps pan, scale and rotation as near as the base-plane point at the canvas centre allows.
5. **One-finger drag orbits.** In the space view, a one-pointer drag that today would open the rubber band or be ignored (it starts on empty canvas, or a tool is active) orbits instead: horizontal travel turns the azimuth, vertical travel changes the tilt. The orbit keeps the figure's centre fixed on screen. The same drag with a mouse orbits too.
6. **Two fingers pan, zoom and twist** as today; the twist turns the azimuth. Scroll, Ctrl/Cmd+scroll, Alt+scroll and Space+drag keep their meaning.
7. **Taps and object drags are unchanged in meaning.** A tap or drag lands on the base-plane point under the pointer. Tools, selection, long-press, label drags, point drags with tracing, and grid snap all work at any tilt where the base plane can be picked.
8. **Near edge-on, the base plane cannot be picked.** Within about 3° of edge-on (|cos tilt| < 0.05) a tap or object drag on the plane does nothing; orbit, pan and zoom still work. Nothing is ever placed at a wildly distant point because the plane was seen at a grazing angle.
9. **Preset views**: Top (tilt 0), Front (tilt 90°, rotation 0), Side (tilt 90°, rotation 90°), Oblique (tilt 60°, rotation kept on entry, −30° when chosen from the menu). A Views menu beside the button appears while the space view is on.
10. **The picture reads like a drawing, not a photographed sheet.** Under tilt, curves foreshorten (a circle is drawn as an ellipse) while stroke widths, point dots, labels, tick labels and dash lengths keep their screen size and stay upright.
11. **Fit and Reset work in the space view.** Fit frames the figure at the current camera; Reset returns to the oblique preset at origin and 100 %.
12. **PNG export** renders what the canvas shows, tilt included.
13. **Nothing is saved.** The save format, the codec and `test/fixtures/` do not change. A document reopens in 2D at its saved pan, scale and rotation.
14. **Phone first.** Every camera action in this milestone is reachable by touch alone.

## Design

### Camera state

`ViewportState` (`lib/application/providers/viewport_provider.dart`) gains two fields, both defaulting to 0:

- `tilt`, radians, clamped to [0, π].
- `panZ`, the height of the world point at the canvas origin. Under parallel projection a translation along the view direction is invisible, so at tilt 0 `panZ` has no effect and is kept at 0. It exists so that panning is total: at edge-on a vertical screen pan cannot be expressed as a movement of a base-plane point, and it becomes a change in `panZ`.

A separate `spaceViewProvider` (session `bool`) holds the button. It is not a field of `ViewportState`, because Top is a legitimate space view with tilt 0.

The projection of a space point X = (x, y, z), with pan P = (pan.x, pan.y, panZ), scale s, rotation θ, tilt φ:

```
u = Rz(θ) · (X − P)                       (turntable azimuth)
screen.x =  s · u.x
screen.y = −s · (cos φ · u.y + sin φ · u.z)
```

At φ = 0 this is exactly today's `worldToScreen`. Perspective, if it ever comes, replaces the last two lines only.

### One consequence that shapes the painter

For a base-plane point, the tilted picture is the flat picture with its y coordinate scaled:

```
screen.x = flat.x
screen.y = cos φ · flat.y + s · sin φ · panZ
```

where `flat` is today's `worldToScreen` at the same pan, scale and rotation. A turntable tilt is a vertical squash of the 2D drawing plus an offset. So the painter does not learn 3D in this milestone. It keeps computing in the flat frame, and one affine map, the *sheet map*, carries flat coordinates to the screen.

### `CanvasViewport`

- `worldToScreen`, `screenToWorld`, `pannedByScreen`, `zoomedAbout`, `pinning`, `visibleWorldBox` take the tilt into account. Each reduces to today's arithmetic when tilt is 0, by an early return on `tilt == 0` rather than by multiplying by `cos 0`, so no float differs.
- `screenToWorld` stays the base-plane pick. A new `pickBasePlane(Offset) → Vec2?` returns null inside the edge-on band; callers that place or drag use it. `screenToWorld` keeps a total answer for the callers that only need a clip bound.
- `sheetMap` exposes the flat-to-screen affine (identity at tilt 0), and `flat` exposes the same viewport with tilt removed.
- `orbitedAbout(pivot, dRotation, dTilt)` returns the state whose camera is turned while the space point `pivot` keeps its screen position.
- `worldToScreenLength`, `worldToScreenAngle` and `worldToScreenDirection` are flat-frame quantities and are documented as such.
- `visibleWorldBox` near edge-on would be unbounded. It is capped at eight canvas diagonals around the canvas centre's flat image, which bounds grid lines and clip work.

### The painter: a sheet canvas

`GeometryPainter` draws through a small adapter, `SheetCanvas` (new file, `lib/presentation/canvas/sheet_canvas.dart`), instead of the raw `Canvas`. It has two kinds of call:

- **In-plane geometry** (`drawLine`, `drawCircle` as a rim, `drawArc`, `drawPath`, fills). The adapter builds the path in the flat frame, transforms the *path* by the sheet map with `Path.transform`, applies dashing after the transform, and strokes it on the untransformed canvas. Strokes and dash lengths therefore keep their screen size. An affine image of a circular arc is an exact conic segment, so no sampling is added.
- **Sprites** (point dots, preview markers, labels, tick labels). The anchor goes through the sheet map; the shape is drawn untouched.

With the sheet map at identity the adapter forwards each call to the canvas unchanged: `drawCircle` stays `drawCircle`. That is what keeps the goldens byte-identical, and it is tested directly.

Rejected: wrapping the paint in `canvas.transform`. It is one line, but it squashes strokes, dots and text with the geometry, and at steep tilt horizontal lines thin to nothing.

Angle arcs, right-angle squares and segment tick marks are in-plane geometry: they lie in the plane and foreshorten with it, as in a textbook figure.

The painter replaces its uses of `Offset.zero & size` as "the visible region" with the flat visible rectangle (the canvas rectangle pulled back through the sheet map, capped as above).

### Hit testing

`CanvasHitTester` is untouched: it works in world coordinates with a world-space radius. Under tilt, a world disc is a squashed ellipse on screen, so a fixed world radius would be too tight along the foreshortened direction. The canvas therefore passes `hitThresholdPx / scale / max(|cos φ|, 0.5)`: the touch target keeps at least its full size along the foreshortened axis down to 60° of tilt and grows to at most double across it. A screen-space hit test, which needs each kind projected to the screen, belongs to milestone 2, where objects leave the base plane and the world-space test stops being meaningful at all.

The rubber band's containment predicate already works in screen space through `worldToScreen`; in the space view the band is not opened (requirement 5), so nothing changes there. Long-press still toggles selection.

### Gestures (`geometry_canvas.dart`)

- `_panStart` falls through today to the band when nothing is hit, and returns early when a tool is active. With the space view on, both exits start an orbit instead: an `_OrbitBaseline` holding the start rotation, start tilt and pivot. Updates are computed from the baseline, like `_NavBaseline`, at 0.5° per logical pixel.
- **The pivot** is the centre of the figure's bounds on the base plane (the bounds Fit uses), or the world origin for an empty document. It is not the point under the canvas centre: near edge-on that point lies far away on the plane, and turning about it would swing the figure off screen.
- Two-finger navigation pins the base-plane point under the focal, or the point at the pivot's depth when the plane is inside the edge-on band.
- Taps and `_panStart`'s hit test use `pickBasePlane`; a null pick ends the handler.
- An orbit ends with the rotation settle that a twist ends with (`TwistGate.settled`), and tilt snaps to 0, 90° or 180° when within the same threshold.

### App bar (`lib/main.dart`)

A toggle `IconButton` ("3D view") after Reset. While on, a `PopupMenuButton` "Views" follows it with Top, Front, Side, Oblique. The compass chip already shows rotation and keeps doing so. `_fitView` and Reset branch on the space view (requirement 11). File > New and Open set the space view off.

### Not changed, and why

- `lib/domain/` — no file. The camera is presentation and application state; the space kernel is milestone 2.
- `construction_codec.dart` and the save format — requirement 13. The intent's question about which format version carries 3D stays open for milestone 2, when there is something an older reader could misread.
- `label_obstacles.dart` — label declutter keeps treating obstacles in the flat frame. See concerns.

## Intent constraints → how each is met

| Constraint | How |
|---|---|
| Phone is required; no gesture only on mouse or keyboard | Orbit is one finger, pan and zoom are two, the button and Views menu are tap targets. Widget tests drive touch pointers. The Android and iOS smokes parked in `intent/README.md` fire here |
| 2D costs nothing; existing goldens unchanged | `tilt == 0` early returns in `CanvasViewport`; `SheetCanvas` forwards at identity; the golden suite run on macOS before and after with no diff; a test that the adapter's call log at identity equals the raw painter's |
| Mathematically robust; the figure never lies | Panning and orbiting are total at every tilt (`panZ`). The only singular operation, picking the base plane, refuses inside the edge-on band instead of answering far away |
| Open to later extension | The projection is one function of a space point; the sheet map is its restriction to one plane, and milestone 2 gives every plane its own. Sprites versus in-plane geometry is the split sampled curves and surfaces will also use |
| `lib/domain/` free of Flutter | No domain file changes |
| Every action is one undoable command | Camera moves are view state, like pan and zoom today, and are not commands. Object drags under tilt go through the same drag session and emit the same one command |
| Save format versioned; v1 readable | Not touched |
| No new domain API without a test | No new domain API |
| Rasterizer-dependent behaviour tested in a browser | A `test/web` test paints a tilted, dashed circle and probes pixels, since `Path.transform` of an arc and dashing over it rest on the renderer |
| No GPU stack; parallel projection | `CustomPainter` throughout; the projection above |

## Open questions carried over

None block this milestone. The intent's remaining questions are assigned to milestones 2, 3 and 5 there.

## Areas of concern

- **The hit radius under tilt is an approximation** until milestone 2's screen-space test. It is generous across the foreshortened axis at steep tilt, so two close objects may be harder to tell apart at 70° and beyond than they are flat.
- **Label declutter under tilt** runs on flat-frame obstacles, so a label may sit over a foreshortened curve it would have avoided. Labels remain draggable. Revisit with milestone 2's projected shapes.
- **The band selection is not available in the space view.** Long-press and shift-tap remain. If that proves a loss, a modifier or a mode brings it back.
- **The app bar on a phone** gains one button, and a second while the view is on. `app_bar_layout_test` pins the row against overflow; if it does not fit, Views moves inside a single 3D menu button.
- **The painter refactor is wide**: about forty draw calls move behind the adapter. It lands as its own commit with the goldens as the proof that nothing moved.
- **A document that is edge-on shows a line.** That is correct for a planar figure and is the reason Front and Side are only useful from milestone 2 on; they ship now so the camera is complete.
