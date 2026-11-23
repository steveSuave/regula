# Intents

One folder per change, following Anthropic's AI-native SDLC playbook: `intent.md` (what is asked for), then `spec.md` (what was decided), then `plan.md` (how it is built and proved, and how far it has got). The user accepts an intent before its spec is written, and approves a plan before code.

| # | Intent | Status | Depends on |
|---|---|---|---|
| 001 | [Docs follow the intent → spec → plan method](001-docs-method/intent.md) | done 2026-11-23; [spec](001-docs-method/spec.md), [plan](001-docs-method/plan.md) | — |
| 002 | [regula2 becomes regula again](002-fold-into-regula/intent.md) | done 2026-11-23; [spec](002-fold-into-regula/spec.md), [plan](002-fold-into-regula/plan.md) | 001 |
| 003 | [Prover is experimental, off by default](003-prover-flag/intent.md) | done 2026-11-23 (toggle moved by 006); [spec](003-prover-flag/spec.md), [plan](003-prover-flag/plan.md) | 002 (so it ships to the final URL) |
| 004 | [Stereometry](004-stereometry/intent.md) | draft, awaiting review | 001; after 003 |
| 005 | [CI is green again on Flutter stable](005-toolchain-3-50/intent.md) | part 1 done (workflows pinned to Flutter 3.47.2); part 2 (upgrade to Flutter 3.50 and `material_ui`): done and merged 2026-11-23 (Flutter 3.50.1, `material_ui`); [spec](005-toolchain-3-50/spec.md), [plan](005-toolchain-3-50/plan.md) | — |
| 006 | [The prover toggle moves to the geometry menu](006-prover-toggle-geometry-menu/intent.md) | done 2026-11-24 (express); [spec](006-prover-toggle-geometry-menu/spec.md), [plan](006-prover-toggle-geometry-menu/plan.md) | 003 |
| 007 | [The geometry menu's Prover item opens the prover](007-prover-toggle-opens-panel/intent.md) | done 2026-11-24 (express); [spec](007-prover-toggle-opens-panel/spec.md), [plan](007-prover-toggle-opens-panel/plan.md) | 006 |

## Where the next session starts

**Intent 004**: a draft; the user reviews it, then spec and plan, then code.

## Parked

Open items from the old checklist that are not intents yet. Each becomes an intent when its trigger fires, and not before.

| Item | Trigger |
|---|---|
| Android emulator smoke; iOS simulator smoke and `flutter build ios` | Intent 004's first milestone, which requires a phone. Needs an AVD with a system image, and a complete Xcode install with CocoaPods |
| The Newclid comparison (old Phase 176) | Newclid ships past 3.0.1, or fixes either crash class (`LengthEquationPredicate is not implemented`; the pydantic error on degenerate `simtri`). Check with `pip index versions newclid` |
| Prover carries (old Phase 186): `readFact` on a listed `eqangle` can read magnitude-false; the re-glance on old `entails`-based zeros; `regular_hexagon#2`'s quiescence asterisk | The prover comes back out from behind intent 003's flag |
| The proof sheet cannot be resized with a mouse (no drag, no wheel), so a narrow desktop window gets only its initial half; touch works. Found in intent 003's browser look | The prover comes back out from behind intent 003's flag, or a user reports it |

Dropped: hand-written SVG export (a stretch item since V1 Phase 19).

The full text of each item is in `docs/archive/TODO-final.md`.
