# cel-rust profile

Repo: `cel-rust/cel-rust`. Read `CONTRIBUTING.md`, `.github/PULL_REQUEST_TEMPLATE.md` and
`.github/workflows/rust.yml` first; if they disagree with this file, they win.

## Remotes and landing
- No `origin` is guaranteed. `upstream` is cel-rust/cel-rust, `alex` is the maintainer's fork, other
  remotes are contributors' forks (the maintainer sometimes pushes a commit or two to a contributor's
  branch, or opens a PR on their repo, to move a contribution along). Always resolve by URL.
- Maintainer PRs land as **merge commits** (each commit reaches master); external PRs are
  **squashed** (PR title = commit). `release-plz` builds `cel/CHANGELOG.md` and the semver bump from
  Conventional Commits, so type/scope/`!` matter. Bot PRs (`app/github-actions`, "chore(cel): release
  vX") get a light review: version bump and changelog make sense, CI green.

## Priorities (CONTRIBUTING)
Spec compliance, then user experience, then performance.

## CI, and what it leaves uncovered
CI (verify against the workflow): `Test` = fmt, three builds (minimal/default/all features), clippy
`-D warnings`, `cargo test -p cel` per feature (default, json, regex, chrono, structs); `Conformance` =
`cargo test -p conformance --release`; `Fuzz` (`value_binop`, `program_compile`, 60s); `Run Examples`;
`DCO` is a probot check, not a workflow.

Gaps to run locally (all guarded, in the applied checkout):
1. New tests fail without the change; mutation testing on changed lines (`.cargo/mutants.toml` sets
   `all_features` and `test_workspace`, so conformance counts as coverage, and excludes the generated
   parser and `fuzz/`). The repo has a large pre-existing baseline of missed mutants: ignore it.
   `example/**` is excluded (`profiles/cel-rust.mutants-args`): example `main`s only run in CI's
   `Run Examples` job, so their mutants always read as missed. Look at the diff of an example instead.
2. Per-commit build: `scripts/check-commits.sh <ref>` (default `cargo check --workspace --all-targets
   --all-features`). CI builds only the head.
3. Rustdoc: CI has no doc step. `cargo doc -p cel --no-deps --all-features`; report warnings on lines
   the PR touches (master already has an unrelated private-link warning about `FromVal`).
4. `cargo test -p cel --all-features`: CI never tests features together, and `parser_pratt` and `bytes`
   are only ever compiled, never tested.

## Conformance (verified by reproduction)
`conformance/src/bin/ignored.txt` lists known-failing cases; the generator emits them as
`#[should_panic]` tests in `conformance/tests/gen/**`. A PR that **fixes** a case but leaves it listed
turns the `Conformance` job **red** ("test did not panic as expected"). CI already catches this: do not
run the suite. Read the failing names from the job log and raise: "N cases now pass: remove them from
`ignored.txt` and regenerate (`cargo run -p conformance --features skip-version-check --bin generate`,
then `cargo fmt`)". Statically, removed `ignored.txt` names should coincide with removed
`#[should_panic]` lines in `gen/**`; a hand-edit of `gen/**` is `should-fix:`.

## Generated code (no line review, no mutation scope)
`cel/src/parser/gen/**` (ANTLR from `CEL.g4`), `conformance/tests/gen/**`, `conformance/src/gen/**`.
A change to the generated parser without a grammar change: note it, don't review it. Regenerating runs
guarded code (`conformance/src/bin/generate.rs`): only with the maintainer's go-ahead.

## What to look for beyond generic Rust review
1. **Spec behaviour.** Changed semantics (coercion, overflow, errors) against cel-spec / cel-go; cite
   the `langdef.md` section or a conformance case. Wins over everything else.
2. **Panics reachable from CEL input** in non-test library code (`unwrap`, `expect`, indexing,
   `unreachable!`, `todo!`): `blocker:`, with `file:line`. The fuzz targets exist for this.
3. **Error types.** `ExecutionError` (evaluation), `DeclarationError` (registering/declaring),
   `ParseErrors`/`ParseError`, `SerializationError`, `ConvertToJsonError`. New errors carry context
   (function, types), as in the overload-context work; a bare unit-like error is a `question:`.
4. **Public surface.** Intentional `pub`, `#[non_exhaustive]` on enums that will grow, `!` + release note +
   rustdoc for breaking changes.
5. **Rustdoc that would fail if wrong**: claims backed by a doctest or test.
6. **Two parsers.** ANTLR is the default, `parser_pratt` experimental; a parser change should hold
   for both or say why not.
7. **Performance claims** need a benchmark applied to all parser backends equally, never shaving
   shared `SourceInfo`/id bookkeeping off one side.
8. **"Behaviour-preserving" refactors need mechanical proof** (e.g. dump before/after and diff).
