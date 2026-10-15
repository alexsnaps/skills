---
name: rust-authoring
description: Author idiomatic, hard-to-misuse Rust. Use when writing or modifying Rust code — choosing types, APIs, error handling, concurrency, and async patterns so misuse is caught at compile time, and shaping modules, interfaces, names and docs so complexity stays low.
---

## When this applies

Apply these practices whenever you write or modify Rust in the current project. They cover the decisions the
compiler cannot make for you: how to shape types and APIs so they are hard to misuse, how to handle errors, and
how to write correct concurrent and async code.

- Write code that fits its surroundings — match the crate's existing naming, module layout, error style, and
  idioms before importing a pattern from here.
- When a rule here conflicts with a strong, consistent local convention, follow the local convention. Don't
  introduce a "better" convention in one place; if one is worth changing, ask, then change every use.
- Prefer moving a class of bug to compile time (strong types, enums, typestate) over catching it at runtime.
- Working code isn't enough: aim for the design that keeps the code easy to understand and change. Complexity
  builds up in small increments, so no kludge is too small to matter.
- "Type" below means a struct, enum, or type alias defined in the current crate.

### Reference files

This file holds the rules and the self-check. Read a reference file when the work matches its row; each one
explains its rules and gives examples.

| File | Read it before you... |
|---|---|
| [DESIGN.md](DESIGN.md) | design a new type, trait, module boundary or error enum (complexity, information hiding, docs, names) |
| [API.md](API.md) | add or change a public signature, trait, error type or crate docs (contracts, standard traits, semver) |
| [SYSTEMS.md](SYSTEMS.md) | write `unsafe`, FFI, atomic or lock-free, or `no_std` code |
| [PROJECT.md](PROJECT.md) | touch `Cargo.toml` (dependencies, features, versions), or write tests, benchmarks or macros |

## Write idiomatic Rust

Aim for these characteristics in the code you write:

- **Embrace the type system.** Model data with enums and structs so the compiler checks exhaustiveness and catches
  missing cases. Make illegal states unrepresentable.
- **Prefer functional patterns.** Reach for iterators, closures, and combinators (`map`, `filter`, `fold`) over
  manual index loops when they read more clearly.
- **Handle errors with the type system.** Use `Option` and `Result` with pattern matching (`match`, `if let`) and
  the `?` operator; no sentinel values or manual null checks.
- **Work with ownership and borrowing.** Let the borrow checker guide the design; borrow by default, own when you
  must.
- **Design with traits, not inheritance.** Use traits for shared behaviour, and implement the standard ones
  (`Display`, `Debug`, `From`, `Default`, …) so your types integrate with the ecosystem.
- **Stay tooling-clean.** Code should pass `cargo fmt` and `cargo clippy` with zero warnings before you call it
  done.

## Self-check before you're done

Before considering a change complete, confirm:

### Correctness the compiler cannot catch

- [ ] Boundary conditions are handled
- [ ] State machine transitions are complete
- [ ] No race conditions in concurrent paths
- [ ] Public APIs are hard to misuse
- [ ] Type signatures express intent
- [ ] Error type granularity is appropriate

### Design (see [DESIGN.md](DESIGN.md))

- [ ] Each new type or module hides at least one decision; its interface is much simpler than its implementation
- [ ] No new pass-through methods, forwarding wrappers, or parameters threaded through layers that don't use them
- [ ] The common case needs no knowledge of rare options (defaults; extras kept off the main path)
- [ ] Each new error variant or panic is either one a caller can act on or a genuine bug; the rest were defined
  away, masked, or aggregated
- [ ] For a new public interface, at least one substantially different alternative was considered
- [ ] Modified code reads as if it had been designed with the change in mind, with no bolted-on special cases or
  flags
- [ ] No [red flag](#red-flags) is left unaddressed

### Public API (see [API.md](API.md))

- [ ] Public types implement `Debug`, plus `Clone`/`Default`/`PartialEq`/`Eq`/`Hash` where they make sense; a type
  that isn't `Send`/`Sync` says why
- [ ] Arguments ask only for what's needed (owned only when stored or moved; generic only where callers will pass
  other types); return types promise only what you can keep
- [ ] New items are no more visible than needed (`pub(crate)` otherwise); no foreign type leaks into the public
  API by accident
- [ ] `#[non_exhaustive]` was decided for each new public enum and struct; auto-trait expectations are pinned by a
  test

### Documentation and naming

- [ ] Docs were written with (or before) the code; interface docs say what, not how
- [ ] Arguments, return values and fields are precise: units, inclusive/exclusive bounds, meaning of `None`/empty,
  ownership
- [ ] `# Errors` / `# Panics` / `# Safety` sections are present where they apply
- [ ] No comment restates the code or the item's name; workarounds say why they're needed
- [ ] Names are precise and used consistently; booleans read as predicates
- [ ] The diff was re-read: docs match the new behaviour; no leftover `dbg!`, `println!`, `todo!()`, or
  commented-out code

### Ownership and borrowing

- [ ] Every `clone()` is intentional and justified by a comment when non-obvious
- [ ] `Arc<Mutex<T>>` is used only where shared mutable state is truly needed
- [ ] `RefCell` usage is justified
- [ ] Lifetimes are kept simple
- [ ] `Cow` considered where it avoids an allocation

### Unsafe code (most important)

- [ ] Every `unsafe` block has a `SAFETY` comment explaining *why* it is sound
- [ ] Every `unsafe fn` has a `# Safety` doc section listing caller invariants
- [ ] The unsafe boundary is as small as possible: private fields, and a safe interface around it
- [ ] A safe alternative was considered first
- [ ] Soundness holds if user code panics or `?` returns early; `unsafe impl Send/Sync` carries the right bounds
- [ ] Tests that exercise unsafe code ran under Miri (if available), or the report says they didn't

### Concurrency

- [ ] The simplest design was tried first (channels or locks); anything finer-grained is backed by a measurement
- [ ] Atomics use `SeqCst` unless a comment justifies a weaker ordering
- [ ] Lock acquisition order is consistent
- [ ] Channel buffer sizes are deliberate
- [ ] `JoinHandle` results are handled
- [ ] `join!` / `try_join!` used for structured concurrency

### Cancellation safety

- [ ] Futures in `select!` are cancel-safe
- [ ] Public async fns document their cancel safety
- [ ] Cancellation cannot cause data loss or inconsistent state
- [ ] `tokio::pin!` is used correctly for reused futures

### Error handling

- [ ] No `unwrap()` / `expect()` on recoverable failures in production code; only a broken invariant (a bug)
  panics, via `expect("<invariant>")` or `unreachable!`
- [ ] No error a caller needs is swallowed (`let _ =`, `.ok()`, `unwrap_or_default()`)
- [ ] Error messages help with debugging
- [ ] `#[must_use]` values are handled; `#[source]` preserves the chain
- [ ] Error types implement `Error` (with `source`), are `Send + Sync + 'static`, and `Display` as one lowercase line
  with no trailing punctuation

### Performance

- [ ] No unnecessary `collect()`
- [ ] Large data passed by reference
- [ ] Strings built with `with_capacity` / `write!` where it matters
- [ ] `impl Trait` vs `Box<dyn Trait>` chosen deliberately
- [ ] Hot paths avoid allocations
- [ ] Every optimization that adds complexity is backed by a measurement

### Code quality

- [ ] `cargo clippy` is clean and `cargo fmt` applied
- [ ] Doc comments are complete; public APIs have examples
- [ ] Tests cover boundary conditions
- [ ] A bug fix comes with a regression test that failed before the fix
- [ ] Nothing newer than the crate's `rust-version` is used; features stay additive

### Async

- [ ] No blocking calls (`std::fs`, `thread::sleep`) in async
- [ ] No `std::sync` lock held across `.await`
- [ ] Spawned tasks are `'static`
- [ ] `spawn` used only for genuinely parallel/background work
- [ ] No future runs long without yielding; CPU-heavy work goes to `spawn_blocking` or a thread pool
- [ ] Pinning uses `pin!`/`Box::pin`, never a hand-written `Pin::new_unchecked`

### Typestate

- [ ] State that gates which methods are legal is encoded in the type, not a runtime flag
- [ ] Transitions consume `self`
- [ ] State markers are zero-sized; `PhantomData` holds unused parameters
- [ ] State set is sealed when the type is public and states should not be extensible

## Dependencies

### Before adding a crate

- Check whether a crate already in the tree does the job — especially for cross-cutting concerns (error handling,
  async runtime, serialization, HTTP). Don't add a second crate of a similar nature when one can serve; it grows
  build time and binary size.
- Put test-, bench-, and example-only crates in `[dev-dependencies]`. Gate situational code behind a feature and
  mark its dependencies `optional = true` rather than always pulling them in.
- Pick a version that unifies with what the workspace already resolves, so `Cargo.lock` doesn't gain a second copy
  of the same crate. If a duplicate version is unavoidable, note why. Within that, specify the oldest version that
  has everything you use, not automatically the latest.
- Depend with `default-features = false` and enable only what you use. Refer to an optional dependency as
  `dep:name` in `[features]`, and keep features additive: enabling one must never remove an item or change a
  signature.
- Respect the crate's `rust-version` (MSRV): don't use language or std features newer than it.
- Details and the rest of Cargo in [PROJECT.md](PROJECT.md).

## Design for low complexity

Every design choice should keep the code easy to understand and change. Judge a choice by what it costs the next
reader: how many places change if this decision changes, how much a caller must know, and whether a maintainer
would know what else to update (if not, make the compiler tell them). [DESIGN.md](DESIGN.md) has the reasoning
and Rust examples behind each rule below; **read it before you design a new public type, trait, module boundary,
or error enum.**

- **Make modules deep.** A function, type or module should hide much more than its interface exposes. Don't split
  things up by size: many small items, each with its own interface, add complexity.
- **Hide each design decision in one module** (a format, a representation, an algorithm). Don't split modules by
  execution phase when the phases share knowledge, and don't hand out references to internal collections.
- **Make the common case simple.** `new`/`Default` cover the usual use; rarely used options live in builder
  methods that the common caller never needs to see.
- **Pull complexity down.** Handle a condition inside the module rather than returning it as an error, an
  `Option` or a config parameter, unless callers genuinely need to decide.
- **Make it somewhat general-purpose.** Implement today's need, but phrase the interface in the module's own
  terms rather than in terms of the caller's feature.
- **Different layer, different abstraction.** Avoid methods that only forward to a field, wrappers that mirror an
  inner type's API, and parameters threaded through functions that only pass them on.
- **Define errors and special cases out of existence.** See
  [Reduce where errors must be handled](#reduce-where-errors-must-be-handled).
- **Design it twice.** For a new public type, trait or module interface, sketch at least two substantially
  different sets of signatures and choose by ease of use for callers.

### Red flags

When you notice one of these in code you're writing, stop and look for a design that removes it. Each one is a
prompt to reconsider, not a verdict.

| Red flag | What it looks like in Rust |
|---|---|
| Shallow Module | a `pub` item whose doc would be as long as its body; a newtype that forwards most of the inner API |
| Information Leakage | one format, representation or decision known in two modules; getters returning `&HashMap`/`&Vec` internals |
| Temporal Decomposition | types or modules per execution phase (`reader`/`parser`/`writer`) that share format knowledge |
| Overexposure | the common call needs rarely used parameters or types; a `new` whose extra arguments nearly always take the same value |
| Pass-Through Method / Variable | methods that only forward to a field; a parameter threaded through functions that only hand it on |
| Repetition | the same snippet, `match` or cleanup in several places |
| Special-General Mixture | a general mechanism with code for one of its uses; a `bool` parameter that picks between two bodies |
| Conjoined Methods | two functions you can only understand by reading both |
| Comment Repeats Code | `/// Returns the name.` on `fn name` |
| Implementation Documentation Contaminates Interface | `///` docs describing internals the caller doesn't need |
| Vague Name | `data`, `info`, `status`, `manager`, `tmp`, a bare `count`, `result` for something other than the return value |
| Hard to Pick Name | no short, precise name comes to mind: the item does more than one job |
| Hard to Describe | a complete `///` doc has to be long |
| Nonobvious Code | a quick read misleads: tuple returns, callbacks with no "invoked when", a `new` that spawns tasks |

Clippy can catch a few of these without any change to the crate's lint config:

```sh
cargo clippy -- -W clippy::fn_params_excessive_bools -W clippy::struct_excessive_bools \
  -W clippy::missing_errors_doc -W clippy::missing_panics_doc -W clippy::wildcard_enum_match_arm
```

## Modifying existing code

- When you're done, the code should look as if it had been designed with this change in mind. Don't make the
  smallest diff by bolting on a special case, flag or parameter. If the change needs a seam that isn't there,
  refactor first (the `make-change-easy` skill, if installed, structures this).
- Stay in scope: improve the design of the code the change touches, and report (don't fix) unrelated problems you
  notice.
- Keep comments next to the code they describe, and update them in the same change. Reasons a future maintainer
  will need go in the code, not only in the commit message.
- For a bug fix, write the regression test first and watch it fail.
- Before calling it done, re-read the whole diff: do the docs still match the behaviour, and is any `dbg!`,
  `println!`, `todo!()`, stale TODO, or commented-out code left over?

## Shaping functions and types

### Constructors

When you create a new instance of a type, expose it as an associated function on that type (`Type::new(...)`, or a
named constructor like `Type::from_parts(...)`) rather than a free function. Implement `Default` when the type has
a sensible default so it composes with the rest of the ecosystem.

Keep `new` cheap and free of side effects. Name a constructor that does I/O, connects, or spawns threads or tasks
for what it does (`open`, `connect`, `spawn`) and document that it does so.

### Prefer methods over free functions

When a function's primary argument is (a reference to) a struct from the current crate, make it a method in an
`impl` block on that type rather than a free function. Behaviour stays with its data and the call site reads
better.

### Expose operations, not fields

Don't hand out the representation: no getter that returns `&HashMap`/`&Vec` internals, and no getter and setter
pair per field. If a struct has an invariant, keep its fields private and offer the domain operations callers
need (`param(name) -> Option<&str>`, not `params() -> &HashMap<..>`). A plain-data struct with no invariant can
have `pub` fields rather than trivial accessors.

### Return named structs, not tuples

When the meaning of the parts isn't obvious, return a struct with named fields: with `-> (u64, bool)`, every
caller has to remember which is which. Universally understood pairs, such as `(K, V)` or the result of
`split_at`, are fine as tuples.

## Design for illegal-states-unrepresentable

### Enums over groups of booleans

When several booleans together determine a state or a mode — especially when some combinations are invalid — model
the allowed states as an enum instead of loose `bool` fields. One `enum` makes the valid set explicit and lets the
compiler check you handled every case.

### Use strong types, not stringly-typed values

Don't represent distinct domain concepts with the same primitive — e.g. `String` for both an IP address and a file
path, or `u32` for both a user id and a byte count. Wrap each in a newtype so the compiler rejects passing one
where the other is expected. The classic bug is one `block` name and one integer type used both for a block index
within a file and for a block number on disk. Give the two concepts different names as well as different types
(`FileBlock`, `DiskBlock`). A newtype should expose the domain operations, not forward the inner type's whole API.

### Let the compiler find every site

When adding a variant to one of your enums means other code must change too, `match` on that enum exhaustively,
with no `_ =>` arm, so that every site that needs updating fails to compile. Where a dependency can't be checked
by the compiler, document it where a maintainer must look: "adding a variant also requires …" on the enum itself.

### Prefer empty over absent

When "none" and "empty" mean the same thing, use the empty value (an empty `Vec`, string or range) rather than
`Option<Vec<T>>` or an `is_set` flag, so that normal code handles the case without an `if`.

### Reach for typestate when correctness depends on order or mode

When a type's correct use depends on an ordering ("connect before send") or a mode, encode that in the type so the
invalid call does not compile. See the **Typestate Pattern** section below.

## Typestate Pattern

The typestate pattern encodes a value's current state in its *type* via a generic state parameter, so operations
that are invalid in a given state simply do not exist for that type — an invalid call is a compile error, not a
runtime `Err`, `panic!`, or silent misbehaviour. Invalid *transitions* become impossible to express. Reach for it
whenever a type's correct use depends on an ordering or a mode.

### When to reach for it

Design a type with typestate when you are about to write any of:

- A struct that would carry flag fields (`is_open`, `connected`, `initialized`, `started`, or a `state: State`
  enum) that every method has to check before deciding whether the operation is allowed.
- Methods that would return an error, `panic!`, or `debug_assert!` for the "wrong state" (e.g. "`send()` called
  before `connect()`", "`build()` called before all required fields set").
- An API whose docs would have to say "call `open()` before `read()`" or "call this first" — an ordering the
  caller must remember rather than one the compiler enforces.
- A builder that could produce an incomplete or invalid value, so `build()`/`finish()` has to fail at runtime when
  a required field was never set.

### Mechanics (how to write it)

- Add a generic state parameter `S` to the type, with one marker type per state. Markers are normally zero-sized
  structs (`struct Connected;`), so they add no runtime cost.
- Hold the parameter with `PhantomData<S>` — the state lives only in the type, not as data.
- **Make transitions consume `self`** — take `self` by value and return the type parameterised over the *next*
  state. The old-state value is moved out, so a stale handle in the previous state cannot be used afterwards.
- Put state-specific operations in `impl Foo<ThatState>`; put operations valid in every state in the generic
  `impl<S: State> Foo<S>`.
- Seal the state set with a [sealed trait] so downstream crates cannot invent new states — do this for public
  types whose states should be closed.
- If a transition can fail, hand the original value back on error (e.g. return `Result<Foo<Next>, (Foo<Prev>,
  Error)>`) so the caller can recover rather than lose the value.

[sealed trait]: https://rust-lang.github.io/api-guidelines/future-proofing.html

### BAD vs GOOD

```rust
// BAD: state tracked with a runtime flag; every method must guard, and
// misuse is only caught at runtime (or not at all).
struct Connection {
    socket: TcpStream,
    connected: bool,
}

impl Connection {
    fn send(&mut self, data: &[u8]) -> io::Result<()> {
        if !self.connected {
            return Err(io::Error::new(io::ErrorKind::NotConnected, "not connected"));
        }
        self.socket.write_all(data)
    }
}
// `conn.send(..)` before connecting compiles fine and fails at runtime.
```

```rust
// GOOD: state encoded in the type. `send` only exists on a connected
// connection, so calling it too early does not compile.
use std::marker::PhantomData;

mod sealed {
    pub trait Sealed {}
}
pub trait State: sealed::Sealed {}

pub struct Disconnected;
pub struct Connected;
impl sealed::Sealed for Disconnected {}
impl sealed::Sealed for Connected {}
impl State for Disconnected {}
impl State for Connected {}

pub struct Connection<S: State> {
    socket: TcpStream,
    _state: PhantomData<S>,
}

impl Connection<Disconnected> {
    pub fn connect(addr: &str) -> io::Result<Connection<Connected>> {
        let socket = TcpStream::connect(addr)?;
        Ok(Connection { socket, _state: PhantomData })
    }
}

impl Connection<Connected> {
    pub fn send(&mut self, data: &[u8]) -> io::Result<()> {
        self.socket.write_all(data)
    }

    // transition consumes `self`: the connected handle is gone afterwards
    pub fn disconnect(self) -> Connection<Disconnected> {
        Connection { socket: self.socket, _state: PhantomData }
    }
}
// There is no `connected` bool to check and no "not connected" error variant
// to handle: `Connection::connect(addr)?.send(data)?` is the only path.
```

### When you write a typestate, make sure

- State that gates which methods are legal lives in the type parameter, not in a runtime flag.
- Transitions consume `self` so a stale handle in the old state cannot linger.
- State markers are zero-sized; unused type parameters are held via `PhantomData`.
- The state set is sealed for public types whose states should not be extensible.
- State-specific methods are in `impl Foo<ThatState>`; shared methods in `impl<S: State> Foo<S>`.
- No "wrong state" error variants, `panic!`, or `debug_assert!` guards remain for cases the types now make
  impossible — if you left one in, the conversion is incomplete.
- Fallible transitions return the original value on error.

### Builders

For a builder, use typestate to guarantee required fields are set before `build()`, so `build()` can be infallible
and return the value directly instead of a `Result` that fails on a missing field. (A plain required-arguments
constructor is often the simpler answer — prefer it when the builder exists only to enforce required fields.)

```rust
// build() is infallible because the type cannot exist without `url`.
let req = RequestBuilder::new()      // Builder<NoUrl>
    .url("https://example.com")       // -> Builder<HasUrl>
    .build();                         // only defined on Builder<HasUrl>
```

### When NOT to use it

Typestate adds generic machinery and has real costs. Prefer a runtime model when:

- **State is chosen at runtime from external input** (parsed from a file, received over the wire) and the set is
  not known statically — a runtime `enum` is correct; typestate would force boxing/dynamic dispatch.
- **You need heterogeneous states in one collection** — `Vec<Connection<Connected>>` cannot also hold
  disconnected connections. If you need that, use an `enum` or `dyn`.
- **There are more than ~2–3 orthogonal state dimensions** — they multiply into unreadable generic bounds. Split
  the type or model the state at runtime instead.
- **The flow is trivial** and misuse is cheap to prevent another way. Weigh the generic noise against the bug
  class actually prevented.

## Don't duplicate

- **Repeated functions.** When you find yourself writing the same function a second time, pull it into a shared
  helper or an associated function rather than copy-pasting.
- **Near-identical functions.** When two functions you're writing differ only slightly, unify them with a
  parameter that varies the behaviour instead of maintaining two bodies — as long as the merged signature stays
  simple. If unifying takes a `bool` that picks between two bodies or several extra parameters, keep two
  functions that share a private helper instead.
- **Duplicated knowledge.** Two modules that both know a format or a representation are duplication even when
  their code differs. Put that knowledge in one module.
- **Repeated cleanup.** When the same cleanup precedes several early returns, use `?` with an RAII guard (`Drop`)
  or an inner function that returns `Result`, rather than copying the cleanup.
- **Not every repetition is worth a helper.** A one- or two-line snippet, or a helper that would need a complex
  signature to reach its surroundings, is often better left inline.

## Split and join deliberately

- Don't split a function just because it's long. A long function with a simple signature that reads block by block
  is fine.
- Extract a subtask only when the child can be understood without the parent and the parent without the child's
  body. If you find yourself flipping between two functions to understand either one, join them.
- Don't extract a one-line helper used in one place (such as a `log_x_error()` wrapper); the reader has to jump to
  it and back.
- Separate general-purpose mechanisms from special-purpose uses: a general mechanism shouldn't contain code for one
  of its callers. Push that code up into the caller's layer.
- Don't bundle loosely related state behind flags (a cursor and a selection plus `has_selection: bool`). Two
  simpler types are usually easier both to use and to implement.

## Ownership and borrowing

### Avoid unnecessary clone()

`clone()` is "Rust's duct tape" — easy to reach for to silence the borrow checker. Before you clone, ask: is it
necessary, or would a borrow do?

- Prefer passing by reference.
- When a clone is genuinely needed (e.g. data moved into a spawned task), add a comment saying why.

```rust
// BAD: clone without justification
let owned = data.clone();
expensive_operation(owned)

// GOOD: pass by reference
expensive_operation(data)

// GOOD: justified clone with comment
// Clone needed: data will be moved to spawned task
let owned = data.clone();
tokio::spawn(async move { process(owned).await });
```

### Take ownership in the signature, not with a clone

If a function stores its argument or moves it elsewhere, take it by value (`name: String`, `item: T`). Then the
caller decides whether to move or clone, and the cost is visible in the signature. Don't take `&str` and call
`to_string()` inside. If the function doesn't need ownership, borrow.

### Move out of `&mut` without cloning

To take a value out from behind `&mut`, leave something valid in its place: `mem::take` (leaves the `Default`),
`mem::replace` (leaves a value you give it), `mem::swap`, or `Option::take`. Use `clone_from` to reuse an
existing allocation when overwriting a value with a copy of another.

### Arc<Mutex<T>> usage

Reach for `Arc<Mutex<T>>` only when state is genuinely shared and mutated across owners. Prefer a single owner
when you can; for concurrent access, consider finer-grained alternatives such as `DashMap`.

```rust
// BAD: possibly unnecessary shared state
struct BadService {
    cache: Arc<Mutex<HashMap<String, Data>>>,
}

// GOOD: single owner when sharing is not required
struct GoodService {
    cache: HashMap<String, Data>,
}

// GOOD: finer-grained locking for concurrent access
use dashmap::DashMap;
struct ConcurrentService {
    cache: DashMap<String, Data>,
}
```

### Cow (copy-on-write)

Use `Cow<'_, str>` (and similar) to avoid allocating when the data often does not need to be owned.

```rust
use std::borrow::Cow;

// BAD: always allocates a new String
fn bad_process_name(name: &str) -> String {
    if name.is_empty() { "Unknown".to_string() }
    else { name.to_string() }  // unnecessary allocation
}

// GOOD: borrow when possible, allocate only when modification is needed
fn normalize_name(name: &str) -> Cow<'_, str> {
    if name.chars().any(|c| c.is_uppercase()) {
        Cow::Owned(name.to_lowercase())
    } else {
        Cow::Borrowed(name)
    }
}
```

`Cow` belongs in return types and in the fields of types used both as input and as output. It rarely belongs in an
argument: take `&str` or `String`, and let the caller allocate if needed. A type with `Cow` fields should offer
`into_owned(self) -> Foo<'static>`.

## Unsafe code (most critical)

Avoid `unsafe` — write the safe equivalent whenever one exists. Don't mark a function `unsafe` unless callers must
uphold real invariants the type system can't. When you do need `unsafe`, keep the boundary minimal and document it.
Read [SYSTEMS.md](SYSTEMS.md) before writing unsafe code. In short:

- Soundness depends on every piece of code that can touch the relevant fields, so keep them private, and wrap the
  unsafe code in one module with a safe interface.
- Stay sound when user code panics or `?` returns early: update lengths and invariants only after the data they
  describe is valid.
- Unsafe code may rely on the safety of safe code, never on its correctness. A user's `Hash`, `Ord` or `Deref` can
  be wrong.
- `unsafe impl<T: Send> Send for X<T>` carries bounds. Inside an `unsafe fn`, still use `unsafe {}` blocks.
- Run the tests under Miri when it's available.

### Every unsafe block gets a SAFETY comment

The comment must justify the operation in every build. A `debug_assert!` can back it up, but it isn't the proof,
because it doesn't run in release builds.

```rust
// BAD: no explanation
unsafe { *slice.get_unchecked(index) }

// BAD: the justification vanishes in release builds
debug_assert!(index < slice.len());
// SAFETY: We verified index < slice.len() via debug_assert.
unsafe { *slice.get_unchecked(index) }

// GOOD: the precondition is established on every build (as in `checked_get` below)
// SAFETY: `index < slice.len()`: `index` comes from `0..slice.len()` above.
unsafe { *slice.get_unchecked(index) }
```

### Every unsafe fn gets a `# Safety` doc section

```rust
// BAD: unsafe fn without safety documentation
unsafe fn bad_transmute<T, U>(t: T) -> U {
    std::mem::transmute(t)
}

// GOOD: documents invariants the caller must uphold
/// # Safety
/// - `T` and `U` must have the same size and alignment
/// - `T` must be a valid bit pattern for `U`
/// - No references to `t` may exist after this call
unsafe fn documented_transmute<T, U>(t: T) -> U {
    // SAFETY: Caller guarantees size/alignment match and bit validity
    std::mem::transmute(t)
}
```

### Wrap unsafe in a safe API

Encapsulate unsafe behind a safe public function that enforces the required invariants at the boundary.

```rust
pub fn checked_get(slice: &[u8], index: usize) -> Option<u8> {
    if index < slice.len() {
        // SAFETY: bounds check performed above
        Some(unsafe { *slice.get_unchecked(index) })
    } else {
        None
    }
}
```

### FFI boundaries

Wrap unsafe FFI calls in safe functions that validate inputs and translate error codes into `Result`. Use
`core::ffi` types (`c_int`, `CStr`), `#[repr(C)]` structs, and one distinct type per opaque handle. Never let a
panic unwind across `extern "C"`. Don't implement `Send`/`Sync` for a foreign type unless its library documents
that it's thread-safe. Edition 2024 requires `unsafe extern` blocks and `#[unsafe(no_mangle)]`. Details are in
[SYSTEMS.md](SYSTEMS.md#ffi-ch11).

```rust
unsafe extern "C" { // `extern "C"` before edition 2024
    fn external_function(ptr: *const u8, len: usize) -> i32;
}

pub fn safe_wrapper(data: &[u8]) -> Result<i32, Error> {
    // SAFETY: data.as_ptr() is valid for data.len() bytes,
    // and external_function only reads from the buffer.
    let result = unsafe { external_function(data.as_ptr(), data.len()) };
    if result < 0 { Err(Error::from_code(result)) } else { Ok(result) }
}
```

## Error handling

### Reduce where errors must be handled

Every error variant and every panic is part of the interface, and error paths are the least-tested code. Before
adding one, try these in order (examples in [DESIGN.md](DESIGN.md#define-errors-out-of-existence-ch10)):

1. **Define it away.** Redefine the operation so the condition is normal: "ensure absent" succeeds when the item
   is already absent, and a range query returns the overlap (possibly empty) instead of failing on out-of-range
   bounds. Typestate defines wrong-state errors away.
2. **Mask it low.** Recover inside the module when every caller would do the same (retry, fall back).
3. **Aggregate it high.** Propagate with `?` to a single handler (the request loop, `main`) instead of handling
   the error at each call site, and build the human-readable message where the error is created.
4. **Crash on bugs.** A broken internal invariant is a bug: panic with a message naming the invariant rather
   than adding a variant that no caller can act on.

Add a variant only when a caller would handle it differently from the others. Don't overdo it, though: never
swallow an error the caller needs to know about.

### Library vs application error types

- **Libraries**: define structured, matchable errors with `thiserror` so callers can match on variants.
- **Applications**: use `anyhow` with `.context()` for ergonomic propagation.

```rust
// BAD: library using anyhow -- callers cannot match on error variants
pub fn parse_config(s: &str) -> anyhow::Result<Config> { /* ... */ }

// GOOD: library with thiserror
#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("invalid syntax at line {line}: {message}")]
    Syntax { line: usize, message: String },
    #[error("missing required field: {0}")]
    MissingField(String),
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

pub fn parse_config(s: &str) -> Result<Config, ConfigError> { /* ... */ }
```

### Enumerate or make opaque

Choose by how callers will react to the error (details in [API.md](API.md#errors-ch4)):

- Enumerate the causes that callers will handle differently.
- When callers can only report the error, a library can expose one opaque error type instead: private fields,
  methods for the interesting facets (a line number, a status code), and an implementation of `Error`. Don't
  return `anyhow::Error` or `Box<dyn Error>` from a library API; neither implements `std::error::Error`.
- Keep `Result` small by boxing large error payloads (clippy's `result_large_err`).
- `Result<T, ()>` is not `Option<T>`: an `Err` is a failure to handle, while `None` just means there is nothing to
  return. Use a unit struct that implements `Error` rather than `()`, and `std::convert::Infallible` for a
  `Result` that can't fail.

### Preserve error context

```rust
// BAD: original error is lost
operation().map_err(|_| anyhow!("failed"))?;

// GOOD: use .context() to preserve the error chain
operation().context("failed to perform operation")?;

// GOOD: use .with_context() for lazy formatting
operation().with_context(|| format!("failed to process file: {}", filename))?;
```

### Error type design

- Use `#[source]` to preserve the error chain.
- Implement `From` for common conversions.

```rust
#[derive(Debug, thiserror::Error)]
pub enum ServiceError {
    #[error("database error")]
    Database(#[source] sqlx::Error),

    #[error("network error: {message}")]
    Network {
        message: String,
        #[source]
        source: reqwest::Error,
    },

    #[error("validation failed: {0}")]
    Validation(String),
}
```

---

## Documentation and naming

Comments record what the code can't express: the abstraction, the precise contract, and the reasons. Details and
examples are in [DESIGN.md](DESIGN.md#documentation-ch1213-1516).

- **Write the `///` doc before the body.** If it's hard to make the doc both short and complete, or a caller
  needs implementation details to use the item, rework the design before writing the code.
- **Interface docs say what, not how.** For a type: what one value represents, and its limitations. For a
  function: its behaviour as the caller sees it; arguments and return value; side effects; `# Errors`,
  `# Panics`, `# Safety`, `# Cancel Safety`; preconditions. Implementation notes go in `//` inside the body.
- **Be precise**: units, inclusive or exclusive bounds, what `None`/empty/zero means, who owns or closes a
  resource, invariants. Describe fields as what they represent, not as which code updates them.
- **Don't repeat the code or the name** (`/// Returns the count.` on `fn count`). Implementation comments explain
  what a block does and why, one per block; a workaround cites the reason or issue.
- **Document each decision once**, where a maintainer will look. Elsewhere, link to it (``[`Type::method`]``); link
  to external specs rather than restating them; don't re-describe a callee at its call site.
- **Document nonobvious control flow**: say when, and on which thread or task, a callback, registered handler,
  spawned task, or side-effecting `Drop` runs.
- **Names are precise and consistent.** Avoid `data`, `info`, `status`, `manager`, `tmp`, and a bare `count`.
  Booleans are predicates (`cursor_visible`). Use one name per concept across the crate, and share a base name
  across related pairs (`src_block`/`dst_block`). The farther a name's uses are from its declaration, the longer it
  should be. Follow the Rust API Guidelines naming conventions (`as_`/`to_`/`into_`, no `get_` prefix). If a
  name is hard to pick, the item probably does two jobs.

## Testing

Details are in [PROJECT.md](PROJECT.md#tests-ch6).

- Unit tests sit beside the code in a `#[cfg(test)] mod tests`. Integration tests and doctests exercise only the
  public API.
- To inspect internals from tests, add `#[cfg(test)] pub(crate)` accessors rather than widening visibility.
- Test invariants with property tests against a simple reference implementation, and fuzz parsers.
- Show that a misuse doesn't compile with a `compile_fail` doctest, and confirm it fails for the right reason.
- Benchmarks use `criterion` and `std::hint::black_box`, with only the measured code inside the loop.

---

## Performance

### Measure before adding complexity

Simple code is usually fast. Know what is fundamentally expensive (network round trips, disk and syscall I/O,
heap allocation, cache misses) and pick the naturally efficient option when it's just as simple: `HashMap` unless
you need ordering, `Vec<T>` rather than `Vec<Box<T>>`. Add complexity for speed only with a measurement behind it
(`cargo bench`/criterion, a profiler): keep the baseline, and back out a change that doesn't measurably help.
When optimizing a hot path, check for all special cases with one test up front and move their handling into a
separate `#[cold]` function ([example](DESIGN.md#designing-for-performance-ch20)).

### Avoid unnecessary collect()

Don't materialize an intermediate `Vec` only to iterate it again — chain lazily.

```rust
// BAD: unnecessary intermediate allocation
items.iter().filter(|x| **x > 0).collect::<Vec<_>>().iter().sum()

// GOOD: lazy iteration
items.iter().filter(|x| **x > 0).copied().sum()
```

### String building

Avoid repeated allocations in loops — use `.join("")`, `String::with_capacity`, or `write!`.

```rust
// BAD: re-allocates on every iteration
let mut s = String::new();
for item in items { s = s + item; }

// GOOD: join
items.join("")

// GOOD: pre-allocate
let total_len: usize = items.iter().map(|s| s.len()).sum();
let mut result = String::with_capacity(total_len);
for item in items { result.push_str(item); }
```

### Prefer &str over String

Strings allocate on the heap. Take `&str` in signatures when you don't need ownership, and use `&'static str` for
constants so they live in the text segment rather than being allocated.

### Avoid unnecessary allocations

```rust
// BAD: allocating a Vec just to check if any element matches
let filtered: Vec<_> = items.iter().filter(|i| i.is_valid()).collect();
!filtered.is_empty()

// GOOD: use iterator method
items.iter().any(|i| i.is_valid())

// BAD: String::from for a static string when no owned String is needed
fn bad_static() -> String { String::from("error message") }

// GOOD: return &'static str
fn good_static() -> &'static str { "error message" }
```

### Small wins from std

- Wrap anything that receives many small reads or writes in `BufReader`/`BufWriter`.
- Use `Vec::swap_remove` (O(1)) when element order doesn't matter, and `VecDeque` for queues and stacks used at
  both ends.
- Keep values that are moved around small: box large error payloads and large enum variants (clippy warns by
  default with `result_large_err` and `large_enum_variant`).
- In a generic function, move the type-independent work into a non-generic inner function, so it is compiled
  once rather than once per instantiation.

---

## Trait design

### Don't over-abstract

Don't create a trait for everything — concrete types are simpler and faster. Introduce a trait only when you
genuinely need polymorphism. A trait gets deeper the more distinct implementations it has; one with a single impl
is usually a shallow layer. The same goes for design patterns: don't force a builder, wrapper, visitor, or
observer onto a problem it doesn't fit.

- Default methods are implementation inheritance. Write them only against the documented contract of the
  required methods, so an implementor doesn't have to read them to know what to override.
- Don't emulate inheritance with `Deref`; only transparent, smart-pointer-like wrappers should implement it. Hold
  the shared part as a field and expose the operations you mean.
- Use an associated type when a type has one natural implementation of the trait, and a type parameter only when
  several make sense (`From<T>`).
- Keep a trait object-safe if users may want `dyn Trait`: put generic convenience methods behind
  `where Self: Sized`.
- For a new trait, add blanket impls for `&T`, `&mut T` and `Box<T>` where the receivers allow it. Seal a trait
  only when outside implementations make no sense. More in [API.md](API.md#traits-ch23-13).

```rust
// BAD: trait soup -- not Java, no need to interface everything
trait Processor { fn process(&self); }
trait Handler { fn handle(&self); }
trait Manager { fn manage(&self); }

// GOOD: concrete type when polymorphism is not needed
struct DataProcessor { config: Config }
impl DataProcessor {
    fn process(&self, data: &Data) -> Result<Output> { /* ... */ }
}
```

### Trait objects vs generics

- In a library, default to **generics** (static dispatch) for performance and inlining; the caller can still pass
  a trait object, but a `dyn` parameter forces dynamic dispatch on every caller.
- In a binary, `dyn Trait` is often the simpler choice and compiles faster, at a usually marginal runtime cost.
- Make an argument generic only where callers will reasonably pass several types. Making a concrete argument
  generic later can break callers' type inference.
- Use **trait objects** (`dyn Trait`) for heterogeneous collections or where dynamic dispatch is required.
- Use `impl Trait` in return position when the caller doesn't need the concrete type.

```rust
// Prefer generics
fn good_process<H: Handler>(handler: &H) { handler.handle(); }

// Trait objects for heterogeneous collections
fn store_handlers(handlers: Vec<Box<dyn Handler>>) { /* ... */ }

// impl Trait return type
fn create_handler() -> impl Handler { ConcreteHandler::new() }
```

## Macros

- Prefer functions and generics; if the code varies by type, use generics. Use `macro_rules!` for repetitive,
  structurally similar code that generics can't express.
- In exported macros, use `$crate::` and `::core::` paths, never the caller's imports.
- A procedural macro needs a strong reason, because it costs compile time. Report its errors with
  `compile_error!` spanned on the offending input. More in [PROJECT.md](PROJECT.md#macros-ch7).

## Concurrency

- Start with the simplest design (threads with channels, or a `Mutex`), measure, and fix only the measured
  bottleneck, for example by splitting a lock or adding a thread, before reaching for lock-free code.
- Choose the model by the work:
  - shared state when updates don't commute;
  - a worker pool (`rayon`) for the same operation over different data;
  - an actor (a task that owns a resource and serves requests from a channel) per independent resource.
- Keep critical sections short. When you split a lock, always take the parts in the same order.
- Concurrency has overhead: measure the parallel version against the sequential one.
- For atomics, memory orderings, and testing with Loom and TSan, see
  [SYSTEMS.md](SYSTEMS.md#atomics-and-lock-free-code-ch10).

## Async code

### Use async only when it pays

Async adds machinery. Use it when the program waits on many I/O operations at once; a synchronous interface is
simpler otherwise. For parallelism, futures must be `Send` and spawned as separate tasks: one big future is polled
by one thread. Spawned tasks make progress only while the runtime runs.

### No blocking in an async context

Blocking calls (`std::fs`, `std::thread::sleep`) in an async fn starve other tasks on the runtime.

```rust
// BAD: blocking in async
async fn bad_async() {
    let data = std::fs::read_to_string("file.txt").unwrap();  // blocks!
    std::thread::sleep(Duration::from_secs(1));                // blocks!
}

// GOOD: use async APIs
async fn good_async() -> Result<String> {
    let data = tokio::fs::read_to_string("file.txt").await?;
    tokio::time::sleep(Duration::from_secs(1)).await;
    Ok(data)
}

// GOOD: use spawn_blocking for unavoidable blocking work
async fn with_blocking() -> Result<Data> {
    let result = tokio::task::spawn_blocking(|| {
        expensive_cpu_computation()
    }).await?;
    Ok(result)
}
```

### Don't hold a std Mutex across .await

Holding a `std::sync::Mutex` guard across an `.await` can deadlock.

```rust
// BAD: holding std::sync::Mutex across .await
async fn bad_lock(mutex: &std::sync::Mutex<Data>) {
    let guard = mutex.lock().unwrap();
    async_operation().await;  // holding lock across await!
    process(&guard);
}

// GOOD option 1: minimize lock scope
async fn good_lock_scoped(mutex: &std::sync::Mutex<Data>) {
    let data = {
        let guard = mutex.lock().unwrap();
        guard.clone()  // release lock immediately
    };
    async_operation().await;
    process(&data);
}

// GOOD option 2: use tokio::sync::Mutex (designed for holding across await)
async fn good_lock_tokio(mutex: &tokio::sync::Mutex<Data>) {
    let guard = mutex.lock().await;
    async_operation().await;  // OK
    process(&guard);
}
```

**Selection guide:**
- `std::sync::Mutex`: low contention, short critical sections, never across `.await`
- `tokio::sync::Mutex`: when holding across `.await` is required or under high contention

### Keep futures cooperative and small

- A future should never run long between `.await`s: as a rule of thumb, no more than about a millisecond without
  returning `Pending`. Move CPU-heavy work to `spawn_blocking` or a thread pool, and yield
  (`tokio::task::yield_now`) inside long loops.
- Locals held across an `.await` live inside the future, so a big buffer makes every move of the future a big
  `memcpy`. `Box::pin` a large future that gets moved around (clippy's `large_futures`, opt-in, finds them).
- Pin with `std::pin::pin!` or `Box::pin`, and project pinned fields with `pin-project`(`-lite`). Don't write
  `Pin::new_unchecked` yourself.
- In a hand-written `Future::poll`, return `Pending` only after arranging a wake-up (an inner future returned
  `Pending`, or you stored the `Waker`). Don't poll a future again after it returns `Ready` unless it is fused.
- A library that should work on any runtime takes generic I/O traits (`AsyncRead`/`AsyncWrite`) rather than one
  runtime's types, and never starts a runtime of its own behind the caller's back.

### Async trait methods

```rust
// Rust 1.75+: native async trait methods
trait Repository {
    async fn find(&self, id: i64) -> Option<Entity>;
    fn find_many(&self, ids: &[i64]) -> impl Future<Output = Vec<Entity>> + Send;
}

// For dyn-compatible scenarios, use Pin<Box<dyn Future>>
trait DynRepository: Send + Sync {
    fn find(&self, id: i64) -> Pin<Box<dyn Future<Output = Option<Entity>> + Send + '_>>;
}
```

---

## Cancellation safety

When a future is dropped at an `.await` point, what state is it in?

- **Cancel-safe**: can be dropped at any await point without harm.
- **Cancel-unsafe**: cancellation may cause data loss or inconsistent state.

```rust
// BAD: cancel-unsafe -- if cancelled after receive_data, ack is never sent
async fn cancel_unsafe(conn: &mut Connection) -> Result<()> {
    let data = receive_data().await;
    conn.send_ack().await;
    Ok(())
}

// GOOD: use transactions or atomic operations for consistency
async fn cancel_safe(conn: &mut Connection) -> Result<()> {
    let transaction = conn.begin_transaction().await?;
    let data = receive_data().await;
    transaction.commit_with_ack(data).await?;
    Ok(())
}
```

### In select!

- `read_exact` is **not** cancel-safe: partially read bytes are lost when the future drops.
- `read` **is** cancel-safe: unread data stays in the stream.
- When you need a cancel-unsafe operation in `select!`, move it into a task and select on the `JoinHandle`.

```rust
// BAD: cancel-unsafe future in select!
select! {
    result = stream.read_exact(&mut buffer) => { /* ... */ }
    _ = tokio::time::sleep(Duration::from_secs(5)) => { /* timeout */ }
}

// GOOD: cancel-safe API
select! {
    result = stream.read(&mut buffer) => {
        match result {
            Ok(0) => break,
            Ok(n) => handle_data(&buffer[..n]),
            Err(e) => return Err(e),
        }
    }
    _ = tokio::time::sleep(Duration::from_secs(5)) => {
        println!("Timeout, retrying...");
    }
}

// GOOD: use tokio::pin! for futures reused across loop iterations
let sleep = tokio::time::sleep(Duration::from_secs(10));
tokio::pin!(sleep);
loop {
    select! {
        _ = &mut sleep => { break; }
        data = receive_data() => { process(data).await; }
    }
}
```

### Document cancellation safety

Every public async function should state its cancel safety:

```rust
/// # Cancel Safety
///
/// This method is **not** cancel safe. If cancelled while reading,
/// partial data may be lost and the stream state becomes undefined.
/// Use `read_message_cancel_safe` if cancellation is expected.
async fn read_message(stream: &mut TcpStream) -> Result<Message> { /* ... */ }
```

---

## spawn vs await

### When to spawn

- Don't spawn a simple operation you can just await — spawning adds overhead and loses structured concurrency.
- Spawn for genuinely parallel execution (multiple independent I/O operations).
- Spawn for fire-and-forget background tasks.

```rust
// BAD: unnecessary spawn
let handle = tokio::spawn(async { simple_operation().await });
handle.await.unwrap();  // why not just await directly?

// GOOD: direct await
simple_operation().await;

// GOOD: spawn for parallel execution
let task1 = tokio::spawn(fetch_from_service_a());
let task2 = tokio::spawn(fetch_from_service_b());
let (result1, result2) = tokio::try_join!(task1, task2)?;
```

### The 'static requirement

Spawned futures must be `'static`. Options: clone the data, share it with `Arc`, or use a scoped-task crate
(`tokio-scoped`, `async-scoped`).

```rust
// BAD: borrowing non-'static data in spawn
tokio::spawn(async { process(data).await });  // Error: `data` is not 'static

// GOOD: clone or Arc
let owned = data.clone();
tokio::spawn(async move { process(&owned).await });

let data = Arc::clone(&data);
tokio::spawn(async move { process(&data).await });
```

### Handle JoinHandle results

Don't silently discard a task's panic or error.

```rust
// BAD: ignoring spawn errors
let _ = handle.await;

// GOOD: handle both task errors and join errors
match handle.await {
    Ok(Ok(result)) => { /* task completed successfully */ }
    Ok(Err(e))     => { /* task returned an error */ }
    Err(join_err)  => {
        if join_err.is_panic() {
            error!("Task panicked: {:?}", join_err);
        }
    }
}
```

### Prefer structured concurrency

Prefer `join!` / `try_join!` over raw `spawn` when tasks share one lifetime scope. With `try_join!`, if any task
fails the others are cancelled. When you do `spawn`, plan the task's lifecycle and shutdown (graceful wait or
abort).

```rust
// GOOD: structured concurrency
tokio::try_join!(fetch_a(), fetch_b(), fetch_c())
```
