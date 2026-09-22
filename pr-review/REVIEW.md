# What to check, and how to say it

## Principle: don't duplicate CI

1. `gh pr checks <n> -R <repo>` gives the real check names and states. Apps such as DCO show up
   here and **not** in `.github/workflows/`.
2. Read `.github/workflows/*` to learn what each job runs (its steps and commands). Everything a
   passing job already runs is covered: do not re-run it locally and do not review its output.
3. Reading CI is read-only: `gh run view <run> --log-failed` for a red job.

| CI state | What you do |
|---|---|
| green | one line in the draft ("CI: 5/5 green"), nothing more |
| red | the failing job is a finding: link, failing step, the error. Do not dig into lint/format noise |
| pending | record `ci: pending`; the verdict is provisional; the next run picks it up |
| not run (fork PRs often wait for approval) | say so; tell the maintainer to approve the run on GitHub. Do **not** run those gates locally instead unless told to |

Run locally **only what no CI job provides** (the "gaps"): the checks below marked (gap). The
profile lists the repo's known gaps.

## Dimensions, in priority order

1. **Correctness and spec conformance (blocking).** Behaviour beyond the happy path: does a
   stricter change block a legitimate use? Do the changed semantics match the spec / reference
   implementation? For a "behaviour-preserving" refactor, is there mechanical proof (a diff of
   before/after outputs), or only an assertion? Missing proof is `should-fix:`.
2. **Design and complexity (strategic).** Below correctness, above the rest: is the change making
   the system easier or harder to understand and modify? Screen the diff against the red-flag table
   in [design-principles/README.md](design-principles/README.md) (Ousterhout, *A Philosophy of
   Software Design*); when a flag fits, open that chapter's file for the specific checks and the
   questions to ask. High-value flags on a diff: shallow module, information leakage, temporal
   decomposition, pass-through method/variable, special-general mixture, conjoined methods,
   nonobvious code, a comment that repeats the code, a vague or hard-to-pick name. Most land as
   `should-fix:` or `question:`, rarely `blocker:`; a whole-approach disagreement ("this module is
   shallow") is a **For you, not for the PR** conversation, not a line comment. A red flag never
   blocks a correct, well-specified change on its own.
3. **API and user experience.** The API slice of the design lens above. Breaking change without `!`,
   release note, docs; new public items that should be internal; naming and error types consistent
   with the crate; docs that would fail if the claim were false (a doc example that never exercised
   what it describes). For a Rust crate's public surface, use the `rust-api-review` skill if
   installed, don't duplicate it.
4. **Performance.** Only if claimed or clearly on a hot path. A claim needs a benchmark, applied
   fairly (see the profile), never by trimming shared bookkeeping from one side. Prefer the simpler
   design first — see [design-principles/20-designing-for-performance.md](design-principles/20-designing-for-performance.md).
5. **Hygiene: commit level only.** Do NOT check the PR template, AI disclosure or issue-first
   policy: the maintainer does those. Conventional Commit message vs diff is checked per commit.

`unsafe` in the diff: use the `unsafe-rust-review` skill if installed, don't duplicate it.

## Tests: is the change actually covered? (CI can't catch what isn't tested)

1. **Static read.** Every behaviour change has a test that exercises it: error paths, feature-gated
   code, public API examples (doctests count). A bug fix without a regression test, or a feature
   without tests, is `blocker:`.
2. **Do the new tests fail without the change?** (gap) Keep the PR's tests, revert its source
   changes, run those tests, expect failure. A test that passes on the old code proves nothing.
3. **Mutation testing on the changed lines** (gap, default). `scripts/mutants.sh count <ref>` first.
   Up to 300 mutants: `scripts/mutants.sh run <ref>` (detached, background). Above: **ask the
   maintainer** (all / narrow to the highest-priority paths / skip), then `--over-limit` if they say
   all. Zero mutants = docs/tests/generated only: say so. Each missed mutant on a changed line is a
   `should-fix:` naming the mutation and `file:line`. Unviable/timeouts are mentioned, not blamed.
   Never review or count the pre-existing baseline of missed mutants. Missing tool: say "mutation
   skipped", never imply it passed. Mutants run on a copy; never `--in-place`.

## Per commit

Review each commit on its own, then the series.
- Message vs diff: Conventional Commit type, scope and `!` must match what the diff does (release
  tooling reads them); sign-off is CI's job. Atomic: one logical change, no refactor+feature mix.
- Builds? (gap) `scripts/check-commits.sh <ref>` (exports each commit with `git archive`; more than 20
  commits: ask). CI only builds the head.
- Anchor a finding to the commit that introduced it. If a later commit of the same PR fixes it, do
  not flag a defect: add a history nit ("fixed in `abc123`, consider squashing").
- Pointers: `file:line` at the PR head (what the editor shows) plus the commit SHA. If the code is
  gone at head, cite the commit's line and mark `superseded`.
- Commits authored by the maintainer are `yours`: still read and built, but no contributor-directed
  phrasing ("please add...").

**Landing strategy decides commit-level severity.** The maintainer's own PRs land as merge commits
(every commit reaches the base branch); external PRs are squashed (the PR title becomes the commit).
- merge-commit PR: wrong type/`!`, a non-atomic commit, or a commit that doesn't build = `should-fix:`.
- squash PR: those become `nit:`; the PR title/body must be a valid Conventional Commit with the
  right `!` (`should-fix:` if wrong).
State the assumption at the top of the draft; `--merge` / `--squash` overrides it.

## Running the PR's code: the guard

`exec_guard` (in `scripts/lib.sh`) refuses (exit 22) when the PR touches `build.rs`, `Cargo.toml`/lock,
toolchain files, `.cargo/`, `.github/`, or a profile-listed generator, unless `--approved`. Pass
`--approved` only after asking the maintainer. Independently, for a PR from a fork by someone other
than the maintainer, ask "OK to run PR #N? It only touches <paths>" before any script that builds
it. A worktree is not a sandbox: this guard is the protection.

## Generated code

Do not review generated files line by line, and exclude them from mutation scope. Summarise
("N generated lines changed"). Check the generated output changed *consistently* with its source
of truth; a hand-edit of a generated file is `should-fix:`. Regenerating for real runs guarded code:
only with the maintainer's go-ahead, then byte-compare with the PR's committed output.

## Writing findings

Every finding: a label (`blocker:` `should-fix:` `nit:` `question:`), terse, with `file:line` and the
commit, and evidence (the command and the relevant output) or an explicit "not verified".
- Phrase non-blockers as questions where honest ("Might be able to drop this branch, no?").
- A mechanical fix gets a GitHub `suggestion` block.
- No thanks, praise or warm-up sentences: the maintainer adds their own voice. The draft says
  it is an AI-assisted draft for them to edit.
- Design disagreements, "postpone" calls and anything not meant as a comment go in **For you, not
  for the PR**, never in the comments to post.
- A `blocker:` needs a reproduction or a cited rule. Don't inflate: fewer, verified findings.
