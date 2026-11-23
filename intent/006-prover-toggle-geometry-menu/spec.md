# Spec: the prover toggle moves to the geometry menu

Written 2026-11-23 from [intent](intent.md) · Status: done with the plan (express)

## Requirements

1. `GeometryMenu` ends with a divider, a non-selectable "Experimental" header, and a `CheckedPopupMenuItem` "Prover" in the menu's two-line row style, subtitled with what the prover is and that it speaks only Euclidean. It flips `experimentalProverProvider`.
2. `_gridMenu()` in `lib/main.dart` returns to its pre-003 form: tooltip "Axes & grid", three rows, original doc comment.
3. `prover_flag_test.dart` toggles through the globe; `grid_menu_test.dart` expects three checked items again.
4. README, DECISIONS §"The prover is behind a device preference" and `experimental_prover_provider.dart`'s doc comment say "the geometry menu".

## Intent constraints → how each is met

| Constraint | How |
|---|---|
| Intent 003's constraints hold | No change to the provider or the editor's gate; `prover_flag_test` keeps every assertion and only changes which menu it opens |
| README and DECISIONS name the new place | Requirement 4 |

## Areas of concern

- The geometry menu's items switch the document's geometry through an undoable command; the Prover row is a device preference. The "Experimental" header and divider set it apart, as in intent 003.
