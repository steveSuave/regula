# Plan: stereometry milestone 3 — solids, cross-sections, dashed hidden edges

Written 2026-11-25 from [spec](spec.md) · Status: approved 2026-11-25, in progress · Branch: `intent-004-stereometry`

Three stages. Each ends green on the full gate, with a look, and merges to `main`.

- **Stage A — what solids rest on.** Polygons, glued points and translations in space.
- **Stage B — solids and faces.** The two kinds, raised points, the four tools, working in a face.
- **Stage C — sections and hidden edges.** The section polygon, dashing, the grid, the fixture.

## Files that change

| File | Change | Stage |
|---|---|---|
| `lib/domain/construction/geo_object.dart` | `GeoPolygon.spaceVertices` and widened `isDefined`; `GeoLine.spaceParameterOrigin` / `spaceDirection`; `GeoSolid` (B) | A, B |
| `objects/polygon.dart`, `translated_point.dart`, `point_on_object.dart` | space values | A |
| `objects/segment.dart`, `ray.dart`, `line_through_two_points.dart`, `parallel_line.dart`, `perpendicular_to_plane_line.dart`, `plane_intersection_line.dart` | the space parameter origin | A |
| `lib/domain/tools/drag_session.dart` | a glued point on a space host drags statically, from a parameter the canvas supplies | A |
| `objects/raised_point.dart`, `proportional_raised_point.dart` | new | B |
| `objects/pyramid.dart`, `prism.dart`, `face_plane.dart` | new | B |
| `lib/domain/construction/construction.dart`, `mutable_roots.dart`, `commands/set_point_height_command.dart`, `tools/lift_session.dart` | a height on either kind | B |
| `lib/domain/construction/space_incidence.dart` | solids' faces; `SegmentRatioPoint`, `TranslatedPoint`; the section's plane (C) | B, C |
| `lib/domain/tools/pyramid_tool.dart`, `prism_tool.dart`, `cube_tool.dart`, `regular_tetrahedron_tool.dart` | new | B |
| `lib/domain/tools/plane_scope.dart` | a pending face plane rides in the commit | B |
| `lib/application/providers/active_plane_provider.dart` (+ `.g.dart`), `tool_provider.dart` | a plane id or a (solid, face) pair; the new tools | B |
| `lib/domain/projective/space/section.dart` | new: the classing and chaining, pure | C |
| `objects/section_polygon.dart`, `tools/section_tool.dart` | new | C |
| `lib/presentation/canvas/hidden_line.dart` | new: hidden intervals, pure | C |
| `lib/presentation/canvas/screen_figure.dart`, `space_hit_tester.dart` | ink for space polygons (A) and solids (B) | A, B |
| `lib/presentation/canvas/geometry_painter.dart` | space polygons (A); face fills, the active face outline (B); the hidden-line path, the grid in a plane (C) | A, B, C |
| `lib/presentation/canvas/geometry_canvas.dart` | the glued-point drag in space (A); face taps, the handle on a raised point (B) | A, B |
| `lib/presentation/canvas/plane_patch.dart` | extent over all ink on the sheet | C |
| `active_plane_chip.dart`, `toolbar.dart`, `object_tree_panel.dart`, `object_kind_label.dart`, `attributes_inspector.dart`, shortcuts | face names; the tools; a section's side count | B, C |
| every exhaustive kind switch | a `GeoSolid` arm | B |
| `lib/application/persistence/construction_codec.dart` | the new types; a face plane left out when unused | A, B, C |
| `docs/DECISIONS.md`, `CLAUDE.md` | §"Solids are faces over ordinary points" (B); §"Sections and hidden edges" (C); the mutable-roots line (B) | B, C |
| `test/space_fixtures/cube_section.rgl`, `README.md` | new; the tools | C |

## Order of work

**Stage A**

1. **Baseline** on a clean `main`: analyze, VM, browser, goldens. Counts recorded here, and a saved 2D document kept for byte comparison.
2. **`Polygon` in space.** Tests: on a shared sheet the planar value is bitwise what it was and `spaceVertices` is its lift; with one vertex lifted `polygonVertices` is null, `spaceVertices` is real and the polygon is defined; an `AreaMeasurement` on it is undefined and returns when the height is 0. Painter and ink: a recording-canvas test that the outline is drawn at `spaceToScreen` of the vertices; a tap inside the fill hits it.
3. **`TranslatedPoint` in space.** Tests on the pattern of the five intrinsic kinds.
4. **The space parameter of a line, and `PointOnObject` on it.** Tests:
   - for a base-sheet segment the planar value and stored parameter are untouched;
   - continuity: a point glued at parameter t on AB moves by O(h) when B is lifted by h, on the base sheet and on a tilted plane's sheet;
   - on a `PerpendicularToPlaneLine` the parameter is the height over the plane;
   - the parameter clamps to a segment's ends in space;
   - `PointOnObject.near` from a space position.
5. **Dragging it.** Session-level tests (the memory note: engine tests miss the command path): a drag along an edge to a lifted apex ends in one `SetPointOnObjectParameterCommand`, undo restores, cancel rolls back; the Point tool on a space segment glues. Widget test with touch at phone size.
6. **Codec, browser gate, stage look, merge.** A space polygon and a glued point on a space edge round-trip at version 4; the decoder's shared-sheet check admits `Polygon`, `TranslatedPoint` and `PointOnObject`.

**Stage B**

7. **Raised points and the height interface.** Tests: value over the base plane and over a tilted plane; `ProportionalRaisedPoint` follows its two points; command apply, undo, redo; `MutableRoots` saves and restores a height; the lift handle appears for a selected `RaisedPoint` and one drag is one command.
8. **`GeoSolid`, `Pyramid`, `Prism`**, with the arm in every exhaustive switch and the face fills painted (one commit; a solid with no picture is not a state worth one). Tests: vertices, faces and edges of each; every face wound outward for a base drawn in either sense and an apex on either side; undefined with a base vertex lifted, defined again at 0; a triangle base with a lifted vertex stays defined; Euler's formula on both as a `glados` property over the base size; one new golden of a prism and a pyramid at Oblique; the old goldens unchanged.
9. **The four tools and the toolbar.** Tests per tool on the existing pattern: object counts and kinds, one command, one undo; a base point not in the active plane is refused with the reason; cube edges equal and faces square to 1e-12 before and after a session-level drag of each free point; tetrahedron edges equal likewise; the new top point is selected after commit.
10. **`FacePlane`, `liesIn` for solids, and the active face.** Tests: each new incidence rule, and a point that is in a face numerically but not by construction is refused; a tap on a face activates it and the chip names it; the pending plane is one instance across the taps of one tool; a circle through three vertices of a cube's face is one command holding the plane, three adapters and the circle, and one undo removes all five; a second construction in that face reuses the plane; New, Open, view off and undo return to the base plane.
11. **Codec; DECISIONS and `CLAUDE.md`; browser gate, look, merge.** Round-trips; an unused face plane is not written and a used one is.

**Stage C**

12. **The section algorithm**, pure, in the kernel. Tests: a cube cut to a triangle, a quadrilateral, a pentagon and a regular hexagon (side count and area against closed forms); a plane through a vertex, along an edge and containing a face; a plane that misses; `glados`: every section vertex lies on the plane and on an edge, and the loop is convex for a convex solid.
13. **`SectionPolygon` and the Section tool.** Tests: it sits on the plane's sheet; `AreaMeasurement` reads it; the side count in the inspector; a drag of a plane point through a vertex changes the count without an undefined frame.
14. **Hidden intervals**, pure. Tests: a segment wholly behind, wholly in front, piercing a face, passing behind a corner; an edge of the face itself is not hidden; a non-convex face; a segment behind two faces gives the union.
15. **The painter's hidden-line path.** Tests: for a cube at Oblique exactly the three back edges are dashed, and at Top none; a hidden solid dashes nothing; with no solid the recording canvas sees the calls it saw at step 1; goldens unchanged plus one new; a `test/web` case.
16. **The grid in the active plane; the patch over all ink.** Tests: the patch contains a circle built in it; the grid is drawn through the active plane's viewport and not when the base plane is active in 2D.
17. **The acceptance fixture.** `cube_section.rgl`: a cube, three glued points on three edges, the plane through them, the section. Its side count and its area against a hand computation to 1e-9, before and after a session-level drag.
18. **Browser gate, README, DECISIONS, looks, close and ship.** Progress here, the status row, merge, push, `gh run list`, the deployed build.

**Looks, each stage.** Ask before using Chrome and check `tabs_context_mcp` first; otherwise the headless release build with mouse and touch, at 1280 wide and at 400×800. Stage B's phone look includes the plane tools and the active plane, owed from milestone 2. Say plainly what was not seen.

## Risks

- **A last bit moves in 2D.** `GeoPolygon.isDefined`, `PointOnObject`, `TranslatedPoint` and the painter's straight-ink path are all on the 2D path. Each takes the old branch first. A golden diff or a changed save byte is a stop.
- **The planar and space parameter origins may not agree** as the spec assumes (`LineEq.direction` against `Line3`'s direction for each kind). Step 4's continuity test is written first; if a kind fails it, that kind takes its sheet's lift explicitly.
- **The drag session's glued-point path is built on a chart reading** (`line.parameterAt`). If a space host cannot be given to it cheaply, the space drag becomes its own small session, like `LiftSession`, and the departure is recorded here.
- **The pending face plane's identity.** Held in the provider, keyed by (solid id, face index), dropped on commit, undo, New and Open. Step 10's two-tap test is the guard.
- **Outward winding at zero volume** has no answer. The faces keep their last-computed sense only by accident, so the kind uses a fixed rule there (the base's own sense) and the hidden-line pass skips a flat solid.
- **Hidden-line margin.** Tuned on the cube and the pyramid fixture at the four presets; step 15 asserts the dashed set at each.
- **Stage size.** If stage C runs long, the grid and the patch extent (step 16) ship after the milestone.

## Proof

- Each step's tests green; the CI gate green at each stage end.
- Goldens unchanged from step 1 apart from the new files; a saved 2D document byte-identical to step 1's.
- `git diff main --stat -- test/fixtures test/v1_oracle` empty at every merge.
- The acceptance fixture of step 17, which is the intent's second fixture.
- The three stage looks, on wide and phone, and the deployed build.

## Progress and gotchas

- **Step 1, baseline.** Not re-run as its own step: `main` was at milestone 2's closing gate (analyze clean; VM 3876; goldens 36; browser 18) with only documents committed since. The first run made here overlapped the first edits and is not a baseline.
- **Steps 2 to 6, what solids rest on** (stage A, one working pass). Tests: 14 in `test/domain/construction/space_carriers_test.dart`, 12 in `test/domain/tools/space_slide_session_test.dart`, 9 in `test/presentation/canvas/space_carriers_view_test.dart`, 2 more in `codec_space_test.dart`, 3 widget tests (group "a point on an edge of space", mouse and touch). Full run 3916 with goldens, none moved; browser 18. Departures and notes:
  - **The space drag is its own session, `SpaceSlideSession`**, as the risk list allowed. The planar slide projects a world point onto a chart form; an edge of space has none. The canvas reads one screen axis per line (`spaceLineScreenAxis`) and hands the session a parameter, the way it hands `LiftSession` a height.
  - **The Point tool gets the reading through `ToolInput.spaceParameterOn`**, a callback, because `position` is a point of the active plane and such an edge is in none.
  - **`GeoLine.spaceParameterFrame`** is one accessor (origin and unit direction), not the two the spec named. The continuity test passed for segment, line and ray on the base sheet and on a tilted plane with no per-kind override; only `PerpendicularToPlaneLine` overrides, to measure from its plane.
  - **Found on the way: a planar tool was handed a lifted point or an edge to one** when its plane was active, since both are on that sheet by structure. `resolvePoint` then called `PointOnObject.near` on a line with no chart, which throws. `PlaneScope` now refuses them (DECISIONS), and `resolvePoint` no longer reaches `near` for such a line.
  - **A third scope, `ToolScope.planeAndSpaceLines`**, for the Point tool only.
  - `TranslatedPoint` in space is Euclidean by construction, like the planar one; a document with space content is Euclidean.
  - The decoder's shared-sheet check admits `Polygon`, `TranslatedPoint`, and a `PointOnObject` whose host is a line.
  - **Not tested: `PointOnObject.near` from a space position.** There is no such factory; a space position reaches the kind as a parameter (`PointOnObject.onSpaceLine`).
  - Gotcha: a background gate started while editing reads half-edited files. Run it in the foreground or after the edits.
  - **A face over points of space is ground to a planar tool**, like a plane's patch: the tap passes through it to the active plane. The first version of the refusal above also refused a Point-tool tap anywhere inside such a face, which the stage look found.

- **Stage A look.** The release wasm build on 127.0.0.1 in a separate headless Chrome over the DevTools protocol, read from screenshots. The Chrome extension was not used.
  - Seen at 1280 wide, mouse: a filled triangle ABC drawn with the Polygon tool and a segment AC; the 3D button tilts it; a tap on C shows the grip, and dragging it up lifts C with the fill and outline following (before this stage the polygon vanished); the Point tool tapped on the middle of the lifted edge AC puts a point on the edge, and tapped inside the face puts a free point on the base plane behind it; a drag of the glued point moves it along the edge and nowhere else; an orbit turns the figure with the glued point still on the edge.
  - Seen at 400×800, touch: Fit frames the lifted triangle; a touch drag of the glued point slides it about 100 px down the edge.
  - **Not seen in a browser**: a point glued by a touch tap (the one touch tap tried fell inside the face, on no edge); the slide stopping at an end of the edge; an edge seen end-on; a translated point in space; opening a saved file with these in it. Those rest on the widget and unit tests.
- **Stage A closed 2026-11-25.** Final gate: analyze clean; 3917 with goldens, none moved; browser 18; `flutter build web --wasm` built. `git diff main --stat -- test/fixtures test/v1_oracle` is empty.
