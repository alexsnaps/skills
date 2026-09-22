---
name: rust-api-review
description: Review the public API surface a Rust pull request changes — what's added, removed or modified across every touched crate — then judge its encapsulation and ownership (borrow vs. move, data held longer than needed) and give a per-crate semver verdict, challenging every breaking change until you and the model agree whether it's justified. Local only: nothing is posted to GitHub, and the working tree is never touched. Requires pr-review (its fetched refs and scripts/lib.sh). Use when pr-review's "API and user experience" review dimension applies to a Rust crate, when the user says "review the API changes in PR N", "/rust-api-review N", or asks for a semver or encapsulation review of a Rust pull request.
---

# rust-api-review

Specialist companion to `pr-review`, the same way `unsafe-rust-review` is: cited from its
`REVIEW.md` ("public API changed → use this skill if installed"), but usable directly once a PR
is fetched.

## Hard rules

1. **Never write to GitHub.** `gh` is read-only here too (`pr view`, nothing else).
2. **Never touch the working tree, index, or history.** All building happens in `git archive`
   exports under `.pr-reviews/<slug>/api-review/`; whatever checkout `pr-review` may have applied
   is never read or disturbed. Allowed writes: `.pr-reviews/<slug>/api-review/**` and
   `.pr-reviews/<slug>/api-review.md`.
3. **Hard-depends on `pr-review`.** `scripts/lib.sh` sources `pr-review`'s `scripts/lib.sh` for
   `parse_pr_ref`, `load_pr_refs`, `exec_guard`, `require_excluded`. If it can't find `pr-review`
   (`$PR_REVIEW_DIR`, a `pr-review` directory next to this one, or `~/src/Claude/pr-review`),
   every script fails immediately (exit 2) — there is no fallback implementation.
4. **Requires the PR already fetched.** Run `pr-review`'s `scripts/fetch-pr.sh <ref>` first; this
   skill never fetches a PR itself, only reads the refs that leaves behind.
5. **Building the PR's code needs the same go-ahead as `pr-review`'s `exec_guard`**: a fork PR, or
   one touching build/config files, needs "OK to build PR #N?" before `scan-api.sh` runs.
6. **Every breaking change gets challenged, justified or not.** Never silently accept one because
   the PR text explains it, and never silently flag one as a defect without arguing it through
   first. See [REVIEW.md](REVIEW.md).

## Workflow

1. `scripts/classify-crates.sh <ref>`: which crates the PR touches and a best-effort kind for
   each (published library / workspace-internal / binary-or-cdylib) — no build, reads `Cargo.toml`
   via `git show`. It's a heuristic starting point; confirm anything borderline yourself.
2. `scripts/pr-context.sh <ref>`: PR body, linked issues, commit messages — evidence for the
   justification step in [REVIEW.md](REVIEW.md).
3. Read the diff for build/config files (`scan-api.sh` will refuse without `--approved` if there
   are any, or if the PR is from a fork by someone other than the maintainer) and ask first.
4. `scripts/scan-api.sh <ref> [--approved]`: archives base and head, runs `cargo public-api` and
   `cargo semver-checks` per crate where installed, saves raw output under
   `.pr-reviews/<slug>/api-review/`. Missing tool → say "skipped: tool missing", never imply a
   pass — reason about that crate from the diff alone and say so explicitly.
5. Read `.pr-reviews/<slug>/api-review.md` if it exists: its front matter has `head_reviewed` and
   each item's `status` ([TRACKING.md](TRACKING.md)). Unchanged, already-`resolved` items are
   skipped; anything whose quoted code changed since is re-raised as `superseded`.
6. Build the summary table (every added/modified/deleted public item, crate-grouped, IDs `A1`/
   `M2`/`D3`, `file:line` at PR head — [TRACKING.md](TRACKING.md)) and show it up front, before
   the walkthrough starts.
7. Walk the items. Default order is crate-first, severity-within-crate (breaking, then concerning
   non-breaking, then a light one-line pass on the rest) — but once the summary's been seen, jump
   to whatever item is asked for instead.
8. Per item, the three lenses from [REVIEW.md](REVIEW.md) (signature / body / callers). For a
   breaking change: argue the strongest case against it, record the answer, and bucket it
   (justified-stated / justified-demonstrated / unjustified / contradicts-diff).
9. Write `.pr-reviews/<slug>/api-review.md` incrementally as items resolve, not only at the end —
   format and severity mapping in [TRACKING.md](TRACKING.md).
10. `scripts/clean-api.sh <ref>` once done, to drop the scratch archives (the `.md` file stays).

A PR with no public API changes: say so in one line and skip the walkthrough entirely.

## Scripts

`lib.sh` (shared, hard-depends on `pr-review`) · `classify-crates.sh` · `pr-context.sh` ·
`scan-api.sh` · `clean-api.sh`. Exit codes are documented in each script's header.

## Repo-specific notes

Read `pr-review`'s own `profiles/<repo>.md` if one exists, for repo-specific API conventions
(e.g. cel-rust's note on intentional `pub` and `#[non_exhaustive]`). Don't keep a second copy of
that knowledge here.
