# Status Log

Append-only journal of working sessions. Newest entries on top. Each entry should answer three questions in 5–15 lines: **what was done**, **what's next**, **gotchas / open questions**.

Write a fresh entry at the end of every session, before stopping. Do not edit older entries — if something turned out wrong, note it in the next entry.

---

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
