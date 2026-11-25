# Spec: stereometry milestone 3 — solids, cross-sections, dashed hidden edges

Written 2026-11-25 from [intent](../intent.md) · Status: approved 2026-11-25 with the [plan](plan.md)

Milestone 3 of five. After it a user can build a pyramid, a prism, a cube and a regular tetrahedron in a few taps, put points on their edges, work inside any face, cut a solid with a plane and get the section as a polygon, and read the figure like a textbook: edges behind a face are dashed. Angles, distances and volume in space are milestone 4; spheres, cones and cylinders are milestone 5.

## Requirements

**What solids rest on**

1. **A polygon follows its vertices into space.** A `Polygon` whose vertices do not share a sheet is drawn from their space positions: outline and fill. Lifting a vertex of a base-plane polygon no longer hides it.
2. **A point can be put on any segment, ray or line of space** with the Point tool, and dragged along it. This is the point on a pyramid's edge that milestone 2 left open.
3. **A translation needs no plane.** `TranslatedPoint` joins the kinds that follow their parents into space.

**Solids**

4. **Two solid kinds: `Pyramid` (base loop and apex) and `Prism` (base loop and the top of the first base vertex).** A solid is one object that owns its faces: translucent fills, tappable, styled, hidden and deleted like any object. Its edges and vertices are ordinary segments and points beside it, so they take points, labels and styles.
5. **Four tools, in the Space group:**
   - **Pyramid**: tap the base vertices, close on the first, then tap the apex. A tap on an existing point uses it; a tap on empty canvas makes a lifted free point over the base.
   - **Prism**: the same, and the last tap is the top of the first vertex. On empty canvas it makes a point that stays over that vertex and has a height the lift handle changes, so the prism is right and stays right.
   - **Cube**: two points, an edge of the base.
   - **Regular tetrahedron**: two points, an edge of the base.
   Cube and tetrahedron stay what they are under every drag.
6. **"Pulling up" is the lift handle.** A solid made with a new top point is committed at a default height (the mean base side), with that point selected and its handle showing. Building is one command; the pull is a second.
7. **A solid's base lies in one plane by construction.** Base vertices are on the active plane's sheet or lie in it by construction; the tool refuses others, with the reason. While a base vertex is off that plane (lifted), the solid is undefined and comes back when the point does; its edges stay drawn. A triangular base needs no plane: a pyramid on three points and an apex is any four points of space.
8. **A face is a plane to work in.** A tap on a face with no tool selects the solid and makes that face active: the chip names it, its outline takes the selection colour, and every planar tool works in it as in any plane.

**Sections**

9. **A plane cuts a solid in a polygon.** The Section tool takes a plane and a solid, in either order, and builds one object: the section polygon, on the plane's sheet. It can be filled, styled, and measured by the existing Area tool; the inspector and the object tree say how many sides it has. It follows every drag, and its side count changes as the plane moves through vertices.
10. **A plane that misses the solid gives no section**, and one that only touches it (a vertex, an edge) gives none either. A plane that contains a face gives that face.

**Hidden edges**

11. **In the space view, straight ink behind a face of a solid is dashed.** Segments, rays, lines, and the outlines of polygons and sections are split where they pass behind a face, wherever they live. The rule is per point: a point of ink is hidden when some face of some visible solid is strictly in front of it along the view direction. It assumes nothing about convexity.
12. **An ink on a face is not hidden by that face.** Edges of a solid, and anything drawn in a face's plane, are solid lines when the face is towards the viewer.
13. **A hidden solid hides nothing.** Making a solid invisible gives the wireframe.

**Carries closed here**

14. **The active plane carries a grid** in its own coordinates, and **a patch grows to hold the curves built in it**, not only the points.
15. **The phone look for the plane tools and the active plane**, owed from milestone 2, is done with this milestone's looks.

**Standing**

16. **Phone first.** Every tool is taps; the pull is the 48 px lift grip; a face is activated by a tap.
17. **2D costs nothing.** A document with no solid, no space polygon and nothing lifted paints, hit-tests, drags and saves as on `main`; goldens and saved bytes are identical. The hidden-edge pass does not run without a visible solid.
18. **Save format stays version 4.** The new kinds are new `type` values, and a document that holds one already holds space content. A reader from milestone 2 refuses the unknown type; it does not misread it.

## Design

### Polygons, glued points and translations in space

- **`Polygon`** gains `spaceVertices` (`List<Vec3>?`). On a shared sheet it is today's polygon, bit for bit, and `spaceVertices` is the lift. Otherwise `polygonVertices` is null and `spaceVertices` is read from the vertices' space positions. `GeoPolygon.isDefined` widens the way `GeoPoint`'s did, planar arm first. The kind does not claim its loop is planar: three points always are, and what an area means for a skew loop is milestone 4's question. `AreaMeasurement` stays defined only for a polygon with a planar value.
- **`PointOnObject` on a line with no planar value.** `GeoLine` gains `spaceParameterOrigin` and a unit `spaceDirection`: the point and direction the parameter is measured from in space. For a line that has, or had, a value in a sheet they are the lift of `LineEq.pointOnLine` and `direction` taken in that sheet's frame, so a glued point does not jump when an end of its host is lifted by a hair. For a line with no sheet they are the kind's own: the foot on the plane for a perpendicular to a plane, `Line3.anchor` otherwise. The parameter stays a real arc length, clamped to the drawn extent, and the stored number means what it meant.
- **Dragging such a point** reads the pointer against the host's screen image: the parameter of the nearest point of the projected line. It is a static drag (space is real; nothing is continued), ending in the existing `SetPointOnObjectParameterCommand`.
- **`TranslatedPoint`** answers from space values when a parent has no value in the sheet, by the rule the five intrinsic kinds follow.

### Raised points

Two kinds, both with no sheet, both `foot + n · height` where `n` is the unit normal of a named plane (a `GeoPlane` parent, or the base plane when there is none, as with `FreePoint.plane`):

| Kind | Height | Used by |
|---|---|---|
| `RaisedPoint(foot, plane?, height)` | a stored real, changed by the lift handle through `SetPointHeightCommand` | a pulled prism's top |
| `ProportionalRaisedPoint(foot, plane?, from, to, factor)` | `factor · |from to|` | cube (factor ±1), regular tetrahedron (±√(2/3) over the centroid) |

`RaisedPoint.height` is the third stored number a gesture may change, after a free point's coordinates and a glued point's parameter. It is a root in the same sense as those: a real parameter of one object, changed only by a command. `MutableRoots` learns it. Dragging the body of a raised point does what dragging any derived point does.

The sign of a new raised point is chosen at creation so that the solid rises on the viewer's side of its base plane.

### Solids (`GeoSolid`, a tenth sealed kind)

`GeoSolid` exposes `spaceVertices` (`List<Vec3>?`), `faces` (index loops, fixed for the object's lifetime, each wound outward) and `edges` (index pairs). It has no sheet and no planar value.

| Kind | Parents | Vertices | Faces |
|---|---|---|---|
| `Pyramid` | base points, apex, `plane?` | the parents' space positions | the base and one triangle per base side |
| `Prism` | base points, top, `plane?` | base, and base + (top − base₀) | two ends and one parallelogram per base side |

- `Prism` computes its top vertices itself. The tool also adds a `TranslatedPoint` per top vertex for the edges to attach to; the two agree by construction, and deleting one of those points does not change the solid.
- **Defined** when every parent has a space position, the base is not exactly degenerate, and (for a base of four or more) every base vertex is in `plane`: on its sheet with a value there, or `liesIn` it. The test is the one adapters make at every recompute, and exact.
- Cube is a `Prism` over the square macro's four points with a `ProportionalRaisedPoint` top; regular tetrahedron is a `Pyramid` over the equilateral macro's three points with a `ProportionalRaisedPoint` apex over the existing `Centroid`. There is no `Cube` kind.
- Outward winding is computed at each recompute from the solid's own centroid, so it survives a base drawn in either sense and an apex dragged through the base plane. A solid of zero volume has faces and no outside; it is drawn and hides nothing.

### Faces as planes

- **`FacePlane(solid, faceIndex)`** is a `GeoPlane`: frame at the face's first vertex, `u` along its first edge, normal outward. It is scaffolding (`isInternal`), like an adapter: the face is its picture, so it draws no patch, is not listed, and is left out of a saved file when nothing was built in it.
- **It is made on demand.** The active plane becomes either a plane's id or a (solid, face) pair. A pair resolves to the `FacePlane` already in the construction, or to one pending instance held until a tool commits in it; `PlaneScope` adds it in the same `MacroCommand` as the adapters. So a cube carries no planes until someone builds in a face, and undo removes the plane with what was built.
- **`liesIn` learns the solids**: a solid's vertex points lie in the faces they belong to. For a prism's top that means the top point and the `TranslatedPoint`s that take a base point by (base₀ → top). The existing rules then carry edges, points on edges and midpoints into the face.
- `liesIn` also learns: a `SegmentRatioPoint` and a `TranslatedPoint` of points in a plane by a vector in it; a point on a section's host plane.

### Sections

`SectionPolygon(plane, solid)` is a `GeoPolygon` on the plane's sheet; its `polygonVertices` are in the plane's coordinates, so the painter, the hit test and `AreaMeasurement` take it as any polygon.

- Each solid vertex is classed above or below the plane by the sign of its height, zero counting as above. An edge whose ends differ is cut; each face contributes the segments between its cuts; the segments chain into loops. Classing zero one way is what keeps every loop closed when the plane passes exactly through a vertex or an edge, with no tolerance.
- Coincident consecutive vertices are merged, so a plane through a cube's vertex gives a polygon with that vertex once. *Amended while building:* coincident means within rounding at the solid's size (1e-12, relative), not bitwise equal. A plane built through a point glued at a corner passes through the corner only to the last bit.
- **One loop or nothing.** The solids of this milestone over a convex base give at most one loop. A prism over a non-convex base can be cut in two; then the section is undefined. See concerns.
- A loop of fewer than three distinct vertices is no polygon (requirement 10).

### Hidden edges (`hidden_line.dart`, presentation)

Pure functions over screen primitives, no canvas: given an ink segment (two screen points with camera depths) and the visible solids' faces (screen loops with a depth plane each), return the parameter intervals that are hidden.

- Under parallel projection depth is linear along a segment and affine over a face, so the candidates for a change of state are finite: where the segment crosses a face's screen edge, and where it crosses the face's plane. Sort them, and test the midpoint of each interval: inside the face's screen loop (even-odd) and behind its plane by more than a margin.
- The margin is what requirement 12 rests on: relative to the figure's depth range, in the manner of the patch's on-plane test. It is where ink goes, not a claim about the figure.
- The painter's straight-ink path asks for the intervals and draws the hidden runs dashed (an 8 px period) at reduced opacity, the rest as it always did. A stroke the user has dashed keeps its own period where visible.
- Sheet-drawn straight kinds (segment, ray, line, polygon outline) take this path only when a visible solid exists; otherwise the per-kind code runs untouched.
- **Curves are not split in this milestone.** A circle on a back face is drawn whole. Curved hidden ink arrives with the curved solids of milestone 5, which need silhouettes anyway.
- Faces are painted with the plane patches, before every stroke, far to near by centroid. Two fills that cross have no right order; at these opacities the error is a tint, and what is in front is said by the dashes, not by the fills. The carry "a depth order for crossing patches" is closed as not needed.

### Tools and presentation

- The four solid tools and Section are `ToolScope.space`. Pyramid and Prism reuse the polygon tool's vertex collection, with one more tap. Each returns one `MacroCommand`: new points, hidden scaffolding, edges, the solid.
- A solid's ink (`screenInkOf`) is its faces as fills with a depth function each; the hit test ranks it with planes, below everything stroked, nearer face first. The face under the pointer is what a no-tool tap activates.
- The lift handle is offered for a selected `RaisedPoint` as for a free point; `LiftSession` works against an interface the two share.
- The grid in the active plane is the background pass run through that plane's `PlaneViewport`, clipped to its patch or face.
- The patch's extent takes the bounds of every defined object on its sheet, through the same ink the hit test reads.

### Not changed, and why

- The planar kernel, tracing, and the 50 plane-bound kinds' `recompute`.
- The camera and its gestures. The rubber band stays unavailable in the space view.
- `test/fixtures/` and `test/v1_oracle/`.

## Intent constraints → how each is met

| Constraint | How |
|---|---|
| Phone is required | Tools are taps; the pull is the lift grip; faces activate by tap. Widget tests at phone size with touch pointers; a phone look per stage |
| 2D costs nothing | The planar arm runs first in every widened kind; the hidden-edge pass and face fills need a visible solid. Goldens, save bytes and the bit-for-bit viewport test |
| Mathematically robust | Solids are real points of space with fixed combinatorics; sections are plane–edge meets from the space kernel; in-face geometry is the planar kernel in the face's frame |
| The figure never lies | A solid with a base vertex off its plane is undefined. Section classing is exact, with no tolerance. Hidden-ness is per point, with no convexity assumption |
| Open to later extension | `GeoSolid` is faces as loops with depth; the hidden-line functions take any ink segments and any occluding loops, which is what a sampled surface will hand them |
| `lib/domain/` free of Flutter | Kinds, sections, incidence and tools are pure Dart; hidden-line and ink are presentation |
| Every action one undoable command | One `MacroCommand` per solid; the pull is `SetPointHeightCommand`; a face's plane rides in the first commit that uses it |
| Save format versioned; v1 readable | Version 4, unchanged; fixtures untouched |
| No new domain API without a test | Each kind, the section algorithm, each `liesIn` rule and each tool |
| Rasterizer-dependent behaviour in a browser | A `test/web` case for dashed runs over a translucent face fill |
| No GPU stack; parallel projection | `CustomPainter`; hidden lines are computed, not depth-buffered |
| The prover stays planar | Unchanged: it declines space content |

## Open questions carried over

Answered here:

- **Hidden edges for non-convex figures** (intent): the rule is per point and per face, so it holds for any solid with planar faces. Edges hidden by a sphere stay with milestone 5.
- **A point on an edge in no plane** (milestone 2): `PointOnObject` on a space line.
- **`Polygon` in space; the grid; the patch growing; `liesIn`'s missing rules; the phone look** (milestone 2 carries): requirements 1, 14, 15 and the incidence list.

Still open:

- **The rubber band in the space view.**
- **A size control for a plane's patch.** The patch now holds everything built in it, which was the seen need.
- **Sections in more than one loop.**

## Decisions taken at approval (2026-11-25)

The user approved the plan; each stands as drafted.

1. **Solids are an object plus ordinary edges and points**, not a self-contained object that draws its own edges. Edges must be hosts for points (the cube fixture), and the shape macros already work this way.
2. **The pull is commit-then-handle** (requirement 6), not a press-drag inside the tool. It reuses a gesture that exists and is tested on touch; the cost is two undo steps for "make a prism this tall".
3. **A pulled prism is right and stays right**; an oblique prism is made by tapping an existing point as the top. A pulled pyramid's apex is a free point, because an apex is a vertex in its own right.
4. **`RaisedPoint.height` is a third mutable root.** `CLAUDE.md`'s invariant line is reworded in the same commit: free points, a glued point's parameter, and a raised point's height.
5. **Face planes are made on demand and hidden.**
6. **Curves are not dashed until milestone 5.**

## Areas of concern

- **The milestone is large.** Three stages, each shippable: space polygons and points on edges; solids and faces; sections and hidden edges.
- **A glued point on an edge keeps its arc length, not its ratio**, when the edge is dragged, as in the plane. On a cube's edge that reads as sliding. `SegmentRatioPoint` is the kind that holds a ratio; the Point tool does not make it.
- **The pending face plane** is the one new piece of session state with identity in it. If it is recreated between two taps of one tool, the second tap's objects land on another sheet.
- **A non-convex prism cut in two shows no section.** Honest, and it will look like a defect.
- **The hidden-line margin** is a tolerance on the picture. Too small and an edge flickers dashed on its own face; too large and an edge just behind a face is drawn solid.
- **A tenth sealed kind** touches every exhaustive switch again.
- **Hidden-line cost** is segments × faces × face sides per frame. A textbook figure is hundreds of tests; a document with many solids and long loci is not measured yet.
- **Lifting a base vertex of a cube** takes the solid away and leaves the wireframe, with the existing chip saying what is waiting.

## Amended while building (2026-11-25)

The plan's progress notes say why; DECISIONS has the settled form.

- **Solids' faces are not wound outward.** Nothing in the milestone reads an outward side.
- **The solid tools require every base corner in the active plane**, a base of three included; the kinds still let a triangular base go anywhere.
- **`MutableRoots` was not taught heights.**
- **Section vertices merge at rounding scale**, not bitwise.
- **The hidden-edge pass runs only while the camera is tilted.**
- **The active face is tinted as well as outlined.**
- **`GeoLine.spaceParameterFrame`** is one accessor, and the space drag is its own session (`SpaceSlideSession`).
- **A face over points of space is ground to a planar tool**; a lifted point or an edge to it on the active sheet is refused.
