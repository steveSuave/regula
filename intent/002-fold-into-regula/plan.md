# Plan: regula2 becomes regula again

Written 2026-11-23 from [spec](spec.md) · Status: done 2026-11-23 · Branch: `intent-002-fold-into-regula`

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

**Done 2026-11-23.** Steps 1–9 ran on 2026-11-23, in a session that did not record them here; the next session (same day) found them on disk and on GitHub, checked what it could, and closed with 10 and 11. Departures and evidence:

- **The plan ran before this file said it was approved.** Its status line stayed "awaiting approval" and this section "Not started" through steps 1–9. The commits and GitHub state are the record: `0fa9dc4` (base-href), `eed4de1` (renames), `7cae636` (6a added to the intent and plan).
- **Steps 1–2 gate counts were not written down.** CI, Benchmarks and Deploy are green on `regula` for both renaming commits and for `7cae636` (runs 45235197025, 45237976316 and siblings). The one non-green run in the last 30 is a cancelled deploy superseded by the next push.
- **Step 6a went ahead.** Every commit on `main` now carries `s.levantes@gmail.com` as author and committer (one merge commit keeps `noreply@github.com` as committer); `v0.1` and `v0.2` carry it as tagger. The pre-rewrite state is `~/Code/var/regula-before-rewrite.bundle` (old `main` `c79d4d5`, `v1-final` `7ef44db`, `v0.1`, `v0.2`). `v1-final` followed its commit: it is now `d0b15c1`, locally and on `origin`, an ancestor of `main` with V1's tree. Hashes quoted elsewhere in this folder and in `docs/archive/` are pre-rewrite; `docs/DECISIONS.md` now gives both.
- **Step 6, the site.** In Chrome: `/regula/` serves `main.dart.wasm` of 2 864 523 bytes, starts, and opens the V1 fixture `test/fixtures/inter2.json` (through the file-input patch). The service-worker check of the spec was **not run** against a profile holding V1's worker; the checking profile had no service worker registered at the origin. No visitor report of a stuck V1 so far.
- **Steps 7–9.** `regula` is public; `regula2` is archived and public, and its Pages site serves the redirect stub (run 45240230147). `/regula2/nope?x=1#y` lands on `/regula/nope?x=1#y`: path, query and hash kept. On `/regula2/?x=1#y` the app itself then rewrites the hash (Flutter's hash URL strategy), so a hash is only meaningful on non-app paths; nothing uses one today.
- **Step 10, local cleanup.** The old V1 checkout `~/Code/var/regula` was clean and at `7ef44db`; every branch tip in it is in `~/Code/var/regula-v1-branches.bundle`. It held nine git-ignored `cl-*` session notes and a `flutter_01.log` found nowhere else; they are kept in `~/Code/var/regula-v1-session-notes/`, and the checkout went to the macOS Trash (not `rm`). In this checkout, 89 local branches that pointed into the pre-rewrite history (all merged into the old `main`, so all in the bundle) were deleted. **`m-3d-planning` was kept**: it is unmerged and intent 004 cites it. Its one commit was re-created on the rewritten parent with the new email, tree unchanged (`93e0193`). Memory: copied into the `-Code-var-regula` project key with the name changed, merged with that key's two still-valid V1-era memories; the obsolete "regula2 is V2" memory dropped. The directory rename `regula2` → `regula` is the last act of the session, after this commit is pushed.
- **Gotcha for the future:** `git reflog` and loose objects in this checkout still hold the pre-rewrite commits with the old emails until they expire. They are local only and never pushed; a `git gc --prune=now` after reflog expiry removes them if that matters.
