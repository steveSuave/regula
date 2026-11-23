# Plan: the prover toggle moves to the geometry menu

Written 2026-11-23 from [spec](spec.md) · Status: done 2026-11-24 · Branch: `intent-006-prover-toggle-geometry-menu`

## Files that change

`lib/presentation/panels/geometry_menu.dart`, `lib/main.dart`, `lib/application/providers/experimental_prover_provider.dart` (doc comment), `test/presentation/prover_flag_test.dart`, `test/presentation/grid_menu_test.dart`, `docs/DECISIONS.md`, `README.md`, `intent/README.md`, this folder.

## Order of work

1. One commit: the move, its tests, DECISIONS and README. Full gate (analyze, VM, browser).
2. Merge to `main`, push, workflows green, the live menu looked at.

## Proof

The gate green with the same counts as intent 003's close (VM 3565, browser 15), and the toggle seen in the globe menu on the live site.

## Progress and gotchas

**Done 2026-11-24** (started 2026-11-23).

- Step 1: gate VM 3565, browser 15, analyze clean, the same counts as intent 003's close. `_gridMenu` was restored verbatim from `62ad89d`, before intent 003, rather than edited back. Gotcha: a scripted edit written against pre-format text missed `main.dart` after `dart format` had reflowed the block; matching formatted text, or restoring from git, is the way.
- The Prover row uses the geometry menu's two-line row (title and subtitle), not the grid menu's `ToolMenuRow`.
