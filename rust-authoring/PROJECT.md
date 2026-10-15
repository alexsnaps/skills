# Cargo, features, tests, benchmarks and macros

Guidance distilled from Jon Gjengset's *Rust for Rustaceans* (chapter numbers point at the book), updated where
Cargo has moved on since 2021. Read it before you touch `Cargo.toml` (dependencies, features, versions), add
tests or benchmarks, or write a macro.

## Features (Ch5)

- **Features are additive.** Enabling a feature may add items or behaviour, never remove an item or change a
  signature. Cargo unifies features across the whole dependency graph, so mutually exclusive features break
  someone's build.
- A feature-gated enum variant or public field requires the type to be `#[non_exhaustive]`.
- Refer to optional dependencies with `dep:` (`serde = ["dep:serde"]`) so the dependency doesn't also become an
  implicit feature.
- Depend with `default-features = false` and enable only the features you use.
- Gate code with `#[cfg(feature = "...")]` rather than `if cfg!(...)`.
- Large optional components (whole modules) can sit behind features, so users pay their compile time only if they
  opt in.
- If the crate has features, check their combinations (`cargo hack check --feature-powerset`) when the tool is
  available.
- Platform-specific dependencies go under `[target.'cfg(unix)'.dependencies]`. Feature and context `cfg`s (`test`,
  `debug_assertions`) don't work there.

## Versions (Ch5)

- **MSRV.** If `Cargo.toml` declares `rust-version`, don't use language or std features newer than it, and check
  with `cargo +<rust-version> check` when that toolchain is installed. If a change has to raise the MSRV, say so:
  it warrants at least a minor version bump.
- **Dependency versions.** Specify the oldest version that has everything you use, rather than automatically the
  latest, and make sure it unifies with what the workspace already resolves.
- If the project keeps a changelog, update it.
- In a workspace whose crates are published separately, use path dependencies between them only while one depends
  on unreleased changes in another.

## Tests (Ch6)

- Unit tests live in a `#[cfg(test)] mod tests` beside the code. Integration tests (`tests/`) and doctests see only
  the public API. Put shared helpers for integration tests in `tests/common/mod.rs`; Cargo doesn't generate a test
  harness for subdirectories.
- **Test-only access.** To inspect internals, add `#[cfg(test)] pub(crate) fn` accessors (or `#[cfg(test)]`
  bookkeeping fields) rather than widening visibility for everyone.
- **Mocking** goes through a generic parameter or a trait object. Where neither is right for the API, swap in a
  test type under `#[cfg(test)]`.
- **Generated inputs.** Property-test invariants against a simple reference implementation (`proptest`), including
  sequences of operations generated as a `Vec<Op>`. Fuzz parsers and decoders (`cargo fuzz`).
- **Misuse that must not compile** (wrong typestate, `!Send` types): write a `compile_fail` doctest and confirm it
  fails for the intended reason. Use `trybuild` when you need exact diagnostics.
- **Unsafe and concurrent code**: Miri, Loom and the sanitizers (see [SYSTEMS.md](SYSTEMS.md)).
- Lints worth enabling in a new crate are `missing_docs`, `missing_debug_implementations` and `rust_2018_idioms`.
  Add them to an existing crate only if asked.

## Benchmarks (Ch6)

- Use `criterion`, which runs the code many times and analyses the statistics, rather than timing a single run
  with `Instant`.
- Wrap inputs and outputs in `std::hint::black_box` so the optimizer can't delete the work being measured.
- Keep everything except the measured code (printing, random-number generation, setup, I/O) out of the timed loop.

## Macros (Ch7)

- Prefer functions and generics. Use `macro_rules!` for repetitive, structurally similar code that generics can't
  express, such as the same test battery over many types or the same trait impl for many types. Rule of thumb: if
  the code varies by type, use generics.
- In exported macros, use absolute paths (`::core::option::Option`, `$crate::...`), never the caller's imports.
  Prefer `::core`/`::alloc` over `::std` so that `no_std` users can call them. A `macro_rules!` macro can be used
  only after its definition in the crate (textual order) unless it is `#[macro_export]`ed.
- Procedural macros cost compile time; disable the `syn` features you don't need. Write a derive macro only for a
  trait that is implemented often and has an obvious implementation. Write a function-like proc macro when a
  `macro_rules!` macro has become unmaintainable or real compile-time computation is needed. Use an attribute
  macro for test generation, framework annotations, transparent instrumentation, or rewriting a type.
- Report proc-macro errors as `compile_error!` with a span on the offending input
  (`syn::Error::to_compile_error`), not as panics. Keep hygiene: use `Span::mixed_site()` for identifiers internal
  to the macro.
- Debug expansions with `cargo expand`.

## Tools worth knowing (Ch13)

- `cargo tree -i <crate>` shows why a dependency is in the graph; `-e features` shows which features are on.
- `cargo udeps` finds unused dependencies.
- `cargo deny` and `cargo audit` check licences, security advisories and duplicate versions.
- `cargo build --timings` shows which crates are slow to build.
- `cargo llvm-lines` measures monomorphization bloat.
- `cargo +nightly rustc -- -Zprint-type-sizes` reports type sizes and layouts; pin the important ones with static
  assertions.

Use these to investigate. Don't add tools or CI configuration to a project unless asked.
