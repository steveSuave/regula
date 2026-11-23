# Plan: regula2 becomes regula again

Written 2026-11-23 from [spec](spec.md) · Status: awaiting approval · Branch: `intent-002-fold-into-regula`

## Files that change

| File | Change |
|---|---|
| `.github/workflows/deploy.yml` | `--base-href "/regula/"`, drop the stale comment |
| `README.md`, `CLAUDE.md` | name, `origin`, live URL |
| `docs/DECISIONS.md` | lines 24, 637, 820, 861 |
| `benchmark/comparator/README.md`, `run_newclid.py`; `test/corpus/newclid_translation.dart` | comments and placeholders |
| `intent/README.md`, this folder | status |
| Outside the tree | GitHub settings, a scratchpad clone for the redirect, the local directory, the memory folder |

## Order of work

1. **Baseline.** `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`; record counts here.
2. **Rename in the tree.** One commit for `deploy.yml`, one for the docs and comments. `grep -rIn regula2` lists only the allowed exclusions. No behaviour changes; the gate is re-run.
3. **Merge to `regula2` `main`** and push, so that `regula2` stays deployable until the end. Its site rebuilds with base `/regula/`, which breaks it. That is accepted: step 8 replaces it, and the window is short. If a longer window is wanted, skip this step and merge only after the push in 5.
4. **Re-verify nothing is lost.** `regula` `main` is still `7ef44db`, an ancestor of `main`, and every remote branch of `regula` is in `main`. Secrets scan of the full history.
5. **Push to `regula`.** `git remote set-url origin git@github.com:steveSuave/regula.git`, `git push origin main --tags`. A non-fast-forward result stops the work.
6. **Prove the site.** `gh run list` shows `ci.yml`, `benchmarks.yml`, `deploy.yml` green. Load https://stevesuave.github.io/regula/ in Chrome: the app starts and a saved V1 fixture opens. Service-worker check from the spec.
6a. **Rewrite the emails** (added 2026-11-23, user's decision). Bundle the current state to `~/Code/var/regula-before-rewrite.bundle`. In a scratchpad clone, `git filter-branch --env-filter` maps both author and committer emails (`stefanos.levantis@agileactors.com`, `git-ai@local`) to the Gmail address, names kept, for `main`; recreate the annotated tags `v0.1` and `v0.2` with the Gmail tagger, original messages and dates; `v1-final` follows its commit. Verify: every commit's tree equals its original's, no old email remains in commits or tags, `git rev-list --count` unchanged. Then `git push --force-with-lease` of `main` and the tags, wait for the three workflows again, and `git reset --hard` the working checkout onto the new `main`.
7. **Make `regula` public.** Ask the user first, after 6a.
8. **Redirect.** In a scratchpad clone of `regula2`: stub commit per the spec, pushed to `regula2` `main`. Check `/regula2/` and a deep link such as `/regula2/?x=1#y` land on `/regula/` with query and hash.
9. **Archive `regula2`.** Ask the user first. `gh repo archive`. The Pages site keeps serving.
10. **Local cleanup.** Confirm the old `~/Code/var/regula` is still clean, delete it, move `regula2` to `regula`, copy the memory folder to its new key and fix paths, check `git remote -v`.
11. **Close.** Progress and gotchas here, status row in `intent/README.md`, one commit pushed to `regula`.

## Risks

- **The site breaks between 3 and 8.** Mitigated by ordering; `regula2` is the archived repo anyway.
- **Pages environment rules on `regula`.** Seen in step 6.
- **A visitor stuck on V1's service worker.** The fallback is in the spec.
- **Making public leaks something.** The scan in step 4, and the confirmation in step 7.

## Proof

- Step 1 and step 2 gate counts are equal.
- `git merge-base --is-ancestor 7ef44db origin/main` on `regula` before the push; the push reports a fast-forward.
- Three green workflows on `regula`.
- The live site starts and opens a V1 `.rgl`; `/regula2/` redirects with query and hash.
- `gh repo view steveSuave/regula2 --json isArchived` is true.

## Progress and gotchas

Not started.
