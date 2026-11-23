# Intent: regula2 becomes regula again

Author: SLevantis, drafted with Claude · Status: done 2026-11-23 · 2026-11-17

## Problem

The app was forked into a second repository, `steveSuave/regula2`, when the V2 kernel work started. The "2" was never meant to be part of the name, and the original `steveSuave/regula` still serves the old V1 build at https://stevesuave.github.io/regula/. There are now two repos and two live sites for one app.

## Proposed outcome

- `steveSuave/regula` holds the current code, as a continuation of its own history, and https://stevesuave.github.io/regula/ serves the current app.
- The name "regula2" is gone from the product, the README, `CLAUDE.md` and the live docs.
- `steveSuave/regula2` is archived, and its Pages site redirects to the new URL.
- The local checkout is the directory `regula`, with `origin` pointing at `steveSuave/regula`.

## Decisions already made (2026-11-16)

- Fast-forward push into `regula`; no force push, no repo rename. **Amended 2026-11-23:** before `regula` goes public, its history is rewritten to replace the author emails (see Resolved questions), and that is pushed with one `--force-with-lease`. The fast-forward push already happened, and `regula` was private throughout.
- `regula` becomes public.
- `regula2` is archived with a redirect, not deleted.
- The V1 app does not stay live. It remains recoverable from tag `v1-final`.

## Affected users and systems

- Anyone with the old `/regula2/` link or bookmark (gets a redirect).
- Anyone using the V1 site at `/regula/` (gets V2; V1 documents open in it).
- GitHub: both repos, their Pages settings, the three workflows (`ci.yml`, `benchmarks.yml`, `deploy.yml`).
- In the tree: the `--base-href "/regula2/"` in `.github/workflows/deploy.yml`, and 44 mentions of "regula2" across 16 files (README, `CLAUDE.md`, docs, `benchmark/comparator/`, `test/corpus/newclid_translation.dart`).
- Local: the two checkouts under `~/Code/var/`, and Claude's per-project memory folder, which is keyed by the directory path.

## Constraints

- Nothing is lost. Verified on 2026-11-16, re-verify before pushing:
  - `regula`'s `main` is commit `7ef44db`, the same commit as tag `v1-final` here, and an ancestor of this repo's `main`.
  - All 78 remote branches of `regula` are contained in this repo's `main`.
  - `regula` has no issues, pull requests, releases or Actions secrets.
  - The local `regula` checkout is clean, with no stashes and no unpushed branches.
- Tags `v0.2` and `v1-final` are pushed with `main`.
- The site at `/regula/` is confirmed to serve the new build, with all three workflows green, before `regula2` is touched.
- Making a repo public and archiving one are outward-facing: each is confirmed with the user at the moment it is done.
- History files (`docs/archive/`, old status entries) keep the old name.
- Runs after intent 001, so the renamed docs are the restructured ones.

## Resolved questions (2026-11-23)

- **Branches:** only `main` and tags are pushed. Every phase branch is merged, so its commits are reachable from `main`, and the merge commits keep the history browsable. Pushing 34 merged branches would be cheap but would clutter `regula`'s branch list (user's call, delegated to Claude). If an old state is wanted later, tag the commit then.
- **Old local checkout:** deleted once the push is verified and the checkout is re-confirmed clean, with no stashes and no unpushed branches. Tag `v1-final` and `regula`'s own history keep V1 recoverable.
- **Service worker (delegated, decided):** no code. The new build is served from the same `/regula/` scope, so the browser's byte-check of the service worker file replaces the old worker on the next visit. The plan includes a post-deploy check that a returning visitor gets the new build; it becomes work only if that check fails.
- **Deep-link redirect (delegated, decided):** yes. `regula2`'s Pages site gets a small `404.html` plus `index.html` that redirect to the same path under `/regula/`, keeping query and hash. It is a few lines and costs nothing.

- **Emails (2026-11-23):** the history carries a work address (989 commits, the `v0.1` and `v0.2` tags) and a local placeholder `git-ai@local` (844 commits). Before going public, both emails are rewritten to the personal Gmail address already on one commit; names are kept. The rewrite touches only identities. The tree of every commit stays byte-identical, which is checked. All SHAs change, including `7ef44db`, so tag `v1-final` moves to its rewritten commit. A bundle of the pre-rewrite state is kept outside the repo.

## Open questions

None.
