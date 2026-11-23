# Intent: the prover is an experimental feature, off by default

Author: SLevantis, drafted with Claude · Status: accepted 2026-11-23 · 2026-11-17

## Problem

The deductive prover is always present in the interface: a Proof button in the toolbar, the proof panel (a bottom sheet on a phone), the question builder bar, and proof highlighting on the canvas. The app's focus is moving to stereometry, where the prover does nothing (it is planar), and it is not finished enough to be part of the default experience.

## Proposed outcome

- A new user sees no trace of the prover anywhere in the interface.
- One persisted setting, "Experimental: prover", off by default, switches it on in the same build, with no rebuild or special URL.
- With the setting off, no prover run starts and no prover state is kept.
- With the setting on, the prover works exactly as it does today.

## Decision already made (2026-11-16)

- A runtime setting stored with the other preferences, not a build-time define.

## Affected users and systems

- Every user of the deployed app (the Proof button disappears until they opt in).
- `lib/main.dart`: the Proof toolbar button (line 1193), the side panel (1685), the proof sheet (`_openProofSheet`, 1527), the question builder bar (1662), the view menu that will hold the toggle (1470).
- `lib/presentation/canvas/geometry_canvas.dart`: proof highlighting (184) and the tap that feeds the question builder (819).
- `lib/application/providers/`: a new preference beside `preferences_provider.dart`; `prover_provider`, `question_draft_provider` and `proof_highlight_provider` are cleared when the setting goes off.
- Existing prover widget tests, which must switch the setting on.

## Constraints

- `lib/domain/prover/` is not changed, moved or deleted, and its tests keep running in CI.
- Saved documents are unaffected; the setting is a preference of the device, not of the document.
- Default-off is pinned by a test: a fresh app shows no Proof button, panel, builder bar or highlight.
- Turning the setting off mid-run stops the run and clears the draft and highlight.
- Works the same on wide and phone layouts.

## Open questions (answered 2026-11-23, at acceptance)

- **Anything prover-related running without the panel?** Only `draftCheck` (`question_draft_provider.dart`), the numeric probe that re-checks a complete question on every construction change, drag frames included. It runs only while a question draft exists, and a draft is opened only from the proof panel. Clearing the draft when the setting goes off, and never building the panel while it is off, gates it.
- **Keyboard shortcuts or cheat-sheet entries?** None. `AppAction` has no prover action and the cheat sheet lists none.
- **README and repo description.** `README.md:87` advertises the prover without calling it experimental; it is reworded. The GitHub description ("A flutter geometry app") does not mention it.
- **Where the toggle lives.** In an "Experimental" section of the existing view menu (the axes & grid popup), the user's choice.
