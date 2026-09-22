# What to check, and how to argue it

## Scope: what counts as "the API"

Everything `cargo public-api`/rustdoc would call public: item signatures, **re-exports** (a
type's public *path* can change without the type itself changing), **trait impls** added or
removed (there's no "before" signature to diff against — it's a new or missing block), **macro-
generated `pub` items** (derive output, proc-macro expansions — textual diffing misses these
entirely), and **feature-gated `pub` items** (still public for anyone enabling the feature; note
the gate, don't discount it).

`#[non_exhaustive]` flips the semver rules for the item it's on: adding a variant or field to an
already-`#[non_exhaustive]` type is additive; adding one without the annotation is breaking; and
adding the annotation itself changes the contract going forward, worth a note even though it
isn't breaking today.

When `cargo public-api`/`cargo semver-checks` ran (`scan-api.sh`'s output), trust their diff over
a manual read for what they cover — they catch what source-level diffing can't (macro output,
blanket-impl overlaps, auto-trait changes through a private field). When a tool is missing (or,
for `cargo public-api`, when it's installed but there's no nightly toolchain to build rustdoc
JSON — a separate failure mode `scan-api.sh` reports precisely), say so explicitly and name what's
likely missed: re-exports, trait-impl-only changes, macro-generated items.

**A clean `cargo-semver-checks` run is not a clean bill of health for the signature lens.**
Confirmed against its own `--list` (v0.50.0): it has no lint for a function's return type changing
to a *different concrete type* — only unit↔value transitions
(`function_now_returns_unit`/`exported_function_return_value_added`). A function whose return type
changed from `()` to `Result<(), E>` — a real, textbook breaking change — passes it silently.

When `cargo public-api` also ran, its plain `base-api.txt`/`head-api.txt` diff (`scan-api.sh`'s
`<crate>.public-api.diff`) reliably catches exactly this: a return-type change shows as a `-`/`+`
pair on the full signature line, no lint needed. Read it whenever it's there, even after a clean
`semver-checks` run — confirmed on a real PR where `public-api` caught a return-type change
`semver-checks` missed entirely. Without `cargo public-api` (e.g. no nightly toolchain), that
fallback isn't available and the signature lens is on you alone; say so.

The diff also lists each item once per public path it's reachable from — a re-exported item
appears twice (once at its definition path, once at the re-export), which is a feature, not
duplication: it's exactly how a re-export path change (scope, above) surfaces. Don't collapse
these into one entry when reading it.

## Crate classification (`classify-crates.sh`)

| Kind | Detected by | Semver verdict |
|---|---|---|
| Published library | not `publish = false`, has a `[lib]` target | Full: apply the 0.x rule below 1.0 (a breaking change bumps the minor version) |
| Workspace-internal | `publish = false` inside a workspace | "Breaking for these siblings," listing the call sites that must change — the compiler already catches it, so this is a design conversation, not a landmine |
| Binary / `cdylib` | `[[bin]]` only, or `crate-type = ["cdylib"]`, no `[lib]` | No verdict on `pub` items — flag, don't judge, recognized external contracts instead (CLI args via clap, `serde` config structs, `#[no_mangle]`/`extern` symbols, wire types) |

Full encapsulation/ownership review (below) runs regardless of kind — only the semver verdict
changes. `classify-crates.sh`'s output is a heuristic (line-based `Cargo.toml` reading, not a
real TOML parser); treat a borderline case as a starting point, not the final word.

## The three lenses, per changed item

1. **Signature — what ownership does the contract promise?** `&T` vs `&mut T` vs owned `T`;
   `impl AsRef`/`Into` vs a concrete type; `Clone`/`Copy` bounds and lifetimes; owned vs borrowed
   return values, `Cow`; `Arc`/`Rc` leaking into public types; `pub` fields vs accessors (a newly
   `pub` field is a one-way door — see below); a private type leaking through a public signature.
2. **Body — where does each argument go after the call?** `.clone()`/`.to_owned()`/`.collect()`
   calls that exist only to satisfy the signature; data stored in a struct longer than it's used;
   a field that could be computed or passed in instead of held; `Arc<Mutex<_>>` where a plain
   ownership transfer would do.
3. **Callers — blast radius, and evidence.** Every caller in the workspace and in the PR's own
   hunks. Every call site having to `.clone()` or convert before calling is hard evidence the
   signature is wrong, not a coincidence.

Stop following a value once it's dropped, moved out, or crosses a crate boundary — no fixed depth.
Scope is the items the PR touches plus what's needed to follow their data; don't audit the rest of
the crate.

## Encapsulation: a newly `pub` field is a one-way door

Encapsulation is set at introduction, and `pub` is a one-way door: a public field is a permanent
promise that no invariant will ever guard writes to it — you cannot later add validation,
normalization, a cap or a ratchet without breaking every write site. `&mut self` gates *when* a
write happens, not *what* it does, and the absence of a constraint today is no evidence there won't
be one tomorrow. So judge a **newly introduced** `pub` field at the moment it appears — it is the
Rust-specific edge of information hiding (see `pr-review`'s
[`design-principles/05-information-hiding.md`](../pr-review/design-principles/05-information-hiding.md)
and [`04-modules-should-be-deep.md`](../pr-review/design-principles/04-modules-should-be-deep.md) for
the rationale):

- Flag it when the field has, or plausibly will have, any correctness / size / ordering / lifecycle
  constraint — collections, modes / state machines, counters, or a field some `set_*` method already
  guards elsewhere on the same type (a public field *plus* a guarding setter means the invariant is
  already bypassable — advisory only, since nothing forces callers through the setter).
- Verdict: a private field + accessor, or `pub(crate)` for a cross-module move. It is *additive*
  today, so it's never a `blocker` on its own — it's the "ownership/encapsulation smell,
  non-breaking" row of the table below (`should-fix` for a published library, `nit` / design-note for
  a workspace-internal crate). The real cost is the future breaking change it locks in.
- Exception: a deliberately unconstrained data bag is fine — but the doc comment must say so,
  because `pub` reads as "unconstrained forever".

## Justifying a breaking change

Every break gets raised, justified or not. Evidence comes from two places:
- **Stated intent** — `pr-context.sh`'s PR body, linked issues, commit messages.
- **Demonstrated benefit** — a concrete improvement in the diff itself (narrows `&mut` to `&`,
  drops a `Clone`/`Send` bound, hides a field behind a method, simplifies every call site it
  touched).

Bucket each one:
1. **Justified (stated)** — the PR says why, and the diff is consistent with it.
2. **Justified (demonstrated)** — silent PR, but a real, cited improvement.
3. **Unjustified** — neither. Turn it into a question for the author, not a verdict.
4. **Contradicts** — the stated reason and the diff disagree (e.g. "just a rename" that also
   changes ownership). Flag the mismatch explicitly.

Argue the case *against* every breaking change regardless of bucket — a stated reason is a claim
to test, not an automatic pass. Record the resolution either way; see [TRACKING.md](TRACKING.md).

## Severity / status tags

| Situation | Tag |
|---|---|
| Unjustified breaking change, published library | `blocker` |
| Unjustified breaking change, workspace-internal crate | `should-fix` |
| Justified breaking change (stated or demonstrated) | none — narrative only |
| Stated reason contradicts the diff | `question` |
| Binary/cdylib item recognized as an external contract | `question` |
| Ownership/encapsulation smell, non-breaking | `should-fix` or `nit`, judged normally |

Each item also gets a `status` once resolved: `open` / `resolved` / `dismissed` / `superseded`
(code changed again since the item was raised) — [TRACKING.md](TRACKING.md).

## Walkthrough order

Default: crate-first (same grouping as the summary table), and within a crate, breaking items
first, then non-breaking items with a real concern, then a one-line pass on the rest. This is a
default, not a fixed sequence: after the preview ([SKILL.md](SKILL.md) step 6), jump to any item
directly on request.
