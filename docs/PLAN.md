# Dynamic Geometry App in Flutter

## Context

Build a cross-platform (web, Android, iOS) dynamic geometry application from scratch in an empty repo. The app is a constructive geometry tool: the user drops free points and builds derived objects (lines, circles, intersections, midpoints, triangle centers, …) on top of them. Dragging a free point must propagate updates to every dependent object correctly and instantly. The project will live in `/Users/stefanos.levantis/Code/var/fgex/`.

Decisions confirmed up front:

- **State management:** Riverpod.
- **Persistence:** Local JSON files only (via `file_picker` — works on web via download/upload, on mobile via the native picker).
- **Undo/redo:** Full Command-pattern undo/redo.
- **Testing:** Unit + property-based + widget + golden tests.

The fundamental abstraction is a **construction graph**: a DAG of geometric objects where every derived object is a pure function of its parents. Free points are the only mutable roots. The same graph powers rendering, hit testing, undo/redo, and save/load.

## Architecture

### Layer separation

```
lib/
├── domain/          # Pure Dart, no Flutter imports — fully unit-testable
│   ├── math/        # Vec2, line/circle primitives, intersections, predicates
│   ├── construction/# GeoObject hierarchy + Construction (the DAG)
│   ├── tools/       # Tool state machines
│   └── commands/    # Undo/redo command interface + concrete commands
├── application/     # Riverpod providers, controllers, persistence I/O
│   ├── providers/
│   └── persistence/
├── presentation/    # Flutter widgets, painters, theme
│   ├── canvas/
│   ├── panels/      # toolbar, tool palette, attributes inspector, object tree
│   └── theme/
└── main.dart
```

The `domain/` layer must not import `package:flutter/*`. This is the boundary that makes the math testable without a widget tester and reusable across platforms.

### Construction graph (`domain/construction/`)

- `sealed class GeoObject` with `id`, `parents`, `attributes: ObjectAttributes`, and `void recompute()`. Sealing is at the *kind* level: `GeoPoint` / `GeoLine` / `GeoCircle` / `GeoAngle` are the sealed branches, concrete objects extend an open kind — Dart requires a sealed class's direct subtypes in the same library, which one-file-per-object rules out on the root. Kind switches are exhaustive; concrete-type switches are not.
- Kinds are *value shapes*, not visual shapes. A kind's geometry accessor is what intersection math and hit testing consume: `GeoPoint.position`, `GeoLine.line` (carrier `LineEq` — segments and rays reuse line∩x math through it, with extent clamps at the painter/hit-tester), `GeoCircle.circle` (carrier `CircleEq` — arcs and sectors reuse circle∩x math the same way, with *angular* extent clamps), `GeoAngle.angle` (an `AngleGeometry`: vertex, unit start direction, CCW sweep in [0, 2π) — angles are decorations plus a measure; nothing intersects them).
- `parents` is a getter derived from typed parent fields (e.g. `Midpoint` holds `GeoPoint point1, point2`), so ill-typed constructions are unrepresentable rather than runtime errors.
- Derived objects support an *undefined* state (degenerate parent configuration — coincident points defining a line, curves that stopped intersecting mid-drag). Undefined objects stay in the graph, are skipped by painter/hit-tester, and recover when the degeneracy passes.
- Subclasses (one file each, grouped by kind):
  - **Points:** `FreePoint`, `PointOnObject` (constrained to a curve), `IntersectionPoint`, `Midpoint`, `Centroid`, `Orthocenter`, `Incenter`, `Circumcenter`, `SegmentRatioPoint`. Planned (Phase 15, transformations): `ReflectedPoint` (about a line), `CentralReflectionPoint` (about a point), `RotatedPoint` (about a center by a fixed angle), `TranslatedPoint` (by the vector between two points) — ordinary derived points, so recompute, persistence and hit testing work unchanged; exact names may be refined at implementation per the "subclasses end in their kind" convention.
  - **Lines:** `LineThroughTwoPoints`, `Segment`, `Ray`, `PerpendicularLine`, `ParallelLine`, `AngleBisectorLine`.
  - **Circles & arcs:** `CircleCenterPoint`, `ThreePointCircle`, `CompassCircle` (two points defining radius + center), `Arc` (through three points: endpoints first and last, the arc is the carrier branch containing the middle point; undefined while collinear), `Sector` (center + rim point fixing radius and start angle + a third point fixing only the end angle; sweep is CCW from start to end).
  - **Angles:** `VertexAngle` (arm–vertex–arm points; sweep is CCW from the first arm's ray to the second's, so the two tap orders give the two complementary markers) and `LineAngle` (between two lines; always the acute/right angle in (0, π/2], vertex at the intersection, undefined while parallel).
- `class Construction` owns the DAG: insertion-ordered map of objects (insertion order doubles as topological order), topological recompute on dirty propagation, dependents lookup for cascading delete. It is pure Dart with a minimal hand-rolled listener API — *not* a Flutter `ChangeNotifier` (the domain layer must not import Flutter, and `ChangeNotifierProvider` is the legacy path in Riverpod 3 anyway). The application layer wraps it in a `@riverpod` `Notifier` that re-exposes state after each command. If that notifier ends up being the only listener by Phase 4, drop the listener API.
- `class ObjectAttributes`: `name`, `colorArgb` (raw ARGB int, `null` = theme default — the domain layer can't use Flutter's `Color`; presentation maps it), `visible`, `labelVisible`, `strokeWidth`, plus per-type extras (point size, fill alpha for sectors). Built with `freezed` for immutability + `copyWith`.

### Pure math (`domain/math/`)

- `Vec2` with the usual ops, `dot`, `cross`, `norm`, `distanceTo`.
- `LineEq` / `CircleEq` value types for analytic forms.
- `intersections.dart`: line∩line, line∩circle, circle∩circle returning `List<Vec2>` (0/1/2). Each intersection object carries an `index` so the user's chosen branch is stable across drags.
- Caveat: the index is *deterministic*, not *continuous*. Line∩circle branches are ordered along the line's direction, so dragging a defining point past the other reverses the direction and the two branches visibly swap. Known wart, not a bug. If it bothers in Phase 5/6 manual testing, layer a runtime continuity heuristic (prefer the candidate nearest the previous position) on top — but the *persisted* branch stays the index; continuity is path-dependent and must never leak into the save format.
- `triangle_centers.dart`: closed-form centroid, orthocenter, incenter, circumcenter.
- `angle_geometry.dart`: `AngleGeometry` value type (vertex, unit start direction, CCW sweep) plus angle helpers — `ccwSweep(from, to)` in [0, 2π), and the arc-branch pick `sweepThrough(start, via, end)` (signed sweep from start to end passing via; feeds `Arc`).
- All functions are pure, take `Vec2`s, and have epsilon-tolerant predicates (`isParallel`, `isCollinear`).

### Tool system (`domain/tools/`)

- `abstract class Tool { ToolState onTap(...); ToolState onHover(...); Command? complete(...); }`
- One subclass per tool: `PointTool`, `LineThroughTwoPointsTool`, `MidpointTool`, `IntersectionTool`, `ThreePointCircleTool`, `AngleBisectorTool`, `CompassTool`, `SegmentRatioTool`, `SquareMacroTool`, `ParallelogramMacroTool`, `TrapeziumMacroTool`, etc.
- A tool collects N hit-tested inputs (existing objects or new free points), then emits a `Command`. Snap-to-object during input collection.
- Planned tool additions (Phases 13–16): `IntersectionTool` *(landed, Phase 13)* — pick two curves; creates the `IntersectionPoint` branch nearest the *second* tap, resolved by probing both branch objects so the choice rides the documented deterministic branch order; non-intersecting curves still commit branch 0 (undefined until dragged together). Transformation tools for the Phase 15 point kinds (reuse `PointAndLineTool` / `TwoPointTool` input shapes where they fit; rotation takes its angle from a dialog like the segment-ratio tool), `AngleBySizeTool` (arm point, vertex, size dialog → a `RotatedPoint` plus a `VertexAngle` — GeoGebra convention; depends on Phase 15's rotation), and macro tools for equilateral / isosceles / right / random triangles and random / regular polygons (regular-polygon side count via dialog; "random" macros stamp randomized *free* points, fully editable afterwards).
- Macro tools (square, parallelogram, trapezium) are scripted compositions of primitive commands wrapped in a single undoable `MacroCommand`. Derived corners come from *hidden* scaffolding objects over the visible sides (perpendiculars + compass circles for the square, parallels for the parallelogram and trapezium), so macros introduce no new object kind — codec, painter and hit tester are untouched. Input schemes: **square** = 2 taps, adjacent corners A, B; the shape lies to the *left* of A→B (branch 1 of line∩circle along the perpendicular's direction — the AB carrier's CCW normal — which follows the points continuously, so the side never flips mid-drag). **Parallelogram** = 3 taps, consecutive corners A, B, C; D = A + (C − B) as the single-branch intersection of two hidden parallels. **Trapezium** = 3 taps for consecutive corners A, B, C plus a 4th *position-only* tap that places D as a `PointOnObject` projected onto the hidden parallel-to-AB through C — direct manipulation instead of a ratio dialog; AB ∥ CD by construction, and D inherits `PointOnObject`'s analytic-parameter caveat (translating the parallel along itself leaves D in place). The 4th tap never consumes an existing point — D must stay constrained to the parallel.

### Commands (`domain/commands/`)

- `abstract class Command { void apply(Construction c); void undo(Construction c); }`
- Concrete commands: `AddObjectCommand`, `DeleteObjectsCommand` (cascades to dependents — captures their full state for restore), `MoveFreePointCommand` (one command per drag gesture, not per frame), `TranslateObjectsCommand` (rigidly translates a *set* of free points by one delta in a single undo step — this is how dragging a derived object works, see canvas section), `ChangeAttributesCommand`, `MacroCommand` (groups N commands).
- Drag preview: during a gesture the construction is mutated directly per frame (no command per frame). The gesture must terminate by emitting exactly one command capturing start → end, or by rolling the preview back on cancel (Esc mid-drag). This is the one sanctioned mutation outside a command; CLAUDE.md states the invariant with this carve-out.
- `class CommandStack` (in `application/`) holds undo + redo stacks, exposed as a Riverpod `Notifier`.

### Canvas & interaction (`presentation/canvas/`)

- `GeometryCanvas` widget hosts a `CustomPaint` with a `GeometryPainter` and a gesture stack:
  - `Listener` for pointer events (mouse + touch).
  - `GestureDetector` for tap, pan, scale.
- `Viewport` value type: `Vec2 pan` + `double scale`. World↔screen transforms live here, including zoom-about-a-focal-point (the world point under the cursor stays fixed) and scale clamping.
- Viewport changes (pan, zoom, fit, reset) are *view* state, not construction state — they never go through `Command`s and are not undoable, for the same reason selection changes aren't: undo should replay edits to the document, not replay where the user was looking. The viewport is still snapshotted into the save format (Phase 9), just outside the undo history.
- `HitTester`: iterates visible objects, returns the closest under an 8 px threshold, with priority order points > arcs/circles > segments/rays/lines > angles. Used by both tools (input picking) and the selection drag.
- Dragging (in the no-tool move/select mode): a free point moves directly (`MoveFreePointCommand`). Any *other* object drags as a rigid translation of its free-point ancestors — grab a circle's rim and the whole circle moves because its defining points do — emitting one `TranslateObjectsCommand` per gesture. Two planned exceptions (Phase 14): a `PointOnObject` slides along its host curve (new `SetPointOnObjectParameterCommand`, one per gesture, same preview/rollback contract as the other drags), and a `CompassCircle` drags by moving only its *center's* free ancestors — the radius-defining points stay put, because the radius is a measurement, not part of the rigid body. Fully-derived objects with no free ancestors (e.g. an intersection point) don't drag. (A dedicated Drag tool with a select-only no-tool default was considered and shelved — dragging stays in the no-tool mode.)
- `GeometryPainter` walks the construction in insertion order, applies the viewport transform, draws each object using its attributes. Labels rendered via `TextPainter`.
- Multi-touch on mobile: pinch = zoom, two-finger drag = pan. On web/desktop: scroll = zoom, drag empty = pan. Known gap (Phase 14): on web there is no trackpad drag-to-pan at all — a Mac multi-finger swipe arrives as browser wheel events, which the app maps to zoom-about-cursor; with the cursor off-center each step scales *and* shifts the drawing, easily read as "panning also resizes". A macOS three-finger drag (accessibility) is a synthetic mouse drag and rubber-bands instead. Space+drag and arrow keys are the only web pans today. Phase 14 decides the trackpad mapping (e.g. plain scroll = pan, pinch / Ctrl+scroll = zoom, Figma-style) and makes the pan gestures discoverable.

### Panels (`presentation/panels/`)

- **Toolbar / tool palette** — grouping (landed in Phase 13, in `presentation/panels/toolbar.dart`): **Points** (flyout: free point, midpoint, segment-ratio point, intersection, point-on-object, centroid, orthocenter, incenter, circumcenter), **Lines** (flyout, renamed from the two-point menu: line, segment, ray, perpendicular, parallel, angle bisector), **Circles** (flyout: circle center+rim — moved here from the two-point menu — three-point circle, compass, arc, sector), **Angles** (flyout: at vertex, between lines; *by given size joins in Phase 16*), **Transform** (flyout: reflect about line, reflect about point, rotate around point, translate by vector — *Phase 15*), **Macros** (flyout: square, parallelogram, trapezium; *triangles and polygons join in Phase 16*). The group icon highlights while its tool is active, so the current tool is always visible. Adapt to mobile with a bottom sheet (still open). Builders are public top-level tear-offs shared with the keyboard switch; the Points highlight is a catch-all for builders no tear-off claims (the segment-ratio dialog's closure).
- **Tool activation / deactivation** — (landed in Phase 13) the active tool's flyout group icon is highlighted; **double-clicking the highlighted group icon deactivates** the tool, and the group's tooltip appends "double-click to deselect" while active. The double-tap detector mounts only on the active group, so the double-tap delay on opening a flyout applies only there. `Esc` and `V` always deactivate. With no tool active the app is in move/select mode (select + drag — see Canvas & interaction).
- **Attributes inspector** — shown when ≥1 object is selected. Edits name, color, visibility, label visibility, stroke width via `ChangeAttributesCommand`s (so attribute edits are undoable).
- **Object tree** (collapsible) — flat list grouped by type, useful for selecting hidden objects.
- **App bar** — file menu (new/open/save/save as), undo/redo, theme toggle.

### Theme (`presentation/theme/`)

- `ThemeData.light()` / `ThemeData.dark()` with a custom palette tuned for canvas contrast (canvas background, axis lines, default object colors per theme). Theme choice persisted in `shared_preferences`.

### Persistence (`application/persistence/`)

- JSON schema:
  ```json
  {
    "version": 1,
    "viewport": {"pan": [0,0], "scale": 1},
    "objects": [
      {"id": "p1", "type": "FreePoint", "parents": [], "params": {"x": 1.0, "y": 2.0}, "attributes": {...}},
      {"id": "m1", "type": "Midpoint", "parents": ["p1","p2"], "params": {}, "attributes": {...}}
    ]
  }
  ```
- Save: serialize each object in topological order (= the construction's insertion order).
- Load: parse, then construct in order — each constructor receives already-deserialized parents by id. Use `freezed`'s json support for attributes.
- Encode/decode both live in one hand-written codec (`application/persistence/construction_codec.dart`) that switches on concrete object type, rather than `toJson` methods spread across the domain classes: the type↔constructor registry must exist centrally for *decoding* anyway, keeping the encoder beside it means one file to update per new object kind, and the domain layer stays free of persistence concerns. The cost — a forgotten kind fails at runtime, not compile time — is covered by the round-trip test that instantiates every concrete kind.
- Decode failures (malformed file, unknown type, unknown version, ill-typed parents) throw `FormatException` with the offending object's id, so File > Open can show one dialog for any bad file.
- Schema version field from day one to allow future migrations. A file with a *newer* version than the app understands is rejected, not best-effort parsed.

## Critical files to create

| Path | Purpose |
|---|---|
| `pubspec.yaml` | Dependencies: `flutter_riverpod`, `freezed`, `json_serializable`, `file_picker`, `shared_preferences`, `uuid`. Dev: `build_runner`, `flutter_test`, `mocktail`, `golden_toolkit`, optionally `glados` (property-based tests). (`vector_math` was planned but dropped — the domain layer hand-rolls an immutable `Vec2`.) |
| `lib/domain/math/vec2.dart` | 2D vector ops. |
| `lib/domain/math/intersections.dart` | All intersection routines, with degenerate-case handling. |
| `lib/domain/math/triangle_centers.dart` | Centroid, orthocenter, incenter, circumcenter. |
| `lib/domain/construction/geo_object.dart` | Sealed base + `ObjectAttributes`. |
| `lib/domain/construction/objects/*.dart` | One file per object kind (~20 small files). |
| `lib/domain/construction/construction.dart` | DAG, topological recompute, dependents lookup, cascading delete. |
| `lib/domain/tools/tool.dart` | Tool interface + state. |
| `lib/domain/tools/*.dart` | One file per tool. |
| `lib/domain/commands/command.dart` + `*_command.dart` | Command interface + implementations. |
| `lib/application/providers/construction_provider.dart` | Riverpod provider exposing the `Construction`. |
| `lib/application/providers/selection_provider.dart` | Selection set state. |
| `lib/application/providers/tool_provider.dart` | Active tool + tool state. |
| `lib/application/providers/viewport_provider.dart` | Pan/zoom state. |
| `lib/application/providers/command_stack_provider.dart` | Undo/redo. |
| `lib/application/persistence/construction_codec.dart` | JSON encode/decode. |
| `lib/application/persistence/file_io.dart` | Save/load via `file_picker` (web + mobile). |
| `lib/presentation/canvas/geometry_canvas.dart` | The canvas widget. |
| `lib/presentation/canvas/geometry_painter.dart` | `CustomPainter`. |
| `lib/presentation/canvas/hit_tester.dart` | Hit testing logic. |
| `lib/presentation/canvas/viewport.dart` | Viewport value type + transforms. |
| `lib/presentation/panels/toolbar.dart`, `attributes_inspector.dart`, `object_tree.dart` | UI panels. |
| `lib/presentation/theme/app_theme.dart` | Light/dark themes. |
| `lib/main.dart` | App entry, `ProviderScope`, theme wiring, layout. |

## Test strategy

Tests mirror the source layout under `test/`. Coverage targets:

- **`test/domain/math/`** — exhaustive numeric tests on intersections (parallel, tangent, coincident, near-tangent), triangle centers (verify against known coords for canonical triangles), and edge cases (degenerate triangles, points coinciding). Property-based via `glados`:
  - midpoint of (A, B) is equidistant from A and B
  - circumcenter is equidistant from all three vertices
  - centroid = (A + B + C) / 3
  - line through (A, B) contains both A and B within epsilon
  - reflection across a perpendicular bisector swaps A and B
- **`test/domain/construction/`** — recompute correctness: build a chain (e.g., midpoint → perpendicular → intersection), drag a root, assert all dependents are consistent. Cascade delete: deleting a parent removes all dependents and is reversible.
- **`test/domain/commands/`** — every command's `undo(apply(c)) == c` for representative inputs.
- **`test/domain/tools/`** — tool state machines: feed a sequence of `onTap` calls, assert the resulting command.
- **`test/application/persistence/`** — JSON round-trip on a complex construction (several derived layers, all object kinds), incl. attributes and viewport.
- **`test/presentation/`** — widget tests for tool flows (tap-tap to make a segment, drag a free point and see the dependent update), and golden tests for rendering each object kind in light + dark theme.

CI-friendly: keep golden tests in their own tagged group so they can be skipped on platforms where rendering differs.

## Keyboard shortcuts

Tools are bound to single letters where possible; less-common variants use Shift+letter or a two-key chord. The one source of truth is a declarative `ShortcutTable` (`lib/presentation/shortcuts/shortcut_table.dart`): a list of bindings, each a one- or two-stroke key sequence plus a semantic `AppAction`, a human-readable label, and a cheat-sheet section. A pure `ShortcutResolver` consumes key strokes one at a time and handles the two-stroke leader chords (a pending leader is cancelled by Esc or any non-matching second stroke, which is swallowed rather than fired standalone); an `AppShortcuts` `Focus` widget at the editor root feeds it hardware key events, marks matches handled, and ignores everything while an `EditableText` has focus so typing a name can never trigger a tool. Flutter's stock `Shortcuts`/`Actions` tables are deliberately *not* used: chords and the focused-text-field guard don't fit `ShortcutActivator`'s single-stroke, always-on model. Mobile users obviously skip these, but on web/desktop they're essential.

Selection / app-level:
| Key | Action |
|---|---|
| `Esc` | Cancel current tool, return to Move/Select |
| `V` | Move/Select tool (pointer) |
| `Del` / `Backspace` | Delete selection (cascades to dependents) |
| `Ctrl`/`Cmd` + `Z` | Undo |
| `Ctrl`/`Cmd` + `Shift` + `Z` (also `Ctrl`/`Cmd` + `Y`) | Redo |
| `Ctrl`/`Cmd` + `A` | Select all |
| `Ctrl`/`Cmd` + `S` / `O` / `N` | Save / Open / New construction |
| `Ctrl`/`Cmd` + `D` | Toggle dark mode |
| `H` | Hide selected · `Shift` + `H` reveals all |
| `Tab` | Cycle through selectable objects under cursor *(deferred — needs cursor-position tracking; Tab does focus traversal meanwhile)* |

Viewport:
| Key | Action |
|---|---|
| `+` / `=` · `-` | Zoom in / out |
| `0` | Reset zoom to 100 % |
| `F` | Fit construction to viewport |
| `Space` (held) + drag | Pan (any tool) |
| Arrow keys | Nudge viewport |

Tools (single-letter primary):
| Key | Tool |
|---|---|
| `P` | Point |
| `L` | Line through two points |
| `S` | Segment |
| `R` | Ray |
| `C` | Circle (center + point) |
| `M` | Midpoint |
| `I` | Intersection *(tool lands in Phase 13 — bind then; macros already build `IntersectionPoint`s internally)* |
| `B` | Angle bisector |
| `A` | Angle at vertex (`Shift` + `A` for angle between lines) |
| `T` | Perpendicular line (`Shift` + `T` for parallel) |
| `O` | Compass circle |

Chords (`G` = "geometry", a leader key for less-frequent constructions):
| Chord | Tool |
|---|---|
| `G` `C` | Centroid |
| `G` `O` | Orthocenter |
| `G` `I` | Incenter |
| `G` `U` | Circumcenter |
| `G` `3` | Three-point circle |
| `G` `R` | Segment-ratio point |
| `G` `A` | Arc (3-point) |
| `G` `S` | Sector |

Macros (`X` leader for advanced shapes):
| Chord | Tool |
|---|---|
| `X` `S` | Square |
| `X` `P` | Parallelogram |
| `X` `T` | Trapezium |
| `X` `E` | Equilateral triangle *(planned, Phase 16)* |
| `X` `I` | Isosceles triangle *(planned, Phase 16)* |
| `X` `R` | Right triangle *(planned, Phase 16)* |
| `X` `G` | Regular polygon *(planned, Phase 16 — random triangle/polygon stay menu-only)* |

Phase 16 chords are proposals; settle the final bindings (and any Transform-tool bindings) when the tools land.

The full table is rendered in a `?`-key cheat sheet overlay. Bindings live in `lib/presentation/shortcuts/shortcut_table.dart` and are tested with widget tests that send key events and assert the active tool / command.

## Build order (rough)

1. `pubspec.yaml`, `domain/math/`, full unit + property tests for math.
2. `domain/construction/` core (FreePoint, Midpoint, Line, Circle, Intersection) + recompute tests.
3. `domain/commands/` + `CommandStack` + tests.
4. Riverpod providers in `application/`.
5. Minimal `GeometryCanvas` + `GeometryPainter` + hit tester + one tool (PointTool); manual smoke test.
6. Round out remaining object types and tools (triangle centers, parallel/perpendicular, angle bisector, segment ratio, three-point circle, compass, arc, sector, angle).
7. Selection, attributes inspector, hide/show, delete-with-dependents.
8. Pan/zoom viewport.
9. Save/load + theme + shared_preferences.
10. Macro/advanced tools (square, parallelogram, trapezium) on top of the macro-command machinery.
11. Golden tests + widget tests for tool flows.
12. Toolbar rework & tool-selection UX: unified Points menu (incl. new intersection tool), Lines menu absorbs the line constructions, circle moves to the circles menu, deselect affordances. (TODO Phase 13)
13. Drag & gesture fixes: `PointOnObject` slide-drag, compass-circle center-only drag, trackpad pan mapping on web. (TODO Phase 14)
14. Transformations: reflect about line / about point, rotate around point, translate by vector. (TODO Phase 15)
15. Angle-by-given-size + triangle/polygon macros. (TODO Phase 16)

## Multi-session workflow

This app spans many sessions. A fresh session has zero memory of prior ones, so we lean on four durable artifacts in the repo. Any new session should be productive within a minute of warm-up.

| File | Role | Cadence |
|---|---|---|
| `docs/PLAN.md` | Architecture, build order, decisions. The "what and why." | Read-mostly; edited only when scope or approach changes. |
| `docs/STATUS.md` | Append-only log of what happened each session. The "where are we." | One entry per session, written at session end. |
| `docs/TODO.md` | Live checklist mirroring the build-order phases. | Tick boxes during the session as items land. |
| `CLAUDE.md` (repo root) | Architectural invariants, common commands, conventions. Auto-loaded by Claude Code every session. | Edit only when invariants change. |

**Session-start ritual.** Open the project and say:

> *Read CLAUDE.md, docs/PLAN.md, docs/STATUS.md, docs/TODO.md. Tell me what's next and propose the first concrete change.*

This can be wrapped as `/continue-build` via `.claude/commands/continue-build.md` so it's one keystroke.

**Session-end ritual.**

1. Commit work-in-progress on a phase branch.
2. Tick completed boxes in `docs/TODO.md`.
3. Append a new entry to `docs/STATUS.md` (date, what was done, what's next, gotchas).

**Branching.** One feature branch per build-order phase (e.g., `phase-1-math`, `phase-2-construction-core`). Merge to `main` once the phase's tests are green and `flutter analyze` is clean.

**Anti-patterns to avoid.**
- Letting a session run too long — context quality degrades. End at a clean checkpoint and start fresh.
- Skipping the STATUS entry. The 30 seconds saved cost 10 minutes next session.
- Treating in-session memory as durable. Anything important must land in one of the four files above.

## Verification

End-to-end manual + automated checks once implementation lands:

- `flutter pub get && dart run build_runner build` succeeds.
- `flutter analyze` clean.
- `flutter test` green, including goldens.
- `flutter run -d chrome` — build a non-trivial construction (triangle + circumcircle + orthocenter + perpendicular from one vertex), drag a vertex, confirm everything updates smoothly.
- `flutter build apk` and `flutter build ios` succeed (build only — actual device run optional unless requested).
- Save the construction to JSON, clear, load it, confirm identical render.
- Toggle theme, confirm colors swap and persist across restarts.
- Undo a chain of operations including a drag, then redo — final state matches.
