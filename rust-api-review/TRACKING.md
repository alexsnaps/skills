# The output file

One file per PR, owned entirely by this skill: `.pr-reviews/<slug>/api-review.md` (`<slug>` is
whatever `pr-review`'s `parse_pr_ref` assigns — see its own `TRACKING.md`). Scratch build output
(the `git archive` exports, raw tool stdout) lives alongside it in
`.pr-reviews/<slug>/api-review/`, removed by `clean-api.sh`; the `.md` file itself is never
touched by that cleanup.

This file is **never** written into `pr-review`'s own `<slug>.md` directly. A PR-postable finding
here (`blocker`/`should-fix`/`question`, per [REVIEW.md](REVIEW.md)'s table) is meant to be read
and folded in by `pr-review`'s own workflow later, the same way it reads `mutants.status` results
— not written here as if this skill were one of `pr-review`'s own scripts.

Front matter: one `key: value` per line, full 40-char SHAs — same convention as `pr-review`'s own
tracking file.

````markdown
---
repo: praxis-proxy/praxis
pr: 214
head_reviewed: <40-char sha>
merge_base: <40-char sha>
reviewed_at: 2026-09-21T12:00:00Z
tools: semver-checks=ok public-api=missing
---
> Local, unposted API-surface review. Nothing here has been sent to GitHub.

## praxis-core (library)
- **A1** `should-fix` `open` — `pub fn Context::register(&mut self, ...)` added —
  `praxis-core/src/context.rs:88`
  > challenge: ...
  > resolution: ...
- **M2** `blocker` `open` — `pub fn Context::get` narrowed `&str` to `impl AsRef<str>` (breaking:
  trait-object callers no longer compile) — unjustified: PR is silent, no demonstrated benefit
  found — `praxis-core/src/context.rs:104`
  > challenge: ...
  > resolution: ...
- **D3** `resolved` — `pub struct LegacyConfig` removed — justified (demonstrated): last caller
  replaced by `Config` in this same PR — no severity tag — `praxis-core/src/config.rs` (removed)

## Summary
| id | crate | kind | change | item | file:line |
|---|---|---|---|---|---|
| A1 | praxis-core | library | added | `Context::register` | context.rs:88 |
| M2 | praxis-core | library | modified | `Context::get` | context.rs:104 |
| D3 | praxis-core | library | removed | `LegacyConfig` | config.rs (removed at head) |
````

## Values

- `status`: `open` (raised, not yet resolved in conversation), `resolved` (challenged, bucket
  recorded), `dismissed` (called not worth pursuing), `superseded` (a later push changed this
  item — re-raise fresh against the new code).
- `tools`: which of `cargo-semver-checks`/`cargo-public-api` actually ran, so a reader knows how
  much to trust the verdict without re-running anything.
- IDs (`A`/`M`/`D` + number) are assigned once, in summary-table order, and never reused within a
  PR. The narrative refers back to an ID instead of restating the signature.

## Resume

`scan-api.sh` reports the current head SHA. If it matches `head_reviewed`, nothing changed:
report the file as still current. If not, range-diff `merge_base..head_reviewed` against
`merge_base..<new head>`: an item whose quoted signature is gone or changed becomes `superseded`
and is re-raised fresh; an item untouched keeps its `status` and is skipped, not re-litigated.
