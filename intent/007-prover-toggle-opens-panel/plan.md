# Plan: the geometry menu's Prover item opens the prover

Written 2026-11-24 from [spec](spec.md) · Status: done 2026-11-24 · Branch: `intent-007-prover-toggle-opens-panel`

## Files that change

`lib/main.dart`, `lib/application/providers/experimental_prover_provider.dart` (+ `.g.dart`), `test/editor_container.dart`, `test/application/providers/experimental_prover_provider_test.dart`, `test/presentation/prover_flag_test.dart`, `test/presentation/panels/proof_panel_test.dart`, `test/presentation/panels/question_builder_bar_test.dart`, `docs/DECISIONS.md`, `README.md`, `intent/README.md`, this folder.

## Order of work

1. One commit: the behaviour, its tests, DECISIONS, README. Full gate.
2. Merge to `main`, push, workflows green, the live menu looked at.

## Progress and gotchas

- Step 1: the prover widget tests open the panel through the flag (the same call the menu item makes) instead of tapping the Proof button. Mutation checks: without the sheet's off-on-dismiss, "dismissing the sheet turns the prover off" fails; without the draft listener's reopen, both phone question tests fail.
- Gate: VM 3566 (the provider test lost its two storage cases for one toggle case; `prover_flag_test` gained two phone cases), browser 15, analyze clean.
- Step 2: merged as `d2e6730`; CI, Benchmarks and Deploy green. Live, at full width: the globe's Prover item docks the panel with no icon added, and unchecking it closes the panel. The phone sheet was not driven live; its behaviour rests on the widget tests.
