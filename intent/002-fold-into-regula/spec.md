# Spec: regula2 becomes regula again

Written 2026-11-23 from [intent](intent.md) · Status: drafted, awaiting plan approval

## Requirements

1. `steveSuave/regula` `main` is this repo's `main` by fast-forward, with tags `v0.1`, `v0.2` and `v1-final`. No force push, no repo rename. No phase branches are pushed.
2. `deploy.yml` builds with `--base-href "/regula/"`, and https://stevesuave.github.io/regula/ serves the current app, with all three workflows green on `regula`.
3. "regula2" is gone from the product, `README.md`, `CLAUDE.md`, `docs/DECISIONS.md`, `benchmark/` and `test/corpus/`. It stays in `docs/archive/`, in the intent history (`intent/001`, `002`, `005`), and wherever it names the old repository on purpose.
4. `regula` is public. Confirmed with the user at that moment.
5. https://stevesuave.github.io/regula2/ and any deep link under it redirect to the same path under `/regula/`, keeping query and hash. Then `regula2` is archived. Confirmed with the user at that moment.
6. The local checkout is `~/Code/var/regula` with `origin` at `steveSuave/regula`. The old local `regula` checkout is deleted after verification.
7. A returning visitor of the old V1 site gets the new build.

## Design

### What is already true (re-verified 2026-11-23)

- `regula` `main` is `7ef44db` = tag `v1-final` here, an ancestor of this `main`. So the push is a fast-forward.
- All 79 remote branches of `regula` are contained in this `main`.
- `regula` has Pages configured with source "workflow", so `deploy.yml` can publish there once pushed. It is currently private.
- The old local `regula` checkout is clean, with no stashes.

### Order

The site must be proven at `/regula/` before `regula2` is touched. So: rename in the tree (on a branch, merged into `regula2` `main` first), repoint `origin`, push, watch the three workflows, check the live site, then make public, then do the redirect, then archive, then clean up locally.

### The tree rename

- `deploy.yml`: `--base-href "/regula/"`, and drop the stale "Replace YOUR_REPOS_NAME" comment.
- Live docs: `README.md` (title and live URL), `CLAUDE.md` (title, `origin`, URL), `docs/DECISIONS.md` lines 24, 637, 820 and 861, `benchmark/comparator/` and `test/corpus/newclid_translation.dart`.
- DECISIONS line 24 says "regula2 is the V2 of regula". It becomes a sentence saying the app was developed as `regula2` and folded back into `regula` on 2026-11-23. Line 861 (package rename) becomes moot, since the package is `regula`. Line 820 is rewritten for the new origin and URL.
- Comments in `benchmark/comparator/` and the corpus translation say "regula2's parser" and mean this app. They become "regula's". The `<regula2>` path placeholders become `<regula>`.
- Not touched: `docs/archive/`, `ios/Flutter/*` (generated, untracked; check they are ignored), and the history text in `intent/`.
- The project memory folder is keyed by directory path. After the checkout is moved it is `-Users-stefanos-levantis-Code-var-regula`. The memory files are copied there, and `reference-provers-and-corpus` is re-read for `regula2` paths.

### The redirect

Pages on `regula2` is built by a workflow. The redirect ships as one more commit on `regula2` `main`, made in a throwaway clone and never pushed to `regula`: it deletes the tree and adds `index.html` and `404.html`, which run `location.replace("/regula/" + path-after-/regula2/ + search + hash)`, plus a `<meta refresh>` and a link as a fallback, and a `deploy.yml` that uploads only those two files. A plain commit on top, not a force push. `404.html` carries deep links, since Pages serves it for any missing path.

### Service worker

The V1 build was a Flutter web app at the same scope, and Flutter's service worker file is re-fetched and byte-compared by the browser on each load, so the new build replaces it. No code. Verified after deploy by loading a profile that holds the V1 worker, or by registering the V1 worker from a `v1-final` build locally. If a visitor stays on V1, the fix is a `main.dart.js` cache-bust or an unregister snippet in `index.html`, and that becomes its own step.

## Intent constraints → how each is met

| Constraint | How |
|---|---|
| Nothing is lost | Re-verified above and re-run immediately before the push. V1 stays in tag `v1-final`. |
| Tags pushed with `main` | `git push origin main --tags` |
| `/regula/` proven before `regula2` is touched | Plan steps 5 and 6 precede 8 |
| Public and archive confirmed at the moment | Plan steps 7 and 9 each ask |
| History files keep the old name | Requirement 3 exclusions |
| Runs after 001 | 001 is done |

## Open questions carried over

None. A visitor who stays on V1 after the service-worker check is the one risk, handled in the plan.

## Areas of concern

- **Pages environment protection.** `regula`'s `github-pages` environment may restrict deployment branches. It allows `main`, so this is expected to be fine; confirmed by the first run.
- **The public flip.** `regula` goes public with the full history, including `docs/archive/`. A scan for secrets and personal data (`gitleaks`-style grep for keys, tokens, emails) runs before step 7.
- **`origin` repoint.** The scratchpad clone for the redirect uses its own remote, so the working checkout's `origin` is never pointing at the archived repo while it still matters.
