# praxis profile

Repo: `praxis-proxy/praxis` — a **Pingora-based** Rust reverse proxy (workspace crates flow
`server → protocol → filter → core → tls`, with test crates under `tests/`), run as **many instances
in parallel** in front of AI/agentic workloads. Read `.claude/CLAUDE.md`, `CONTRIBUTING.md`,
`docs/developing/{conventions,type-design,review-criteria}.md`, `docs/architecture/overview.md` and
the relevant `docs/**` first; if they disagree with this file, **they win**. Not the Envoy ext_proc
variant (`opendatahub-io/praxis-extproc`) — different codebase.

## Remotes and landing
- No `origin`. `upstream` = `praxis-proxy/praxis`, `alex` = the maintainer's fork
  (`alexsnaps/praxis`); other remotes are contributor forks. Always resolve by URL.
- Conventional Commits are CI-enforced (`type(scope): summary`, ≤72 chars). `main` is linear; treat
  PRs as **squashed** (the PR title becomes the commit → it must be a valid Conventional Commit with
  the right `!`) unless told `--merge`. History mixes GitHub squash `(#N)` with a maintainer-curated
  batch tagged `(L##)`; don't assume every `main` commit maps to a PR.

## Priorities
Correctness and security first (a security-sensitive proxy), then the Praxis runtime dimensions
(below), then conventions / type-design, then performance. Conventions are gating: a PR that violates
`docs/developing/conventions.md` is rejected.

## What CI already covers — do NOT re-run it
Verify against the workflow and `gh pr checks <n> -R praxis-proxy/praxis`. Everything a **green** job
ran is covered — read its result, don't reproduce it. Local runs are only for the gaps two sections down.
- **Tests** (`tests.yaml`): `make lint` (clippy `-D warnings` across feature combos, nightly
  `fmt --check`, `cargo machete`, `xtask lint-deps`, `lint-example-tests`, `sync-example-readme`,
  `lint-filter-docs`), `make test` (all-feature unit tests outside `tests/`), `make check-features`
  (per-feature `cargo check`).
- **Tests (Integration)** (`integration.yaml`): `make test-integration` (schema + security +
  resilience + integration), `make build-benches`.
- **Conformance** (`conformance.yaml`): h2spec + `make test-conformance`.
- **Coverage** (`coverage.yaml`): `cargo llvm-cov --workspace --fail-under-lines 96` — a **96% line
  gate**. Don't hand-audit line coverage; read this job.
- **Mutation Testing** (`mutants.yaml`): `cargo mutants --workspace`. If green and it covered the
  changed lines, mutation is done — **skip the local run**; only run `scripts/mutants.sh` on the diff
  when the job is absent/red or not diff-scoped (verify which).
- **Documentation** (`documentation.yaml`): `make doc` = rustdoc `-D warnings`, private items, all
  features. **SemVer** (`semver.yaml`): `cargo semver-checks`. **Supply Chain** (`supply-chain.yaml`):
  `cargo audit` + `cargo deny`. **MSRV** (`msrv.yaml`): `cargo check` on 1.96. **CodeQL**,
  **Container**, **(micro)benchmarks** also run.
- **Conventions / PR Conventions** (`conventions.yaml`, `pull-request-conventions.yaml`): Conventional
  Commits, **≤750 added production LOC** (tests/docs/examples excluded), a real description,
  `Signed-off-by` on every commit, cryptographically signed commits, and **human authorship —
  AI-authored / AI-signed-off commits are rejected**. These are the maintainer's gates (via
  `praxis-bot-app`); report a red one as a finding, don't re-check it. (Never add AI attribution to
  anything you produce — a stray `Co-Authored-By`/AI trailer fails this gate.)

## What the automated bot already covers — read it, don't repeat it
`automated-review.yaml` runs a **Claude review** (`claude-code-action`, default `claude-sonnet-4-6`,
prompt `.github/prompts/automated-review.md`) that **posts inline comments + a severity table** on
every PR. Read it first, read-only: `gh api repos/praxis-proxy/praxis/pulls/<n>/reviews` and
`.../comments` (its body starts `## Automated Review`). It already does, broadly and from the diff:
- **Correctness**: edge cases, boundaries, off-by-one, overflow/underflow, input-validation gaps,
  panic vectors (`unwrap`/index/division), basic concurrency safety, intent match.
- **Test-coverage-gap analysis** (its self-declared most-critical step): per-function, error-path,
  branch, config (valid / invalid-per-variant / default / serde round-trip), integration-for-examples,
  and a new-logic-vs-new-tests ratio check.
- **Conventions & security**: CLAUDE.md style, idiomatic Rust / `thiserror` / combinators,
  injection / DoS / unbounded allocation / info leakage in errors, docs, API-boundary validation,
  and style nits.

Do **not** re-derive these from scratch. Instead: **verify** the bot's material findings against the
code at the reviewed revision (it works from the diff, cites line numbers, and can be wrong or stale),
drop what it already nailed, and spend the human budget on what it and CI miss (next section). If the
bot and CI are both clean on a dimension, say so in one line and move on.

## Where local review adds value (the gaps neither CI nor the bot closes)
1. **Did behaviour actually change?** Diff against the merge base (`git show <base>:<path>`); don't
   attribute a pre-existing quirk to the PR — a diff-only reviewer (the bot) routinely does. If the
   change only alters how a quirk is reported, say that and file the quirk separately.
2. **New tests fail without the change** (gap): keep the PR's tests, revert its source, expect
   failure. Neither CI nor the bot proves this.
3. **Per-commit build & atomicity** (gap): `scripts/check-commits.sh <ref>` — CI builds only the head;
   the ≤750-LOC cap keeps series short.
4. **Praxis runtime dimensions** (need reasoning the bot's static pass doesn't do; each is a
   first-class `blocker:`/`should-fix:` source):
   - **Pingora boundary** (`docs/operating/security-hardening.md`): don't reimplement what Pingora
     owns (request-smuggling prevention, H2 backpressure, pool safety, HTTP/1.1 upgrade forwarding);
     Praxis owns hop-by-hop stripping, Host validation, `X-Forwarded-*`, retry. Crossing it wrong is a
     finding.
   - **Reserved headers**: `x-praxis-*` / `x-ext-*` are stripped from ingress and trusted internally;
     trusting a client-supplied one, or failing to strip, is `blocker:`.
   - **Concurrency & hot reload**: `Arc<ArcSwap<FilterPipeline>>` atomic swap; per-request
     `HttpFilterContext` (`filter_metadata` / `filter_state`) lifecycle across phases; lock scope
     (e.g. build factories outside registry locks); ordering under interleaving.
   - **Horizontal scale / multi-proxy**: N instances against one upstream — retry budgets,
     circuit-breaking, health checks and sticky sessions must not assume single-instance state; watch
     thundering herds on retry/backoff/cache-miss.
   - **Large payloads / streaming**: `BodyMode::Stream` vs buffering; never buffer a full
     streaming/SSE response; backpressure; body ceilings (`ABSOLUTE_MAX_BODY_BYTES`). Buffering where
     it should stream is a finding.
   - **Long-lived connections**: timeout config, WebSocket/upgrade handling, cleanup on
     disconnect/error, leaks under churn.
   - **AI/agentic traffic**: long inference times, large token payloads, multi-turn sessions,
     retry/backoff under bursty high-latency load. The inference path is proxy-parsed (`policy` reads
     the body `model`), not classified.
5. **Enhancement-proposal conformance**: a PR referencing a proposal (`docs/proposals.md` or the
   `praxis-proxy/enhancements` repo) must conform — divergence is a finding, cite the section.
   Larger/architectural/public-interface changes that skipped the proposal process are a `question:`.
6. **New-capability completeness** (CLAUDE.md): a new filter/feature needs unit + integration tests,
   an example config using the header-comment format, a functional example test in
   `tests/integration/tests/suite/examples/`, and `sync-example-readme`. Missing any is a finding.
7. **Type design** (`docs/developing/type-design.md`): enums over strings for fixed sets,
   `#[serde(deny_unknown_fields)]`, `try_from` for constrained numerics, `#[serde(default)]` over
   `Option`+`unwrap_or`; validate only proxy-needed fields (let the backend police ranges).
8. **Encapsulation & error locality** — reinforce two design principles the bot under-weights: a
   newly-introduced `pub` field is a one-way door (prefer private + accessor, since you can't add an
   invariant later without breaking every write site → `design-principles/05-information-hiding.md`);
   an operation that can reject/drop/substitute must signal it at the origin, not fail silently —
   silent loss surfaces later and elsewhere (→ `design-principles/10-define-errors-out-of-existence.md`).

## Generated code (no line review, exclude from mutation)
- `examples/README.md` — table section generated from example-config header comments
  (`cargo xtask sync-example-readme --fix`).
- `docs/filters/reference.md` — filter reference index (`xtask filter-docs`, checked by
  `lint-filter-docs`).
Both are verified by `make lint` in CI; a hand-edit is `should-fix:`. Regenerating runs guarded code
(`xtask/**`, see `profiles/praxis.guard`): only with the maintainer's go-ahead, then byte-compare with
the committed output.
