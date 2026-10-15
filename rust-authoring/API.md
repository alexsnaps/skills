# Designing Rust interfaces

Guidance distilled from Jon Gjengset's *Rust for Rustaceans* (chapter numbers point at the book), updated where
the language has moved on since 2021. Read it before you add or change a public type, trait, signature, error type
or crate-level docs. Internal module boundaries are interfaces too, just with fewer users. Whether a module is
worth having at all (deep vs. shallow, information hiding) is covered in [DESIGN.md](DESIGN.md); this file covers
the Rust mechanics of a good interface. As everywhere in this skill, a strong local convention wins.

An interface should be **unsurprising, flexible, obvious and constrained** (Ch3).

## Every signature is a contract (Ch3)

A signature states requirements (argument types, trait bounds) and makes promises (return types, trait impls,
auto traits). Relaxing a requirement or adding a promise is usually backward compatible; tightening a requirement
or withdrawing a promise breaks callers. Ask for no more than you need, and promise no more than you can keep:

```rust
fn frobnicate1(s: String) -> String                   // caller must allocate; we must always return an owned String
fn frobnicate2(s: &str) -> Cow<'_, str>                // borrows; may return borrowed or owned, but always a Cow
fn frobnicate3(s: impl AsRef<str>) -> impl AsRef<str>  // fewest requirements, fewest promises
```

None of these is best in general. Take `String` if you need ownership anyway; return `Cow` if callers benefit
from the borrowed fast path. Choose deliberately, because changing it later breaks callers.

## Be unsurprising (Ch3)

- **Reuse names with their usual meaning.** `iter` borrows and yields an iterator, `into_inner` consumes, and a
  `FooError` implements `std::error::Error`. Anything named like a std item must behave like it.
- **Implement the standard traits eagerly on public types.** Downstream crates can't add them (orphan rule):
  - `Debug` on every type. Derive it, or use `Formatter::debug_struct`/`debug_map` to show only some fields.
  - `Send` and `Sync`, unless there's a reason not to. If a type isn't, document why.
  - `Clone` and `Default` where they make sense. If a type can't have them, say so in its docs.
  - `PartialEq`, which enables `assert_eq!`. `PartialOrd`, `Hash`, `Eq` and `Ord` when the type could be a map key
    or be sorted, and only when their semantic requirements hold.
  - `serde::{Serialize, Deserialize}` behind an optional `serde` feature.
  - **Not** `Copy` by default. It changes move semantics, and removing it later is a breaking change.
- **`#[derive]` adds a bound on every type parameter.** `#[derive(Clone)] struct Shared<T>(Arc<T>)` is only
  `Clone` when `T: Clone`. Implement the trait by hand when a field (`Arc<T>`, `PhantomData<T>`) doesn't need the
  bound.
- **For a new trait**, add blanket impls for `&T`, `&mut T` and `Box<T>` where the receivers allow it, so callers
  can pass references. For a collection, implement `IntoIterator` for `&Coll` and `&mut Coll` so that
  `for x in &coll` works.
- **Wrappers.** A transparent, smart-pointer-like wrapper may implement `Deref`/`AsRef`, and `From` in both
  directions. Such a type should avoid inherent methods that could shadow the target's; use associated functions
  instead (`Wrapper::frob(&w)`, as in `Arc::clone(&a)`). Implement `Borrow` only for types that behave
  identically (same `Hash`, `Eq` and `Ord`), as `String` and `str` do. A domain newtype is not a transparent
  wrapper: see [DESIGN.md](DESIGN.md#different-layer-different-abstraction-ch7).

## Be flexible, deliberately (Ch1–3)

- **Generic arguments** belong where callers will reasonably and frequently pass other types (`impl AsRef<Path>`,
  `impl Into<String>`, `impl IntoIterator<Item = T>`), not everywhere: a signature full of type parameters is hard
  to read. Making an existing concrete argument generic later can break callers' type inference.
- **Static vs. dynamic dispatch.** Libraries default to generics, which still let the caller choose `dyn`.
  Binaries can often prefer `&dyn Trait`/`Box<dyn Trait>` for simpler code and faster compiles. Never force `dyn`
  on a library caller who may be in a hot path.
- **Owned vs. borrowed.** If the function needs ownership (it stores the value or moves it to another thread),
  take it by value so the caller controls the allocation; don't take `&T` and clone inside. If it doesn't need
  ownership, borrow. Pass small `Copy` types by value, but not large ones (`[u8; 8192]` is `Copy`). If ownership
  depends on the data, return `Cow`. If lifetimes make an API painful to use, owning cheap data can be the better
  trade.
- **Lifetimes.** One lifetime parameter is usually enough. Add a second only when a method returns references tied
  to just one of the inputs. Keep types covariant: a field like `&'a mut &'a str` makes the type invariant and
  rejects code users expect to compile.
- **Returning `impl Trait`** hides helper types (iterators, futures) so you can change them freely. Auto traits
  (`Send`, `Sync`, `Unpin`) still leak through and are part of the contract. Since edition 2024, the hidden type
  captures every in-scope lifetime unless you narrow it with `+ use<..>`.

## Traits (Ch2–3, 13)

- **Associated type or type parameter?** Use an associated type when a type has one natural implementation
  (`Iterator::Item`). Use a type parameter only when several implementations per type make sense (`From<T>`,
  `PartialEq<Rhs>`).
- **Object safety is part of the contract.** If users may want `dyn YourTrait`, keep the trait object-safe: put
  generic convenience methods behind `where Self: Sized`, or move the generics onto the trait. Adding a method that
  breaks object safety is a breaking change.
- **Extension traits** add methods to a trait you don't own: `trait FooExt: Foo` with only provided methods, plus
  `impl<T: Foo + ?Sized> FooExt for T {}`.
- **Seal** a trait (with a private supertrait) only when outside implementations make no sense. Sealing lets you
  add methods later. Document that it's sealed.
- **Monomorphization cost.** In a generic function, move the type-independent bulk into a non-generic inner
  function so it's compiled once:

```rust
pub fn open<P: AsRef<Path>>(path: P) -> io::Result<File> {
    fn inner(path: &Path) -> io::Result<File> {
        File::open(path) // the real, type-independent work: compiled once
    }
    inner(path.as_ref())
}
```

## Destructors that can fail or block (Ch3)

`Drop` can't return an error or `.await`. For a type that flushes, closes, or shuts down a connection:

- Do best-effort cleanup in `Drop`, ignoring errors there; at least you tried.
- Also offer an explicit destructor, such as `fn close(self) -> Result<(), E>` or `async fn shutdown(self)`, and
  point to it from the type's docs.
- To move fields out in the explicit destructor while `Drop` exists, make them takeable: `Option` plus `take()`, or
  `mem::take` for fields with a cheap default. Reach for `ManuallyDrop` (which needs unsafe) only when the code is
  simple enough to check.

## Make misuse hard (Ch3)

- **Semantic types.** Don't take runs of `bool` arguments; use two-variant enums (`DryRun::Yes`,
  `Overwrite::No`). Newtypes carry units. If one argument only matters when another is set (a flag plus the data
  it enables), merge the two into one enum whose variant carries the data.
- **Typestate** for ordering and modes: see the Typestate Pattern in [SKILL.md](SKILL.md#typestate-pattern).
- **`#[must_use]`** only where ignoring the value is very likely a bug.
- **Names that warn.** A dangerous operation's name should make the reader open its docs.

## Errors (Ch4)

Ask how callers will react to a failure; the answer decides how to represent it.

- **Enumerate** when callers will handle causes differently: in `CopyError::In(io::Error)` vs.
  `Out(io::Error)`, a failing disk calls for different action than a disconnected client.
- **Make it opaque** when callers can't act on the cause beyond reporting it: one error type with private fields
  that exposes interesting facets (a line number, a status code) through methods, rather than a long public enum.
  `Box<dyn Error + Send + Sync>` is the extreme, and it doesn't itself implement `Error`, so a library that erases
  errors should wrap it in its own type that does.
- **Every error type** implements `std::error::Error` (with `source()` returning the underlying error) and
  `Debug`. Its `Display` is one line, lowercase, with no trailing punctuation, so it composes into larger messages.
  It is `Send + Sync`, and `'static` where possible (`'static` is what makes downcasting work). Keep it small: box
  large payloads so `Result` stays cheap on the happy path (clippy's `result_large_err` warns about this by
  default).
- `Result<T, ()>` and `Option<T>` mean different things: `Err` is a failure to handle, `None` is "nothing to
  return". Don't collapse one into the other, and prefer a unit error struct that implements `Error` over `()`.
- A `Result` that can never fail (to satisfy a trait signature) uses `std::convert::Infallible` as its error type.
- **Conversions**: implement `From`, and use `Into` in bounds (`fn f(x: impl Into<Foo>)`). `?` converts errors
  with `From`.

```rust
/// The input or the output stream failed while copying.
#[derive(Debug)]
pub enum CopyError {
    In(io::Error),
    Out(io::Error),
}

impl fmt::Display for CopyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CopyError::In(_) => f.write_str("failed to read from input"),
            CopyError::Out(_) => f.write_str("failed to write to output"),
        }
    }
}

impl std::error::Error for CopyError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            CopyError::In(e) | CopyError::Out(e) => Some(e),
        }
    }
}
```

`thiserror` generates this boilerplate.

## Documentation (Ch3, 6)

- Document every way the code can surprise: `# Panics` (and when), `# Errors` (which cases), `# Safety` (what the
  caller must guarantee).
- Put an end-to-end example in the crate and module docs; it teaches more than per-method examples. Skip examples
  that only show that `len` returns the length.
- Group related items into modules, link them with intra-doc links, point the crate docs at the common entry
  points, and link to external specs. `#[doc(alias = "...")]` makes an item findable under other names.
  `#[doc(hidden)]` items (needed by macros, or kept for legacy reasons) still get docs.
- Doctests are integration tests: they see only the public API. End a fallible example with `Ok::<(), Error>(())`
  so that `?` works. Hide setup lines with `#` sparingly, since a copied example must still work. Use `no_run` for
  examples that need a network, and `compile_fail` to show that a misuse doesn't compile, after confirming it
  fails for the reason you intend.

## Evolving a public API without breaking it (Ch3, 5)

- **Expose less.** Default to `pub(crate)` or `pub(in path)`; every `pub` item is a promise.
- **`#[non_exhaustive]`** on public enums and structs you expect to grow. It costs users exhaustive matching and
  struct literals, so leave it off types that are stable. Without it, adding a private field to a struct whose
  fields are all public (or to a unit struct) is a breaking change.
- **Trait impls.** Adding a blanket impl, implementing a foreign trait for an existing type, or even implementing
  your own trait for an existing type (method calls can become ambiguous under glob imports) can break downstream
  code. Adding a trait method without a default breaks implementors; adding one with a default is fine.
- **Foreign types in your API** tie your semver to the dependency's: upgrading its major version becomes a
  breaking change for you. Wrap them in a newtype or return `impl Trait`, unless exposing them is the point.
- **Auto traits are a hidden promise.** A private field that stops being `Send` makes your public type `!Send`.
  Pin the promise with a compile-time test:

```rust
#[test]
fn public_types_are_normal() {
    fn is_normal<T: Sized + Send + Sync + Unpin>() {}
    is_normal::<MyType>();
}
```

## Patterns worth knowing (Ch13)

- **Index "pointers"**: to index the same data several ways, or to build a graph, without `Rc` or
  self-references, store the values in a `Vec` and keep indices elsewhere. Deletions must fix up every index that
  refers to a moved element (`swap_remove` moves one).
- **Drop guards** run cleanup even when a panic unwinds. Bind the guard to a named variable (`let _guard = ...`):
  `let _ = ...` drops it immediately.
- **`Cow` in input/output types.** A struct used both as an argument and as a result can hold `Cow<'a, str>`
  fields, so callers pass borrowed data and results come back `'static`. Provide
  `into_owned(self) -> Foo<'static>`.
- **Preludes** are for crates with many items (often extension traits) that are used together. Glob-import only
  from a crate's prelude.
