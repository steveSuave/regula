# Spec: the geometry menu's Prover item opens the prover

Written 2026-11-24 from [intent](intent.md) · Status: done with the plan (express)

## Requirements

1. On is the panel open. Wide: the docked `ProofPanel` is built exactly while `experimentalProverProvider` is true. Phone: turning it on opens the sheet.
2. The Proof `IconButton` and `_showProofPanel` are removed from `lib/main.dart`.
3. Phone: dismissing the sheet sets the flag off, unless a question draft is open (the panel pops the sheet itself to let the figure be tapped). When the draft goes to null with the flag on and no sheet up (asked, or the builder closed), the sheet reopens. `QuestionBuilderBar.onAsked` is no longer passed by the editor; the draft listener replaces it.
4. **Not stored.** The flag becomes session state (`build() => false`, no `shared_preferences`). A stored "on" would reopen on a phone as a prover with no sheet; on wide it would reopen a panel at every load. This reverses intent 003's "one persisted setting", by the user's redefinition of the toggle as the panel itself.
5. DECISIONS' section is rewritten as §"The prover is an experimental toggle in the geometry menu"; README says the item shows the panel.

## Intent constraints → how each is met

| Constraint | How |
|---|---|
| Teardown, default-off, domain untouched | Provider teardown unchanged and still tested mid-run; `prover_flag_test` default-off at both sizes; no file under `lib/domain/prover` changes |
| Phone question building | `prover_flag_test` "steps aside … comes back when the builder is closed"; `question_builder_bar_test` "reopens with the answer", which now runs through the draft listener |

## Areas of concern

- A window resized from wide to compact while the prover is on loses the docked panel without opening a sheet; the globe still shows Prover checked, and unchecking then checking opens the sheet. Not handled.
- `proof_panel_test`'s "panel close clears the highlight" now closes through the toggle, whose teardown clears the highlight before the panel's own dispose path would. The dispose path is no longer the thing that test proves.
