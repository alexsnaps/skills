# The tracking file

One file per PR under `.pr-reviews/` (excluded from git by `scripts/ensure-excluded.sh`):
`<n>.md` for the base repo, `<owner>-<repo>-<n>.md` for any other repo. The `slug` printed by
`fetch-pr.sh` is the file name without `.md`. Per-PR working files live in `.pr-reviews/<slug>/`
(`pr.patch`, `restore.env`, `mutants/`, `mutants.status`, `commits/`), which scripts manage.

Front matter: **one `key: value` per line** (scripts read it with `fm_get`). Full 40-char SHAs.

````markdown
---
repo: cel-rust/cel-rust
pr: 353
url: https://github.com/cel-rust/cel-rust/pull/353
title: "Err on possible conflict when using `Context::add_function`"
author: alexsnaps
base: master
state: drafted
head_reviewed: <40-char sha>
merge_base: <40-char sha>
reviewed_at: 2026-09-20T12:00:00Z
landing: merge-commit
ci: green
mutation: done
restore_ref: err_fn
restore_sha: <40-char sha>
---
> AI-assisted DRAFT for the maintainer to edit. Nothing here has been posted.
> Landing strategy assumed: merge-commit (maintainer PR). Override with --merge/--squash.

## Suggested verdict: request-changes   (blocker: 1, should-fix: 2, nit: 3)
One or two lines: why.

## What ran / what didn't
- CI (read from GitHub): Test ok, Conformance ok, Fuzz ok, Run Examples ok, DCO ok
- Ran locally (gaps only): new tests fail without the fix; per-commit build 5/5; mutants 41 (2 missed)
- Not run: <what, and why>

## Findings, per commit
### 487084a fix(ctx): `add_function` doesn't allow for shadowing overloads   [yours]
- **F1 blocker:** <text> -- `cel/src/context.rs:217` (introduced here) -- status: open
  > quoted code the finding is about (used to re-match after a rebase)
- **F2 nit:** ...

## For you, not for the PR
- Design questions, postponements, anything you would not post as a comment.

## History
- 2026-09-20 round 1: reviewed 256e252 (full).
````

## Values

- `state`: `drafted` (written, not yet acted on), `posted` (the maintainer says they posted),
  `awaiting-author`, `re-review-needed`, `merged`, `closed`.
- Verdict (suggested, never submitted): `approve`, `request-changes`, `comment`, `needs-discussion`
  (design questions, e.g. two viable APIs).
- `ci`: `green`, `red`, `pending`, `not-run`. `mutation`: `none`, `running`, `done`, `skipped`, `stale`.
- Finding status: `open`, `posted`, `addressed`, `moved` (same code, different place), `dismissed`,
  `superseded` (a later commit of the PR changed the code).
- `restore_ref`/`restore_sha`: where the checkout was before `apply-pr.sh`; `reset-pr.sh` uses its own
  `restore.env`, this is for the human reading the file.

## Re-review of a tracked PR

1. Read the file. `fetch-pr.sh` reports `head_moved`. Review the range-diff since `head_reviewed`
   (`git range-diff <old-mb>..<old-head> <new-mb>..<new-head>`): it ignores the base moving.
   If the old head is not available, do a full review and put "previous head unavailable, full
   re-review" at the top.
2. For each open finding, look for its quoted code in the new diff: gone/changed -> `addressed`;
   same -> `open`; elsewhere -> `moved` (update `file:line`). Never match by line number.
3. Sync from GitHub, read-only, what the maintainer actually posted (`gh pr view --json
   comments,reviews`, and inline comments with `gh api` GET) and set those findings to `posted`;
   don't re-raise them.
4. Mutation results for an older head are `stale` after a force-push; re-run scoped to the
   range-diff's hunks only.
5. Split the new material into "contributor's changes" and "your commits", append a History entry.

## The index: `.pr-reviews/README.md`

One line per tracked PR, newest first, rewritten on every review:
`- #353 request-changes | drafted | ci green | mutation done | Err on possible conflict... | 2026-09-20`
