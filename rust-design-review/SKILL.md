---
name: rust-design-review
description: Assess a whole Rust codebase against the design principles in *A Philosophy of Software Design* (deep modules, information hiding, complexity, layering, consistency) — not a PR diff. Walks a split codebase crate by crate then module by module, and judges how the parts compose: the crate dependency graph, layering, boundaries and duplication. Local and read-only — never writes to git or GitHub and never modifies the code. Use when the user wants a design or architecture review, health-check, or complexity/encapsulation audit of a Rust project or workspace (or a single crate/module) against Ousterhout's principles, says "/rust-design-review", or asks to assess a codebase's design rather than review a specific PR.
---

# rust-design-review

A whole-codebase companion to `pr-review`: instead of a PR diff, it assesses an entire Rust project
against *A Philosophy of Software Design*. If the codebase is split — a workspace of crates, or one
crate of modules — it goes bottom-up (module → crate) and then judges how the parts **compose**.

## Hard rules

1. **Read-only audit.** Never write to git, never touch GitHub (no `gh`), never use the network,
   never modify the code. All output goes under `.design-review/`. `scripts/check-no-writes.sh`
   lints the scripts for this (`--self-test` proves its rules).
2. **Running `cargo` builds the code** (it executes build scripts). That's expected for a codebase
   you own; if the tree is untrusted, say so and stay source-only (skip `measure.sh`'s
   `cargo-public-api` step).
3. **A number is a hypothesis, not a finding.** Every item anchors to a `crate` or
   `crate/path/mod.rs` and cites evidence you confirmed *by reading the code*, not a ratio alone.
   Record **strengths**, not only faults — an assessment names what's good too.
4. **Use the scripts.** They degrade gracefully and report what they skipped; never imply a check
   ran that didn't.

## Modes

- `/rust-design-review` (no argument): the whole codebase, from the current directory.
- `/rust-design-review <crate>`: one crate — its modules, and how it sits in the crate graph.
- `/rust-design-review <crate>/src/<path>.rs`: one module.

## Workflow

1. `scripts/ensure-excluded.sh` (a no-op when the root isn't a git repo). Read the project's own
   docs first — README, `ARCHITECTURE.md`/`DESIGN.md`, the top-level `lib.rs` `mod`/`pub use` — to
   learn the *intended* structure and layering before measuring against it.
2. `scripts/map-structure.sh`: the split — workspace? crates + kind + module counts + internal
   dependency edges (+ a circular-dependency hint). This map is what you assess.
3. `scripts/measure.sh [<crate>]`: per-crate and per-module signals (depth, public surface, sizes).
   Note whatever it says it skipped.
4. Assess bottom-up per [ASSESS.md](ASSESS.md): each **module**, then each **crate**, then the
   **composition** of all crates. Open the code the numbers point at. Record strengths and issues.
5. For one crate's public-API / ownership depth in detail, use the `rust-api-review` skill if
   installed rather than redoing it here.
6. Write `.design-review/report.md` (plus `crates/<name>.md` for a large workspace), most-central
   crate first, per [TRACKING.md](TRACKING.md).
7. Reply: the verdict, counts (`high`/`medium`/`low` + strengths), the report path, and what didn't
   run (missing tools).

## Scripts

`lib.sh` (shared) · `ensure-excluded.sh` · `map-structure.sh` · `measure.sh` (`[<crate>]`) ·
`check-no-writes.sh`. Exit codes are documented in each script's header.

## Design principles

The principle definitions and the red-flag table live in `pr-review`'s
[`design-principles/`](../pr-review/design-principles/README.md) (single source of truth), which
[ASSESS.md](ASSESS.md) links per lens. This skill expects `pr-review` as a sibling directory for
those docs; without it the lenses still apply — read the principles from the book. `pr-review`'s
`profiles/<repo>.md`, if present, still wins on repo-specific conventions (e.g. intentional `pub`).

## Relation to the other skills

`pr-review` reviews a single PR diff; `rust-api-review` judges a Rust PR's public-API surface; this
skill assesses a whole codebase's design. All three share the same design-principles vocabulary.
