# What to assess, and how

The principles are John Ousterhout's *A Philosophy of Software Design*, distilled per chapter in
`pr-review`'s [`design-principles/`](../pr-review/design-principles/README.md) (its `README.md` has
the red-flag table). This file says how to apply them to a **whole codebase** instead of a diff.
For the API/ownership depth of a single crate, `rust-api-review` is the finer tool — reuse it, don't
duplicate it.

## The unit of judgement: complexity

Everything reduces to one question — *does this structure make the system harder to understand and
modify?* (design-principles [Ch2](../pr-review/design-principles/02-nature-of-complexity.md)). Weight
every observation by **how central the part is**: a leak or a shallow interface in the crate that
everything depends on costs far more than the same thing in a leaf binary. (This is Ch2's
time-weighting, applied to the dependency graph — use `edges.tsv` fan-in as the weight.)

## Three scopes, bottom-up

Assess **module → crate → composition**, in that order: you can't judge a crate until you've read
its modules, and you can't judge the workspace until you've judged its crates. A single-crate
codebase still has the first two scopes; its "composition" is how its modules compose.

### 1. Module lens (each `mod` / `.rs` file)

- **Deep or shallow?** ([Ch4](../pr-review/design-principles/04-modules-should-be-deep.md)) Does the
  module hide a real chunk of implementation behind a small public surface, or is it nearly all
  `pub` (high `pub/kLoC` in `measure.sh`)? A one-type wrapper that mostly forwards is shallow.
- **Information hiding.** ([Ch5](../pr-review/design-principles/05-information-hiding.md)) What single
  decision does this module own (a data structure, a format, an algorithm)? Is anything `pub` that
  only the crate uses (should be `pub(crate)`)? Are struct fields `pub` where an invariant does or
  will apply (the encapsulation "one-way door" — see `rust-api-review`'s REVIEW.md)?
- **Temporal decomposition.** Is the module split by execution phase (`parse` / `validate` / `emit`)
  so each phase re-knows the same format, rather than by the knowledge each part owns?
- **Names & comments.** ([Ch13](../pr-review/design-principles/13-comments-describe-non-obvious.md),
  [Ch14](../pr-review/design-principles/14-choosing-names.md)) Vague module name; public items without
  a doc comment stating the abstraction; comments that repeat the code.
- **Size.** An oversized module (top of `<crate>.modules.tsv`) often hides several abstractions;
  a swarm of one-item modules is classitis. Neither number is a verdict — open the file.

### 2. Crate lens (the crate as one module, its modules composed)

- **Is the crate itself deep?** Its public API (what `lib.rs` re-exports) vs its total
  implementation (`public_api` count, or `pub`+`pub_use`, against `loc`). A crate whose API is almost
  as big as its code is a shallow crate.
- **Intra-crate leakage.** Does one decision (a type, a wire format) appear in several modules? Are
  submodules `pub` when `pub(crate)` would do, over-exposing the crate's internals?
- **Module composition.** Do modules layer in one direction, or cross-reference each other into a
  tangle? A module that only re-exports/forwards another is a pass-through
  ([Ch7](../pr-review/design-principles/07-different-layer-different-abstraction.md)).
- **Consistency** ([Ch17](../pr-review/design-principles/17-consistency.md)) **and errors**
  ([Ch10](../pr-review/design-principles/10-define-errors-out-of-existence.md)): one coherent error
  type and one set of naming/argument conventions across the crate, or a proliferation?
- **General vs special** ([Ch6](../pr-review/design-principles/06-general-purpose-modules-are-deeper.md),
  [Ch9](../pr-review/design-principles/09-better-together-or-better-apart.md)): is general-purpose
  code cleanly separated from special-purpose, or mixed in one module?

### 3. Composition lens (the whole workspace)

- **Shape of the crate graph** (`edges.tsv`). Clean layering — acyclic, direction clear
  (`app → domain → util`), fan-out modest — or a tangle? **Cycles are a red flag**
  (`map-structure.sh` flags 2-crate ones; trace longer ones by reading the edges).
- **Are the boundaries information-hiding seams?** Each crate should own a decision. A crate that
  only forwards to another (a pass-through crate), or a `common`/`util` grab-bag of unrelated
  helpers (Special-General Mixture), is a boundary drawn in the wrong place.
- **Duplication across crates** ([Ch9](../pr-review/design-principles/09-better-together-or-better-apart.md)):
  the same type/format/logic defined in more than one crate is change amplification waiting to fire.
- **Granularity.** Many tiny crates (classitis at crate scale — interface + versioning cost per
  crate) vs one mega-crate that hides nothing. For each boundary ask: does splitting *here* hide
  information and simplify callers, or just add cost?
- **Workspace-wide consistency** ([Ch17](../pr-review/design-principles/17-consistency.md)): error
  handling, naming, module layout uniform across crates so knowledge transfers.

## Red flags at codebase scale

| Red flag (design-principles) | How it looks across a codebase |
|---|---|
| Shallow Module | a crate/module whose public surface ≈ its size; a thin wrapper crate |
| Information Leakage | one type/format/decision known in N crates or modules; a "fact" duplicated |
| Temporal Decomposition | crates/modules named for pipeline phases sharing format knowledge |
| Overexposure | a crate marking internal modules `pub`; a prelude forcing rare items on all users |
| Pass-Through Method/Module | a crate or module that only forwards to another |
| Repetition | duplicated logic/types across crates or modules |
| Special-General Mixture | a `util`/`common` crate that is a grab-bag of unrelated helpers |
| Conjoined (crates/modules) | two crates that always change together / can't be understood apart |
| Comment Repeats Code / Vague Name | thin doc coverage on public items; vague crate or module names |
| Nonobvious Code | control flow hidden across crates (registries, dynamic dispatch, callbacks) |

## Severity, and recording strengths

An audit has no PR to block, so use `high` / `medium` / `low`, plus `question` for a genuine design
choice (two viable decompositions). Escalate to `high` when the part is depended on by many crates
(`edges.tsv` fan-in) — that is where complexity compounds.

Record **strengths** too, not only problems: a genuinely deep crate, a clean acyclic layering, a
decision well hidden behind one module. An assessment that only lists faults is not an assessment.

Every item — strength or issue — anchors to a `crate` or `crate/path/to/mod.rs` and cites evidence:
a `measure.sh`/`edges.tsv` number **plus** the code you read to confirm it. A number alone is a
hypothesis, never a finding (a high `pub/kLoC` on a crate whose items all have real, used callers is
fine). Never turn a ratio into a verdict without opening the file.

## Reading the numbers (`measure.sh`)

- **High `pub/kLoC`** → shallow-module candidate: open the module and check whether the surface is
  earning its keep.
- **Large `pub` + few internal callers** (grep the workspace for the item) → overexposure; likely
  wants `pub(crate)`.
- **Big files at the top of `<crate>.modules.tsv`** → may hide several abstractions; read them first.
- **`public_api` count vs `loc`** → crate depth. `-` means the tool/nightly is absent — say so, and
  fall back to `pub`+`pub_use` (weaker: misses trait-impl and macro-generated surface).
- All counts are heuristic (regex, not a parser): they point you at what to read, nothing more.
