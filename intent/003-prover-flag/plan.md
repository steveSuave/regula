# Plan: the prover is an experimental feature, off by default

Written 2026-11-23 from [spec](spec.md) · Status: done 2026-11-23 · Branch: `intent-003-prover-flag`

## Files that change

| File | Change |
|---|---|
| `test/editor_container.dart` | new helper: an overridden-preferences container, optionally with the prover on |
| 16 widget tests mounting `EditorScreen` on a bare container | move onto the helper (list in the spec) |
| `lib/application/providers/experimental_prover_provider.dart` (+ `.g.dart`) | new preference notifier with the off-teardown |
| `test/application/providers/experimental_prover_provider_test.dart` | new |
| `lib/main.dart` | gate the Proof button, docked panel and builder bar; the reset listener; the Experimental section; tooltip "View" |
| `test/presentation/prover_flag_test.dart` | new widget tests: default off, toggle on, off mid-run |
| `test/presentation/panels/proof_panel_test.dart`, `question_builder_bar_test.dart` | `prover: true` |
| `docs/DECISIONS.md` | new §"The prover is behind a device preference", Map citation |
| `README.md` | the prover line says experimental, and where the switch is |
| `intent/README.md`, this folder | status, progress |

## Order of work

1. **Baseline.** `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`; record pass counts here.
2. **Test helper and migration** (one commit, no behaviour change). Add `editorContainer`; move the 16 bare tests onto it. The gate passes with the same counts as step 1.
3. **The preference** (one commit). Notifier, `build_runner`, provider tests:
   - default `false` on empty preferences; reads a stored `true`;
   - `set(true)` persists, `set(false)` removes the key;
   - `set(false)` with a `prove()` in flight: the awaited run completes with `proverProvider` at `ProverIdle`, not `ProverReady`;
   - `set(false)` closes an open draft and empties a highlight.
4. **The editor gate, the menu toggle, DECISIONS** (one commit). `main.dart` changes; the two prover widget tests pass `prover: true`; `prover_flag_test.dart`:
   - fresh editor, wide and phone: no `Proof` tooltip or `fact_check_outlined` icon, no `ProofPanel`, no `QuestionBuilderBar`, an empty highlight;
   - View menu → Experimental → Prover: the Proof button appears, the panel stays closed, the preference is stored;
   - on, panel open, a question being built, a highlight shown → toggle off: button, panel and bar are gone, the draft is null, the highlight is empty, and the prover is idle; toggle on again: the panel is still closed.
5. **README** (one commit).
6. **Browser check.** Ask the user before using Chrome, and check `tabs_context_mcp` first. `flutter run -d chrome`, with the window narrowed out of macOS fullscreen: fresh profile shows no Proof button; turn it on from View; open the proof sheet, run a proof, drag the sheet between its min and max (old Phase 154's look); turn it off.
7. **Close and ship.** Progress and gotchas here, status row in `intent/README.md`, merge to `main` and push; `gh run list` for CI, Benchmarks, Deploy; check the deployed app shows no Proof button on a fresh profile.

## Risks

- **A prover widget test that assumed the panel was reachable without a flag** fails in step 4 for the wrong reason. The `prover: true` switch is the fix; anything beyond it is a departure, noted here.
- **`ref.listen` in `build` firing during the teardown's own rebuild.** The listener only calls `setState` on a value that is already being hidden, so it is safe; a failing test here means the listen moves to `initState` via `ref.listenManual`.
- **Goldens.** The app-bar row loses a button; any golden of the full app bar changes. The goldens are tagged and excluded in CI; regenerate on macOS if one covers the bar.

## Proof

- Step 2's gate counts equal step 1's.
- Step 3 and 4 tests, green in `flutter test`; the full CI gate green.
- `git diff main --stat -- lib/domain/prover test/domain/prover` is empty.
- Step 6's look in Chrome, and the deployed app after step 7.

## Progress and gotchas

**Done 2026-11-23**, all seven steps in one session.

- **Step 1, baseline.** VM 3555 passed; browser 15 passed; analyze clean. The first baseline ran in the background against the working tree while step 2's edits were landing, so its analyze line was polluted by a half-written helper. The counts were re-taken from a clean worktree at `main` (`test/presentation` 681 there, and 681 after the move). Gotcha: take a baseline from a worktree, never from the tree being edited.
- **Step 2** (`fec482a`). The helper is `editorContainer()`. An `overrides` parameter was written and dropped: nothing needed it, and Riverpod 3 does not export `Override` from `flutter_riverpod.dart`.
- **Step 3** (`a38692b`). Five provider tests. Mutation check: without `clear()` in the teardown, the mid-run test fails with `ProverReady(facts: 44, applications: 500, reachedFixpoint: false)`. That partial result is exactly what the teardown drops.
- **Step 4** (`3591afb`). Five widget tests in `prover_flag_test.dart` (default off and toggle on, each at wide and phone; off with everything open). Departure: `grid_menu_test` expected three checked items and now expects four; it was not in the plan's file list. Gotcha: `pumpAndSettle` never settles while a proof step is highlighted, because the canvas pulses it; the test pumps a fixed duration then. Mutation checks: removing the panel-reset listener breaks the "on again leaves the panel closed" test, and removing the button's `if (proverOn)` breaks the default-off tests. Gate: VM 3565 (+10), browser 15, analyze clean; `lib/domain/prover` and `test/domain/prover` untouched.
- **Step 5** (`f156e18`). README.
- **Step 6, Chrome** (release wasm build served on 127.0.0.1, window 500×757, a real window and so compact: `innerWidth` 500, `screenX` 56). Fresh origin, no `flutter.*` keys: no Proof button between the globe and the keyboard. The View menu shows the divider, "Experimental", and "Prover" unchecked; checking it adds the button and no panel, and stores `flutter.experimental.prover`. The sheet opens at half height over the canvas, ▶ runs and answers. After a reload the setting holds; unchecking removes the key and the button.
- **Old Phase 154's look, partly.** With a mouse the sheet cannot be resized at all: neither a drag (Flutter web leaves the mouse out of scrollables' drag devices) nor the wheel (the empty state has nothing to scroll) moves it off its initial half. That is the sheet as it already was on `main`, not this intent; touch resizing is pinned by `proof_panel_test`'s "on a phone" group. A desktop user in a narrow window gets the half-height sheet only. Recorded under Parked rather than fixed here.
