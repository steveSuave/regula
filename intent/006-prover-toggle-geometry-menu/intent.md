# Intent: the prover toggle moves to the geometry menu

Author: SLevantis, drafted with Claude · Status: accepted 2026-11-23 (express: the user asked for it to be done promptly) · 2026-11-23

## Problem

Intent 003 put "Experimental → Prover" at the bottom of the grid menu. The user finds it out of place there: everything else in that menu is a per-document view setting, and the tooltip had to change to "View" to admit it.

## Proposed outcome

- The Experimental section, with its one "Prover" row, sits at the bottom of the geometry menu (the globe). The prover has a link to that menu: it speaks only in Euclidean geometry, and the Proof button already sits beside the globe.
- The grid menu is back to what it was: three rows, tooltip "Axes & grid".
- Behaviour is otherwise unchanged from intent 003: same preference, same teardown, off by default.

## Constraints

- Intent 003's constraints all still hold; its tests move with the toggle rather than being weakened.
- README and DECISIONS name the new place.
