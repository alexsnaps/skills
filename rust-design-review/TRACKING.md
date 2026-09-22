# The assessment report

One report per codebase, owned by this skill: `.design-review/report.md` (git-excluded by
`ensure-excluded.sh` when the root is a git repo). For a large workspace, split per-crate detail
into `.design-review/crates/<name>.md` and keep `report.md` as the summary + composition + index.
Scratch files the scripts manage live alongside it: `metadata.json`, `structure.tsv`, `edges.tsv`,
`measure/<crate>.modules.tsv`.

Front matter: one `key: value` per line. `commit` only when the root is a git repo.

````markdown
---
root: /path/to/workspace
commit: <40-char sha or "n/a (not a git repo)">
workspace: yes
crates: 3
tools: tokei=ok public-api=missing cargo-modules=missing
assessed_at: 2026-09-22T12:00:00Z
---
> Local, unposted design assessment against *A Philosophy of Software Design*. Nothing was sent
> anywhere and no source was modified.

## Verdict
One or two lines: is complexity trending up or down, and the single most important thing to change.
Counts: high N, medium N, low N, strengths N.

## What ran / what didn't
- Ran: map-structure, measure (tokei loc). Read: <which crates/modules by hand>.
- Skipped: cargo-public-api (not installed) → crate-depth from `pub`+`pub_use` only; cargo-modules
  (not installed) → module tree approximated by source files.

## Composition (the whole)
Graph shape (from edges.tsv), boundary quality, cross-crate duplication, granularity, consistency.
- **C1 high** — `common` is a Special-General grab-bag every crate depends on (fan-in 4) —
  `common/` — evidence: edges.tsv + it exports unrelated `time`, `json`, `retry` modules.
  > design-principles: Ch9 Special-General Mixture; Ch2 (central crate → weighted heavily).

## Crates (most-central first)
### core  [workspace-internal, fan-in 1]
Depth verdict + key numbers (loc / pub / pub_use / public_api). Then findings and strengths.
- **core-1 medium** — `engine` module is shallow: 2 public fns over 3 lines that only forward to
  `util` — `crates/core/src/engine.rs` — > Ch4 Shallow Module / Ch7 Pass-Through.
- **strength** — `Config`'s parsing decision is fully hidden behind one constructor — Ch5.

## Strengths (collected)
- <the deep modules, clean seams, good hiding worth preserving>

## Recommendations (prioritized)
1. <highest severity × most-central first; each names the crate/module and the principle>
````

## Values

- Severity: `high` / `medium` / `low` / `question` (a real design choice, not a defect). Escalate by
  centrality — a `high` on a high-fan-in crate outranks a `high` on a leaf.
- `strength`: deep module, clean layering, well-hidden decision — recorded, no severity.
- IDs: `C<n>` for composition items; `<crate>-<n>` for crate/module items. Assigned once, referenced
  by ID afterwards.
- `status` (for re-runs): `open` / `resolved` / `dismissed` / `superseded` (the code changed since).
- `tools`: which of tokei / cargo-public-api / cargo-modules actually ran, so a reader knows how much
  to trust the numbers without re-running anything.

## Re-running

`map-structure.sh` + `measure.sh` are cheap and stateless — re-run them. If a git `commit` is
recorded and unchanged, the report is still current. If crates were added/removed (structure.tsv
differs) or a crate's numbers moved materially, re-assess the affected crates and the composition,
mark stale items `superseded`, and append what changed to the Verdict.
