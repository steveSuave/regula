# Spec: the prover is an experimental feature, off by default

Written 2026-11-23 from [intent](intent.md) · Status: drafted, awaiting plan approval

## Requirements

1. A persisted device preference, `experimentalProverProvider` (a `bool`, default `false`), stored under the `shared_preferences` key `experimental.prover` beside `themeMode`.
2. With the setting off, the editor builds no Proof button, docked proof panel, proof sheet or question builder bar, on wide and phone layouts.
3. The view menu (the axes & grid popup) ends with a divider, a non-selectable "Experimental" header and a checked item "Prover" that flips the setting. Its tooltip changes from "Axes & grid" to "View", since the menu now holds more than axes and grid.
4. Turning the setting off stops any run in flight and drops its result, closes the question draft (which ends the `draftCheck` probe), clears the proof highlight, and closes the docked panel. Turning it back on shows the Proof button and nothing else: the panel stays closed until it is asked for.
5. With the setting on, the prover behaves exactly as today. Every existing prover widget test passes with the setting on and no other change to what it asserts.
6. `lib/domain/prover/` is not touched, and its tests keep running in CI.
7. `README.md` calls the prover experimental and says where to turn it on.
8. A test pins default-off: a fresh editor, wide and phone, shows no Proof button, panel, builder bar or highlight.

## Design

### The preference

`lib/application/providers/experimental_prover_provider.dart`, shaped like `ThemeModeNotifier`: `build()` reads `sharedPreferencesProvider.getBool('experimental.prover') ?? false`; `set(bool)` writes state, then persists fire-and-forget (`remove` on `false`, so a fresh device and an opted-out one store the same thing).

On `set(false)` the notifier itself tears down prover state, so every caller (menu, test, any future route) gets the same teardown:

- `proverProvider.notifier.stop()` then `.clear()`. `clear()` bumps `_generation`, and every run method (`prove`, `proveMore`, `ask`, `askMore`, `searchForPoint`) checks `generation != _generation` before publishing, so a stopped run halts at its next pass boundary and its result is dropped. Without the `clear()`, `stop()` alone would publish a partial `ProverReady`.
- `questionDraftProvider.notifier.close()`.
- `proofHighlightProvider.notifier.clear()`.

Dependencies stay one-way: the preference notifier reads the prover providers, and they never read it. `prover_provider`, `question_draft_provider` and `proof_highlight_provider` are unchanged.

### The editor (`lib/main.dart`)

- `build` watches `experimentalProverProvider` once as `proverOn`.
- The Proof `IconButton` is built only when `proverOn`.
- The docked `ProofPanel` is built only when `proverOn && !compactPanels && _showProofPanel`, and the `QuestionBuilderBar` only when `proverOn && buildingQuestion`. The second condition is redundant after requirement 4's teardown, but it makes "off shows nothing" true by construction rather than by sequencing.
- A `ref.listen` on the preference sets `_showProofPanel = false` when it goes off, so re-enabling does not reopen a panel the user never asked for.
- The phone's proof sheet is modal. While it is open its scrim covers the app bar, so the toggle cannot be reached; nothing is needed for an open sheet.
- `_gridMenu()` gains the Experimental section. The header is a `PopupMenuItem(enabled: false)` in the theme's `labelSmall`. The "Prover" row is a `CheckedPopupMenuItem` with no shortcut display.

### Not changed, and why

- `lib/presentation/canvas/geometry_canvas.dart`, named in the intent. Its highlight read is empty once the teardown has run, and its question-builder tap is already gated on a non-null draft, which the teardown closes and nothing outside the panel opens. Gating it too would add a second place that knows about the flag.
- File > New and Open keep calling `proverProvider.notifier.clear()`. With the setting off that clears an idle notifier, which is harmless.
- The save format and `DocumentSettings`: the setting belongs to the device.

### Tests: the shared-preferences override

16 widget tests mount `EditorScreen` on a bare `ProviderContainer()`. Once the editor watches a preference, `sharedPreferencesProvider` throws for them by design ("Unoverridden access throws"). A helper `test/editor_container.dart` gives `Future<ProviderContainer> editorContainer({bool prover = false, List<Override> overrides = const []})`. It mocks empty preferences (with `experimental.prover: true` when asked), overrides the provider and registers disposal. The 16 tests move onto it in a commit of their own, before any behaviour change. The two prover widget tests (`proof_panel_test`, `question_builder_bar_test`) pass `prover: true`.

The 16, under `test/presentation/`: `export_flow`, `delete_tool_flow`, `text_tool_flow`, `hide_tool_flow`, `grid_menu`, `file_menu`, `name_points_flow`, `app_bar_layout`, `panels/toolbar`, `panels/object_tree_panel`, `panels/attributes_inspector`, `panels/question_builder_bar`, `panels/proof_panel`, `canvas/geometry_canvas`, `canvas/grid_snap_flow`, `shortcuts/cheat_sheet` (each `_test.dart`). `geometry_menu_test` and `editor_shortcuts_test` already override and move onto the helper only if it shortens them.

### DECISIONS

A new subsection under §"M-P": **"The prover is behind a device preference (intent 003)"**. It covers the runtime preference rather than a define, why the teardown lives in the preference's notifier, the one-way dependency, and the rule that an experimental surface is gated at the editor with its domain untouched. The Map's Prover bullet gains the citation. This is the decision intent 004 can reuse for its own staged surfaces.

## Intent constraints → how each is met

| Constraint | How |
|---|---|
| `lib/domain/prover/` unchanged, tests in CI | Requirement 6; no file under it is in the plan's file list |
| Saved documents unaffected; a device preference | `shared_preferences`, not `DocumentSettings`; no codec change |
| Default-off pinned by a test | Requirement 8, wide and phone |
| Off mid-run stops the run, clears draft and highlight | The notifier teardown; a provider test with a run in flight, and a widget test through the menu |
| Same on wide and phone | The gate is one boolean shared by both branches; the default-off and toggle-on tests run at both sizes |
| A runtime setting, not a define | Requirement 1 |
| With the setting on, works exactly as today | Requirement 5: the existing prover widget tests are the evidence |

## Open questions carried over

None. The four in the intent are answered there.

## Areas of concern

- **Test migration breadth.** 16 files change for a mechanical reason. Kept in its own commit, with equal pass counts before and after.
- **A run's last chunk.** `stop()` takes effect at the next pass boundary, up to one chunk later (DECISIONS §"M-P" measures a chunk at up to 2.3 s). The teardown does not wait. The result is dropped by generation, and the UI is already gone, so nothing shows. The CPU finishes that chunk regardless, as it does today for a superseded run.
- **The narrow-window proof sheet look (parked old Phase 154)** is folded into this intent's proof. It needs Chrome out of macOS fullscreen, and the extension connected.
