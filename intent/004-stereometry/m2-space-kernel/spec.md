# Spec: stereometry milestone 2 — the space kernel, planes, and the active plane

Written 2026-11-24 from [intent](../intent.md) · Status: approved 2026-11-24 with the [plan](plan.md)

Milestone 2 of five. After it a user can lift a point off its plane, join points in space, build planes, intersect lines and planes, and use every existing 2D tool inside any plane. Solids, cross-sections and hidden-edge dashing are milestone 3; measurements in space are milestone 4.

## Requirements

**Points and lines in space**

1. **A free point can be lifted.** In the space view a selected free point shows a lift handle. Dragging the handle moves the point along the normal of its plane; dragging the point itself moves it parallel to its plane at its current height. The height snaps to exactly 0 near the plane. One gesture is one undoable command.
2. **Segment, line, ray, midpoint and parallel line work between any two points of space**, with the existing tools and the existing kinds. A segment drawn in the base plane stays attached when one end is lifted.
3. **A construction that needs a plane goes undefined when a parent leaves that plane, and comes back when it returns.** A circle centred on a point that is then lifted disappears; it is never drawn at the point's foot. Only an exactly zero height counts as in the plane.

**Planes**

4. **Plane kinds:** through three points; through a line and a point; through a point perpendicular to a line; through a point parallel to a plane.
5. **Line and point kinds that planes give:** the line through a point perpendicular to a plane; the point where a line meets a plane; the line where two planes meet.
6. **A plane is drawn as a translucent patch** around what defines it and what lies in it, with an outline, and can be tapped, selected, styled, hidden and deleted like any object.

**The active plane**

7. **One plane is active**: the base plane by default. Tapping a plane with no tool active selects it and makes it active. A chip on the canvas names the active plane and returns to the base plane on a tap. The active plane's patch is outlined in the accent colour and carries the grid.
8. **Every existing tool works in the active plane.** A tap on empty canvas lands on the active plane. New free points belong to that plane and move with it.
9. **A tool in the active plane accepts an existing object only if it lies in that plane by construction**, never because it happens to be there now. Segment, line, ray, midpoint and parallel line accept any point (requirement 2).
10. **Two lines in space intersect through a plane that contains both by construction.** There is no intersection of two lines that are merely close: skew lines have no intersection point.
11. **Dragging a free point inside a non-base plane is traced**, as in the base plane. Dragging a point that moves a plane re-solves that plane's contents statically.

**Standing**

12. **Phone first.** The lift handle, plane tools, plane selection and the chip are all touch targets of at least 48 px.
13. **2D costs nothing.** A document with no plane and no lifted point paints, hit-tests, drags and saves exactly as on `main`; the existing goldens are byte-identical; such a document's save file is byte-identical.
14. **Picking refuses instead of guessing.** A tap on a plane seen within about 3° of edge-on places nothing. The lift handle is not offered while the plane's normal points nearly at the camera.
15. **Hit testing in the space view is done in screen space**, and the nearer object wins a tie. Milestone 1's widened world radius is removed.
16. **Save format version 4** is stamped on a document that holds a plane or a lifted point, and only on such a document. Opening one turns the space view on.
17. **Space objects need a Euclidean document.** In a hyperbolic or elliptic document the space tools and the lift handle are absent, and the geometry switch is refused while the document holds space objects. The prover declines a document that holds them.

## Design

### The space kernel (`lib/domain/projective/space/`)

Real projective 3-space, pure Dart, no Flutter.

- `Point3`: a real homogeneous quadruple. `Plane3`: its dual. `Line3`: six Plücker coordinates (direction, moment).
- Join and meet, each total, each answering the zero vector only on exact degeneracy: point ∨ point → line; point ∨ line → plane; three points → plane; plane ∧ plane → line; line ∧ plane → point. `Line3.reciprocal(other)` is the single coplanar-versus-skew quantity; nothing in this milestone gates on it numerically.
- Metric helpers under the Euclidean absolute: the line through a point perpendicular to a plane, the plane through a point perpendicular to a line, the parallel plane, the parallel line.
- `PlaneFrame`: an origin and an orthonormal pair (u, v) with normal n = u × v. `lift` takes plane coordinates (and a height) to space; `pull` is the orthogonal projection of a space point or line onto the plane, in plane coordinates. Because the frame is orthonormal, the plane's 2D Euclidean geometry is the space geometry restricted to it.
- `Vec3` joins `Vec2` in `lib/domain/math/` as a view struct. It replaces the `SpacePoint` record that `canvas_viewport.dart` declared in milestone 1.

### Sheets: where an object's 2D value lives

The existing kernel stays what it is: complex, planar, traced. A **sheet** is the plane whose coordinates an object's `projPoint` / `projLine` / `conic` are written in. It is one of: the base plane; a `GeoPlane` object; or none.

- Every `GeoObject` has a `sheet`, fixed for its lifetime and derived from structure: a free point's is the plane it was placed in; a derived planar object's is its parents' common sheet; an object whose parents do not share a sheet has none.
- **Every point and line also has a space value**, `GeoPoint.spacePoint` and `GeoLine.spaceLine`. The default is the sheet's lift of the 2D value when that value is real. An object with no sheet has only its space value.
- `GeoPoint.isDefined` and `GeoLine.isDefined` become "has a real finite value in its sheet or in space". For a base-sheet object the first arm is today's test and short-circuits.

This is the old record's "2D is a chart of one kernel", with the chart made a property of the object. No existing kind's `recompute` changes except the ones named below.

### Free points: a plane and a height

`FreePoint` gains `plane` (a `GeoPlane?`; null is the base plane) and `height` (0 by default). Its `parents` are `[plane]` or empty, so it is still the graph's only mutable root kind.

- Its stored coordinates are the plane's (u, v); `chartPosition` reads them always.
- **`projPoint` and `position` are null while `height != 0`.** This is a fourth sanctioned exception to "the projective value is total": a point off its sheet has no value in it. The test is exact, so there is no band; the lift handle's snap is what brings a point back to exactly 0.
- `FreePoint.position` is non-nullable today. Callers that mean "the stored coordinates" (commands, drag sessions, `MutableRoots`, the codec) move to `chartPosition`; the compiler lists them.
- A new `SetPointHeightCommand`, and `Construction.setFreePointHeight` beside `moveFreePoint`.
- Because a plane-hosted free point *is* a `FreePoint`, the drag session, `MoveFreePointCommand`, `tracedPosition` and the tracing engine run in that plane's coordinates unchanged. The presentation layer only has to hand them the pick in that plane. `freePointAncestors` and `MutableRoots` already stop at a `FreePoint` and do not walk into its plane.

### The intrinsic kinds

`Segment`, `Ray`, `LineThroughTwoPoints`, `Midpoint` and `ParallelLine` have a value that depends on no plane. Each gains a space computation from its parents' space values, and keeps its 2D computation, which now runs only when its parents share a sheet. So a base-plane segment is bit for bit today's segment, and the same segment with one end lifted has a null `projLine` (a parent's is null, which the existing convention already allows) and a real `spaceLine`.

Every other kind is plane-bound in this milestone. `Polygon`, `VertexAngle` and the measurements gain space values in milestones 3 and 4.

### Planes and what they give

`GeoPlane` is a ninth sealed kind: `spacePlane` (a `Plane3?`) and `frame` (a `PlaneFrame?`).

| Kind | Parents | Frame |
|---|---|---|
| `ThreePointPlane` | A, B, C | origin A, u along AB, n along AB × AC |
| `LinePointPlane` | line, P | origin P's foot on the line, u along the line |
| `PerpendicularPlane` | P, line | origin P, n along the line, u horizontal |
| `ParallelPlane` | P, plane | origin P, axes of the parent's frame |
| `PerpendicularToPlaneLine` (a `GeoLine`) | P, plane | — |
| `LinePlaneIntersectionPoint` (a `GeoPoint`) | line, plane | — |
| `PlaneIntersectionLine` (a `GeoLine`) | plane, plane | — |

"u horizontal" is n × ẑ normalised, with x̂ when the plane is itself horizontal. It is the one frame with a singular direction; see concerns. Parallel planes meet in a line at infinity and a line parallel to a plane meets it at a point at infinity: both are values, and neither projects.

### Lying in a plane by construction (`space_incidence.dart`)

`liesIn(object, plane)` is structural, in the manner of `incidence.dart`: parent ties and theorems, never a test on current positions.

- an object whose sheet is the plane (for a free point this is true of the *sheet*, and the height gate above handles the rest);
- a defining point or line of the plane;
- `LinePlaneIntersectionPoint` and `PlaneIntersectionLine` with the plane as a parent;
- a line through two points that lie in it; a `ParallelLine` through a point in it, parallel to a line in it;
- a `Midpoint` of two points in it; a `PointOnObject` or `IntersectionPoint` on a line that lies in it.

The predicate is sound and incomplete. A point that lies in a plane by a theorem the list does not know is refused (requirement 9), which is the safe side.

### Adapters

A planar kind reads its parents' 2D values directly, so a parent from another sheet has to be brought into the sheet first. Two internal kinds do that and nothing else:

- `ChartPoint(point, plane)`: a `GeoPoint` on the plane's sheet whose `projPoint` is the pull of `point.spacePoint`.
- `ChartLine(line, plane)`: the same for a line.

They are real DAG objects, so undo, delete cascades, save and load need no special case. They are flagged internal: not painted, not hit, not named, not listed in the object tree, never selected. A tool reuses the adapter for a given (object, plane) pair when one exists. An adapter left with no dependents is dropped when the document is encoded.

### Tools

- `ToolInput` gains `plane` (the active plane). `resolvePoint` creates its `FreePoint` in that plane; the macro tools that build free points directly do the same.
- **`PlaneScopedTool`** wraps the active tool whenever the active plane is not the base plane or a hit is not on the base sheet. For each hit it passes through an object already on the active sheet, replaces one that `liesIn` the active plane by its adapter, and drops the rest. For the intrinsic tools it passes any point through untouched. When the inner tool commits, the wrapper returns one `MacroCommand` holding the new adapters and the tool's command. No existing tool is edited for this.
- New tools: **Plane** (three points, or a line and a point, on the `two_line_or_three_point_tool` pattern), **Perpendicular to plane** (point, plane), **Perpendicular plane** (point, line), **Parallel plane** (point, plane). The **Intersection** tool accepts line + plane and plane + plane.
- Two lines: the Intersection tool looks for a plane (the active one first, then any) in which both lines lie by construction, and builds the existing `IntersectionPoint` there through adapters. If there is none the tap is ignored and the hint line says the lines share no plane.
- The new tools sit in a Space group of the toolbar, shown while the space view is on and the document is Euclidean.

### Presentation

**One sheet map per plane.** Under parallel projection the map from a plane's coordinates to the screen is affine. `CanvasViewport.sheetFor(frame)` returns a planar viewport and an affine sheet map for that plane; for the base plane it is milestone 1's `flat` and `sheetMap`, by the same early return. `SheetCanvas` takes the general affine map. The painter's per-kind code is reused as it stands: objects are grouped by sheet and each group is painted through its sheet's canvas. A plane seen inside the edge-on band uses the milestone 1 floor.

**The space pass.** Objects with no sheet (a lifted point, a segment to it, a perpendicular to a plane) are painted from their space values through `spaceToScreen`: dots, and lines clipped to the canvas. Plane patches are painted first, back to front by the depth of their centres, then every stroke, then dots and labels. There is no hidden-edge treatment yet.

**Plane patches.** A parallelogram in the plane's frame: the bounding box of its defining points and of the points on its sheet, padded by a fifth and never smaller than a fixed screen size. Fill at low opacity in the plane's colour, outline at stroke width; accent outline and grid when active.

**The lift handle.** For a single selected free point, a stem along the projected normal ending in a round grip 56 px from the point. Dragging the grip changes the height by the pointer's travel along the projected normal; within the hit threshold of the plane it snaps to 0. While a point is lifted and selected or dragged, a dashed drop line and a small foot mark show its height. The handle is absent when the projected unit normal is shorter than a fifth of the scale (the plane is seen nearly face-on, so a screen drag cannot name a height).

**Screen-space hit test (`screen_figure.dart`).** In the space view each visible object is turned into screen primitives: a dot, a polyline (curves sampled through their sheet map), a filled polygon, a label rectangle. The hit test measures distance in pixels against those, ranks by (priority, distance, depth, nearer first), and returns the same lists `ToolInput` already takes. Label declutter in the space view builds its obstacles from the same primitives. With the space view off, the existing world-space tester and obstacle builder run untouched. Plane patches rank below everything else.

**Picking.** `pickPlane(screen, frame)` intersects the view ray with a plane, optionally offset by a height, and answers null inside that plane's edge-on band. `pickBasePlane` becomes the base case.

**The active plane.** `activePlaneProvider` holds an object id, session state like the space view flag: base on New and Open, base when the space view is turned off, base when the plane no longer exists (an undo of its creation).

### Tracing across sheets

Space is real and a traced detour is complex, so continuation cannot pass through a space value. An intersection slot is seeded for a traced pass only if every object between it and the dragged root is on the root's sheet. Other slots resolve in canonical order at each frame, the rule structural double roots already follow. So a drag inside any one plane is traced in full, and a drag of a point that moves a plane re-solves that plane's intersections statically.

### Save format

- New `type` values for the seven kinds and two adapters; `FreePoint` gains `plane` (an id) and `h`.
- `requiredFormatVersion` answers 4 when the document holds any plane or any nonzero `h`. An older reader would refuse the unknown types; one that skipped `h` would draw a lifted point in its plane, which is a misread. `constructionFormatVersion` becomes 4.
- On decode, a planar object whose parents do not share a sheet is a format error, except the five intrinsic kinds.
- No file in `test/fixtures/` changes. Space documents for tests live in `test/space_fixtures/`.

### Not changed, and why

- `lib/domain/projective/` outside `space/`, and the tracing engine apart from the seeding rule: the planar kernel is reused, not generalised.
- The 50 plane-bound kinds' `recompute`.
- `test/v1_oracle/`.
- The camera, its gestures and presets.

## Intent constraints → how each is met

| Constraint | How |
|---|---|
| Phone is required | Lift is a handle drag; planes are made and activated by taps; the chip returns to the base plane. Widget tests drive touch pointers at phone size |
| 2D costs nothing | Base-sheet objects take the unchanged paint, hit and recompute paths; the space pass and the screen hit test run only when there is something for them. Goldens, a byte comparison of saved 2D documents, and the bit-for-bit viewport test are the proof |
| Mathematically robust; real projective 3-space; Plücker lines | `Point3`, `Plane3`, `Line3` with total join and meet. In-plane geometry runs on the complex 2D kernel in the plane's frame |
| The figure never lies | A plane-bound object off its plane is undefined, by an exact test. Incidence is structural. No numeric coplanarity gate, so skew lines never meet. Picks refuse near edge-on |
| Open to later extension | Screen primitives already carry sampled polylines and filled polygons, which is what a sampled curve or surface will hand the painter, the depth order and the hit test |
| `lib/domain/` free of Flutter | The kernel, kinds, incidence, tools and commands are pure Dart; sheet maps and screen primitives are presentation |
| Every action one undoable command | `SetPointHeightCommand`; adapters ride in the committing tool's `MacroCommand` |
| Save format versioned; v1 readable | Version 4 by `requiredFormatVersion`; fixtures untouched |
| No new domain API without a test | Each kernel function, kind, command and the incidence predicate has tests; property tests for join and meet duality and for lift and pull |
| Rasterizer-dependent behaviour in a browser | A `test/web` case for a circle on a non-base plane through a general affine sheet map, and for a translucent patch |
| No GPU stack; parallel projection | `CustomPainter`, patches depth-sorted by centre |
| The prover stays planar | It declines a document with space content |

## Open questions carried over

Answered here, from the intent:

- **The lift handle on touch, and how the active plane is seen:** requirements 1 and 7, and the presentation section.
- **Tracing inside a non-base plane:** yes for a drag within the plane; static across sheets (requirement 11).
- **Which version carries 3D:** 4; an older reader refuses it.

Answered here, from milestone 1's carries: the screen-space hit test, label declutter on projected shapes, and a sheet map per plane.

Still open:

- **The rubber band in the space view** stays unavailable. Long-press and shift-tap select. Nothing in this milestone makes it more needed.
- **A point on a segment that lies in no plane object** (a point on a pyramid's edge) is not offered here. Milestone 3 needs it for cross-sections and decides between a space value for `PointOnObject` and face planes.

## Decisions taken at approval (2026-11-24)

The user approved the plan and left these four to the best UI/UX. Each stands as drafted.

1. **A lifted point's plane-bound dependents vanish**; the lift is not refused. A handle that is sometimes missing is harder to understand than a circle that comes back when the point does. While the point is lifted the hint line says how many constructions are waiting for it to return to its plane.
2. **A plane becomes active by a tap with no tool active**, and the chip returns to the base plane. A tap while a tool is active always lands in the active plane, so the same tap never means two things where patches overlap.
3. **Adapters are hidden objects in the graph**, saved with the document.
4. **Two lines intersect only through a plane known by construction.** No numeric coplanarity tolerance. The hint line says why a refused pair was refused.

## Areas of concern

- **The milestone is large.** The plan lands it in three stages, each shippable: points and lines in space; planes; the active plane.
- **Lifting a base vertex hides its angle marks, polygons and measurements** until milestones 3 and 4 give those kinds space values. It is honest, and it will look like loss.
- **Structural incidence is incomplete.** A user will meet a point that plainly lies in the active plane and is refused. The hint line has to say why, and the rule list will grow from real cases.
- **`PerpendicularPlane`'s frame turns quickly near horizontal.** A free point placed in such a plane swings when the plane passes through horizontal. The plane itself is unaffected.
- **Intersections in a plane may change branch when the plane's defining points are dragged**, since those drags are static. The tangent-and-chord style documents that needed tracing in 2D would need it here too.
- **A ninth sealed kind touches every exhaustive switch** (about thirteen files). Each arm is small; the compiler finds them.
- **Patch extent is a guess at what the user wants to see.** It follows the content, so it grows as points are added, and it may need a user-adjustable size later.
- **Hidden adapters can accumulate** in a long session. They are dropped at encode when orphaned, not live.
