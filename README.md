# regula

A cross-platform (web, Android, iOS) dynamic geometry app built with Flutter.

**Live at <https://stevesuave.github.io/regula/>** — every push to `main` builds
`flutter build web --wasm --release` and publishes it to GitHub Pages.

Construct points, lines, circles, conics and derived objects (intersections,
midpoints, perpendiculars, triangle centers, transforms, loci, macros, …) on an
interactive canvas. Drag a free point and every dependent object updates
instantly: the construction is a DAG in which free points are the only mutable
roots and everything else recomputes from its parents. Every user action is a
reversible command, so the whole history undoes and redoes.

It is for people who teach, learn or explore geometry: students, teachers, and
people setting up olympiad-style problems. They expect the figure to move
continuously when they drag, to be able to explain itself, and to run where they
already are, in a browser tab or on a phone.

## What "V2" means

This is the second version of **regula**, a Flutter dynamic geometry app whose
kernel computed in ordinary real affine coordinates — `Vec2`, line equations,
circle equations, with epsilon bands deciding when a construction was degenerate.
That version reached ~39 object kinds and ~42 tools, and hit the ceiling the
representation imposes: intersection points that jump to the other branch when a
drag passes a degeneracy, loci that break into pieces at their crossings, and
special cases (parallels, tangencies, points at infinity) handled by hand rather
than by the algebra.

V2 replaces the kernel: **homogeneous coordinates over ℂ, with drags resolved by
analytic continuation** along a path that detours through complex space around
degeneracies — the approach Cinderella established. Under it,

- line ∩ line is *always* exactly one point (possibly at infinity) — a cross product,
- line ∩ conic is *always* exactly two (possibly complex, possibly coincident),
- conic ∩ conic is *always* four, via the pencil `λA + μB`,
- circles become conics through the circular points I = (1, i, 0) and J = (1, −i, 0),
  which also yields Cayley–Klein hyperbolic and elliptic geometry nearly for free,
- being "defined" stops being a property of the construction graph and becomes a
  rendering question: is this value real and finite after projection?

The old repository is private, but nothing here depends on it: this repo carries
the complete V1 git history (the branch point is tagged `v1-final`), V1's
surviving architecture is documented in `docs/archive/PLAN-v1.md`, its affine
kernel is preserved under `test/v1_oracle/` as the agreement oracle the new
kernel is specified against, and the assessment that motivated the rewrite is
`docs/V2-assessment.md`.

## Features

Construction:

- **Points** — free, derived, and constrained points glued to a line, circle,
  arc, or general conic
- **Lines** — line, segment, ray, perpendicular, parallel, angle and
  perpendicular bisectors, tangents, polar, radical axis
- **Circles** — center + rim point, by diameter, by radius, through three points,
  compass (transferred radius), arc, sector, nine-point, inscribed, Apollonius
- **Conics** — through five points, parabola from focus and directrix, ellipse and
  hyperbola from their foci, or from a given eccentricity
- **Intersections** — of any pair of the above, with branch identity preserved
  across drags rather than re-sorted per frame
- **Triangle centers** — circumcenter, incenter, centroid, orthocenter, and the
  circles that go with them
- **Angles** at a vertex or between two lines, including angles of a given size
- **Transformations** — reflection about a line or a point, rotation, translation,
  dilation, applied to points and to whole curves
- **Polygons and shape macros** — triangle, quadrilateral and regular-polygon presets
- **Loci** — traced by the continuation engine, so they follow their curve through
  crossings instead of stopping at them

Document and workspace:

- **Non-Euclidean documents** — switch the whole construction between Euclidean,
  hyperbolic and elliptic geometry from the geometry menu; the absolute is sized to
  your figure, and the switch is an undoable edit like any other
- **Measurements and live text** — distance, area, slope, and text objects with
  `{…}` expression slots that evaluate against the construction as it moves
  (language reference in `docs/EXPRESSIONS.md`)
- **Full undo/redo** over a reversible command stack; one command per drag gesture
- **Object tree, attributes inspector, and keyboard shortcuts**
- **Save/load** to `.rgl` (versioned JSON, with migrations for older documents) and
  **PNG export**
- **3D view** — the cube button in the app bar unlocks the camera, so any
  document can be turned around in space: one finger (or a drag on empty canvas)
  orbits, two fingers pan and zoom, and a Views menu offers top, front, side and
  oblique. Everything else works as before on the tilted figure
- **Points in space** — in the 3D view a selected free point has a handle that
  lifts it off its plane; segments, lines, rays, midpoints and parallels follow
  it, so a pyramid is a base, a lifted apex and the edges between them
- **Planes** — through three points, through a line and a point, perpendicular
  to a line or parallel to another plane; the perpendicular from a point to a
  plane; and the Intersection tool meets a line with a plane and a plane with a
  plane
- **Working inside a plane** — tap a plane to make it active (a chip names it
  and returns to the base plane) and every 2D tool builds in it: circles,
  perpendiculars, bisectors, intersections, with new points belonging to the
  plane and moving with it. An existing point or line can be used there when it
  lies in the plane by construction; two lines of space intersect through a
  plane that holds both, so skew lines never do
- **Solids** — pyramid and prism over a base polygon (tap its corners, the
  first again, then the point it rises to, or anywhere to pull it up by a
  handle), cube and regular tetrahedron from one base edge. A solid's edges are
  ordinary segments, so points can be put on them and slid along; a tap on a
  face makes that face the plane the 2D tools work in
- **Cross-sections** — the Section tool takes a plane and a solid and gives the
  polygon the plane cuts, which follows every drag, says how many sides it has
  and is measured by the Area tool
- **Hidden edges** — in the 3D view, whatever straight line passes behind a face
  of a solid is drawn dashed there, as in a textbook; hide the solid for the
  wireframe
- **Light/dark theme**

Also built in, as an experimental feature that is off by default: a JGEX-style
deductive-database theorem prover whose proofs replay step by step on the figure.
Open it from the geometry menu (the globe): **Experimental → Prover**, which
shows its panel. Stereometry is in progress (angles, distances and volumes in
space come next, then spheres, cones and cylinders); see `intent/README.md`.

## Non-goals

Decided, with the reasoning in `docs/DECISIONS.md`:

- **No general quadric ∩ quadric in 3D.** It is a quartic space curve: a great
  deal of effort for almost no user value.
- **No Wu's method or Gröbner bases in the prover.** Their proofs are unreadable.
- **No code from Cinderella.** It is proprietary; the mathematics comes from the
  published papers. JGEX, DDAR and Newclid are sources for rule sets, not code.
- **No GPU rendering stack for 3D.** `CustomPainter` with depth sorting.
- **No rewrite of the V1 shell.** Toolbar, inspector, object tree, shortcuts,
  command stack and construction DAG gain new arms and are never restructured.

## Getting started

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d chrome     # or -d <device-id> for Android/iOS
```

Run the checks — this is also the CI gate:

```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
```

`test/web/` holds the tests whose correctness rests on the browser's rasterizer
rather than on our own arithmetic; a plain `flutter test` skips them.

## Project layout

| Concern | Location |
|---|---|
| Projective kernel (Complex, ProjPoint, ConicMatrix, tracing) | `lib/domain/projective/` |
| Affine chart types and metric helpers | `lib/domain/math/` |
| Construction graph and objects | `lib/domain/construction/` |
| Tool state machines, reversible commands | `lib/domain/tools/`, `lib/domain/commands/` |
| Theorem prover | `lib/domain/prover/` |
| Riverpod providers, save/load | `lib/application/` |
| Canvas, painter, hit test, panels, theme | `lib/presentation/` |

`lib/domain/` is pure Dart — it never imports `package:flutter/*` — and is unit
tested in isolation; the boundary is crossed only through `lib/application/`.

Each change is one folder under `intent/` (intent, then spec, then plan);
`intent/README.md` is the index. Architecture and pinned decisions live in
`docs/DECISIONS.md`, the history of the old phase-by-phase method in
`docs/archive/`. `CLAUDE.md` states the invariants any change has to keep.
