# Intent: the geometry menu's Prover item opens the prover, with no Proof button

Author: SLevantis, drafted with Claude · Status: accepted 2026-11-24 (express) · 2026-11-24

## Problem

After intent 006, checking "Prover" in the geometry menu only adds a Proof icon to the app bar, which is easy to lose, and the panel then needs a second click. The user wants to toggle the prover from inside the globe, at least until the prover is revisited.

## Proposed outcome

- "Prover" in the geometry menu opens the prover's panel (docked where there is room, the sheet on a phone); unchecking closes it and tears the prover down as before.
- No Proof button in the app bar.

## Constraints

- Intent 003's teardown, default-off, and domain-untouched constraints hold.
- On a phone, building a question still works: the sheet steps aside while the figure is tapped and comes back.
