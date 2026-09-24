---
name: pr-review
description: Draft a local, terse, per-commit code review of a GitHub pull request for the maintainer to edit and post themselves, tracked per PR in .pr-reviews/ and incremental across pushes. Applies the PR diff to the local checkout first so the maintainer can review in-editor while the rest of the review runs, and never posts, commits or changes anything on GitHub. Use when the user says "review PR 123", "/pr-review", pastes a pull request URL, asks which PRs need review, or wants to reset after a review.
---

# PR review (draft only)

## Hard rules
1. **Never write to GitHub**: no comment, review, approve, label, edit, close, merge; no approving or
   re-running workflows. `gh` is read-only (`pr view|list|checks|diff`, `run view`, `repo view`, `api` GET).
2. **Never commit, push, stash, stage, reset or rebase**, and never edit git config or remotes. Allowed
   local writes: the applied PR diff, `.pr-reviews/**`, private refs `refs/pr-reviews/**`, and the one
   `.git/info/exclude` line.
3. Everything is a **draft** for the maintainer: labelled, terse, marked AI-assisted, never finished prose.
4. **Use the scripts** in `scripts/`. They refuse rather than improvise. If one stops, report why and stop.
5. **Do not execute PR code** that touches build/config files without the maintainer's go-ahead
   (`exec_guard` enforces it; PRs from someone else's fork also need an "OK to run?" first).
6. Never claim a check happened that didn't. Say what ran, what was read from CI, what was skipped, why.

`scripts/check-no-writes.sh` lints the scripts for forbidden writes (`--self-test` proves its rules).

## Modes
- `/pr-review` (no argument): `scripts/triage.sh`, show the list, ask which PR. Review nothing.
- `/pr-review <n | owner/repo#n | URL> [--merge|--squash]`: review (below), for any repo the clone has a remote for.
- `/pr-review reset [<ref>]`: `scripts/reset-pr.sh`, then say where the checkout now is.

## Review workflow
1. `scripts/ensure-excluded.sh`, then `scripts/fetch-pr.sh <ref>` (finds the remote by URL; there may
   be no `origin`). Merged or closed: update the tracking state and stop (nothing to apply). Draft or
   bot PRs: only when asked (bot = light review).
2. **Apply the diff first, before any other review work.** `scripts/apply-pr.sh <ref>`: needs a clean
   tree (if another PR is applied, `scripts/reset-pr.sh` first), detaches at the merge-base, applies
   the diff unstaged, prints the way back. Then immediately tell the maintainer the diff is applied
   and where (`branch@sha`, way back via `/pr-review reset`) so they can start reviewing in their
   editor. Everything below is your own review work that runs afterward, in the background for them —
   keep going without waiting for them.
3. Read the repo's CONTRIBUTING.md, PR template and `.github/workflows/*`, and `profiles/<repo>.md`
   if `fetch-pr.sh` reported one. The repo's own files win over the profile.
4. A tracking file exists? Read it and review incrementally (`head_moved=yes`): the range-diff since
   `last_reviewed_sha`, full review if the old head is gone. Match old findings by quoted code, never
   by line number. Details: [TRACKING.md](TRACKING.md).
5. CI: read what GitHub reports and what each job runs; do not re-run it. Only the gaps run locally,
   under the guard. See [REVIEW.md](REVIEW.md).
6. Review **each commit separately**, then the whole: correctness and spec first, then design and
   complexity (screen for red flags → [design-principles/](design-principles/README.md)), then
   API/UX, then performance; are the changes tested; mutation testing on the changed lines (default,
   background, 300-mutant limit, ask above). All in [REVIEW.md](REVIEW.md).
7. Write `.pr-reviews/<slug>.md` and `.pr-reviews/README.md` per [TRACKING.md](TRACKING.md), then
   `scripts/mark-reviewed.sh <ref>`.
8. Reply briefly: suggested verdict, blocker/should-fix/nit counts, the file path, what did not run,
   and the way back (`branch@sha`, `/pr-review reset`).

Mutation results arrive later. The next invocation reads `scripts/mutants.sh status <ref>` and appends
them to the tracking file.

## Scripts
`lib.sh` (shared) · `ensure-excluded.sh` · `fetch-pr.sh` · `apply-pr.sh` · `reset-pr.sh` ·
`mark-reviewed.sh` · `triage.sh` · `mutants.sh` (`count|run|status`) · `check-commits.sh` ·
`check-no-writes.sh`. Exit codes are documented in each script's header.

## Design principles
`design-principles/` distills *A Philosophy of Software Design* (Ousterhout) into a per-chapter
red-flag/checklist set for the strategic dimension of a review (REVIEW.md dimension 2). Start at
[design-principles/README.md](design-principles/README.md) — the red-flag table maps each flag to
the chapter file that explains it; read a chapter file only when a flag actually fits the diff. Repo
conventions in `profiles/<repo>.md` win over a generic principle (e.g. cel-rust's intentional `pub`).

## Repo profiles
`profiles/<repo>.md` holds what cannot be derived from the repo itself (priorities, known CI gaps,
generated paths, conventions). Without one, use the generic workflow and say the profile checks were
skipped. Available: `cel-rust`, `praxis`.
