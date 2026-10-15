# Designing for low complexity

Rust-specific guidance distilled from John Ousterhout's *A Philosophy of Software Design* (chapter numbers point
at the book). Read it before you design a new public type, trait, module boundary or error enum, and whenever
you notice one of the [red flags](SKILL.md#red-flags). As everywhere in this skill, a strong local convention
wins over a rule here.

## The yardstick: complexity (Ch2–3)

Complexity is anything that makes code hard to understand or change. Judge a design choice by its three
symptoms:

- **Change amplification**: how many places must change if this decision changes?
- **Cognitive load**: what must a caller or maintainer know to use or modify it?
- **Unknown unknowns**: would a maintainer even know what else to change? This is the worst of the three. In
  Rust, turn it into a compile error (exhaustive matches, distinct types) wherever you can.

Its causes are **dependencies** (code that can't be understood or changed in isolation) and **obscurity**
(important information that isn't obvious). Complexity accrues in small increments, so no shortcut is too small
to matter: working code isn't enough. Before you're done, remove the kludges, special cases and flags you added
to get it working.

## Make modules deep (Ch4)

A module (function, type, `mod`, crate) is deep when its interface is much simpler than what it does.

- The interface is everything a caller must know: the signature *and* the informal contract (ordering, side
  effects, panics, which errors mean what). Move the informal contract into types where you can (typestate,
  newtypes, `#[must_use]`); document the rest.
- Don't split by size. Many tiny types, modules or functions, each with its own interface, add up to more
  complexity than one deeper item ("classitis").
- Make the common case need the least. If almost every caller wants a behaviour, make it the default rather
  than a separate wrapper or flag the caller must remember.

```rust
// BAD: shallow; the "abstraction" takes longer to name and document than its body.
fn add_null_value_for_attribute(data: &mut HashMap<String, Option<String>>, attribute: String) {
    data.insert(attribute, None);
}
```

## Hide information; don't leak it (Ch5)

Each module should own a few design decisions (a data structure, a wire or file format, an algorithm, a policy)
that no other module depends on.

- Private fields are necessary, not sufficient: a getter that returns `&HashMap<..>`, or a setter per field,
  exposes the representation as much as `pub` would.
- **Leakage**: one decision known in two modules, such as a reader and a writer of the same format that both
  hard-code its field order, even when they share no code. Put the knowledge in one module, or merge the two.
- **Temporal decomposition**: don't structure modules by execution order (`read` → `parse` → `write`) when the
  steps share knowledge. Structure them by what each piece knows.
- Defaults are partial hiding: in the common case callers never learn the knob exists.
- Within an `impl`, minimise the number of methods that touch each field.
- Don't hide what callers need: if different callers genuinely need different settings, expose them.

```rust
// BAD: leaks the representation; every caller depends on it being a HashMap,
// and must do the lookup and conversion itself.
impl Request {
    pub fn params(&self) -> &HashMap<String, String> { &self.params }
}

// GOOD: the representation, where a parameter came from, and URL decoding all stay hidden.
impl Request {
    /// Value of the query or form parameter `name`, URL-decoded; `None` if absent.
    pub fn param(&self, name: &str) -> Option<&str> {
        self.params.get(name).map(String::as_str)
    }

    /// Parameter `name` parsed as `T`.
    ///
    /// # Errors
    /// [`ParamError::Missing`] if absent, [`ParamError::Invalid`] if it doesn't parse as `T`.
    pub fn param_as<T: FromStr>(&self, name: &str) -> Result<T, ParamError> { /* ... */ }
}
```

```rust
// BAD: temporal decomposition. Reading needs Content-Length, so both types parse headers.
let raw = RequestReader::new(&mut stream).read()?;
let req = RequestParser::parse(&raw)?;

// GOOD: one type owns the HTTP request format.
let req = Request::read_from(&mut stream)?;
```

## Somewhat general-purpose interfaces (Ch6)

Implement what today needs, but phrase the interface in the module's own terms rather than the caller's feature.

- Ask: what is the simplest interface that covers all current needs? In how many situations will this function
  be used? (One call site suggests it's too special.) Is it easy to use for today's need? (If callers must write
  loops and glue, it's too low-level.)
- Fewer, deeper functions beat many special ones, but not if you get there by piling on parameters.

```rust
// BAD: the text buffer knows about the editor's keys and selection.
impl Text {
    pub fn backspace(&mut self, cursor: Cursor) { /* ... */ }
    pub fn delete_key(&mut self, cursor: Cursor) { /* ... */ }
    pub fn delete_selection(&mut self, selection: &Selection) { /* ... */ }
}

// GOOD: general text operations; the UI decides, visibly, what a key does.
impl Text {
    pub fn insert(&mut self, at: Position, text: &str) { /* ... */ }
    pub fn delete(&mut self, range: Range<Position>) { /* ... */ }
    pub fn offset(&self, from: Position, chars: isize) -> Position { /* ... */ }
}
// backspace, in the UI module:
text.delete(text.offset(cursor, -1)..cursor);
```

## Different layer, different abstraction (Ch7)

Each layer should change the abstraction. When adjacent layers look alike, one of them isn't earning its keep.

- **Pass-through methods**: a type whose methods mostly forward to a field with the same signature. Fix it by
  letting callers use the inner type, by moving responsibilities so each type owns a distinct set, or by merging
  the two. Dispatchers (which pick one of several implementations) and multiple impls of one trait are fine,
  because they add choice.
- **Wrappers and decorators**: before wrapping a type to add one feature, ask whether the feature belongs in the
  type itself, in the one caller that needs it, in an existing wrapper, or in a standalone type. A newtype for
  type safety should expose the domain operations, not mirror the inner type's API. Don't `impl Deref` to avoid
  writing forwarding methods; only smart pointers should implement `Deref`.
- **Interface ≠ representation**: if the API mirrors the internal storage (`get_line`/`put_line` on a buffer
  stored as lines), the type is shallow. Offer the operations callers actually perform.
- **Pass-through variables**: a parameter threaded through functions that only hand it on. Put it in a struct
  the final user already holds, or in a single context struct (`Arc<Context>`) that the major components store
  and that is passed only to constructors. Keep the context immutable. Don't reach for `static`/`OnceLock`
  globals: they rule out two instances in one process, which tests need.

```rust
// BAD: `tls` passed through layers that never use it.
fn run(cfg: &Config, tls: &TlsConfig) { serve(cfg, tls) }
fn serve(cfg: &Config, tls: &TlsConfig) { accept_loop(cfg, tls) }

// GOOD: the component that opens sockets holds what it needs.
struct Listener { ctx: Arc<Context> } // Context { tls: TlsConfig, timeouts: Timeouts, .. }
```

## Pull complexity down (Ch8)

A module has more users than maintainers, so it should absorb complexity rather than pass it on to every caller.

- Before returning an error or an `Option`, or adding a parameter, ask whether every caller would just do the
  same thing with it. If so, do that thing here.
- Avoid configuration knobs. Ask whether callers will choose a better value than this module can. If not,
  compute the value (e.g. derive a retry timeout from measured round-trip times) or default it, and expose an
  override only for the exceptional caller.
- Don't overdo it. Pull down only what is closely related to the module's job, simplifies many callers, and
  simplifies the module's interface. Pulling the UI's "backspace" into the text type is leakage, not depth.

## Better together or better apart? (Ch9)

Bring code together when the pieces share knowledge, are always used together (in both directions), overlap
conceptually, or can't be understood apart, or when merging simplifies the interface or removes duplication.
Otherwise keep them apart.

- **Separate general-purpose from special-purpose code.** A general mechanism shouldn't contain code for one of
  its uses; push special-purpose code up into the layer that needs it. Undo, for example: a generic `History` of
  `Box<dyn Action>`s with fences, text insert/delete actions living with the text type, and the grouping policy
  in the UI.
- **Don't bundle loosely related state behind flags.** A cursor and a selection in one struct, plus
  `cursor_at_start: bool` and `has_selection: bool`, is usually worse to use and to implement than two simpler
  types.
- **Don't extract single-use one-liners.** A `log_rpc_open_error()` helper called once makes the reader jump to it
  and back. Log at the call site.
- **Shared cleanup on many early returns**: use `?` with an RAII guard (`Drop`) or an inner function that
  returns `Result`, not a copy of the cleanup before each return.
- **Splitting functions**: length alone is no reason. Extract a subtask only when the child can be read without
  the parent and the parent without the child's body; such a child is usually general-purpose. Split one function
  into two caller-visible ones only if each is simpler and most callers need just one of them. If you keep
  flipping between two functions to understand either, rejoin them (Conjoined Methods). A long function with a
  simple signature that reads block by block is deep, and that's fine.

## Define errors out of existence (Ch10)

Every error variant and every panic is part of the interface. Each one is a handler someone must write, and
error paths are the least-tested code. Reduce the number of places that must handle errors, trying these in
order:

1. **Define it away**: redefine the operation so that the condition is normal. "Ensure `x` is absent" can't fail
   when `x` is already absent, and a range query can return the overlap (possibly empty) instead of failing on
   out-of-range bounds. `std::fs::create_dir_all` succeeds if the directory already exists; `fs::remove_file`
   does not, so every caller that only wants the file gone writes the same `NotFound` match.
2. **Mask it low**: recover inside the module when every caller would do the same (retry a transient failure,
   fall back to a replica).
3. **Aggregate it high**: let errors propagate with `?` to one handler (the request loop, `main`) instead of
   handling them at each call site. Build the human-readable message where the error is created, so the
   top-level handler needs no knowledge of specific errors. Keep errors that abort one request distinct from
   errors that are fatal to the process.
4. **Crash on bugs**: a violated internal invariant is a bug, not an error to return. Use
   `expect("<invariant>")` or `unreachable!("<why>")`, and don't invent an error variant that no caller can act
   on. Whether an I/O failure justifies a crash depends on the program: a CLI may abort, but a replicated store
   must recover.

The same applies to special cases, not just errors. When "none" means "empty", represent it with an empty value
(an empty `Vec`, range or selection) so that normal code handles it without an `if`.

Don't overdo it: never swallow an error the caller needs (`let _ =`, `.ok()`, or `unwrap_or_default()` on a
network or storage failure). Hide what's unimportant; expose what's important.

```rust
// BAD: every caller that just wants the file gone must special-case NotFound.
pub fn remove_cache(path: &Path) -> io::Result<()> {
    fs::remove_file(path)
}

// GOOD: the postcondition is "no cache file", which already holds when it's missing.
/// Ensures no cache file exists at `path`.
///
/// # Errors
/// Fails if the file exists and can't be removed.
pub fn clear_cache(path: &Path) -> io::Result<()> {
    match fs::remove_file(path) {
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(()),
        other => other,
    }
}
```

```rust
// GOOD: out-of-range bounds are not an error; the result is the overlap.
/// The items with index in `start..end` that exist; empty if none do.
pub fn window(&self, start: usize, end: usize) -> &[T] {
    let end = end.min(self.items.len());
    &self.items[start.min(end)..end]
}
```

## Design it twice (Ch11)

For a new public type, trait or module interface, sketch at least two substantially different interfaces (a few
key signatures each, e.g. line-oriented vs. character-oriented vs. range-oriented), even when one seems obviously
right. Compare them on ease of use for callers first, then on simplicity, generality, and the efficiency each
interface allows. Pick one, combine them, or use their weaknesses to drive a third design. Repeat for the
implementation, where simplicity and performance matter most. When the choice isn't obvious, tell the user which
alternative you rejected and why.

## Documentation (Ch12–13, 15–16)

Comments capture what the code can't: the abstraction, the precise contract, and the reasons behind it. If a
caller has to read the body to use a function, there is no abstraction.

- **Write the doc first.** Write the type's `///` doc, then the signatures and docs of the main methods, then
  the field docs, and only then the bodies. If a doc is hard to write both briefly and completely (Hard to
  Describe), or must explain the implementation before a caller can use the item, the design is shallow; rework
  it before writing the code.
- **Interface docs (`///`, `//!`) say what, not how.** For a type: what one value represents, and its
  limitations. For a function: one sentence on its behaviour as the caller sees it; then the arguments and the
  return value, precisely; side effects; `# Errors`, `# Panics`, `# Safety` and `# Cancel Safety` sections as
  applicable; and any preconditions (keep them few). Implementation details go in `//` comments inside the body.
- **Be precise** about fields, arguments and return values: units; whether bounds are inclusive or exclusive;
  what `None`, empty or zero means; who owns a resource or must close it; invariants ("never empty"). Describe a
  field with nouns (what the value represents), not verbs (which code updates it).
- **Don't repeat the code or the name.** `/// Returns the count.` on `fn count` adds nothing. Use different words
  from the ones in the name.
- **Implementation comments** say what a block does and why, not how. Put one comment above each major block, at
  the narrowest scope that covers it, plus a short strategy comment at the top of a long function. For a
  workaround or bug fix, say why it's needed and cite the issue, or the next person will remove it. Reasons belong
  in the code, not only in the commit message.
- **Document each decision once**, where a maintainer will look (usually the declaration). Elsewhere, point to it
  with an intra-doc link (``[`Buffer::alloc`]``) or a "see …" comment. Don't re-describe a callee at its call
  site. Link to external specs (an RFC URL) instead of restating them.
- **Cross-module decisions**: make the compiler enforce them where you can. Otherwise put the note where a
  maintainer must go, e.g. "adding a variant also requires …" on the enum.
- **Nonobvious control flow**: for callbacks, trait objects in a registry, spawned tasks, a `Drop` with side
  effects, or a constructor that starts threads, document when, where and on which thread or task the code runs.
  Put that in the item's doc, and add a short comment at any surprising call site.

```rust
// BAD: repeats the name; the reader still doesn't know the unit or which side.
/// The horizontal padding.
pub text_horizontal_padding: u32,

// GOOD
/// Blank space left on both the left and the right of each line, in pixels.
pub text_horizontal_padding: u32,

// BAD: describes which code toggles it (verbs).
/// Set to true by the receiver on a heartbeat, reset by the timer task.
received_heartbeat: bool,

// GOOD: describes what it means (noun).
/// A heartbeat has arrived since the election timer was last reset.
received_heartbeat: bool,
```

## Names (Ch14)

Seeing a name in isolation, a reader should be able to guess what it refers to, and what it doesn't.

- **Precise**: avoid `data`, `info`, `status`, `value`, `manager`, `tmp`, a bare `count` (of what?), and
  `result` for anything that isn't the return value. Use short names (`i`, `n`) only where every use is visible
  within a few lines; the farther the uses are from the declaration, the longer the name should be.
- **Booleans are predicates**: `cursor_visible` or `is_empty`, not `blink_status`. Name a sentinel for its
  meaning (`NOT_YET_VOTED`), or better, make it an enum variant or `None`.
- **Not too specific**: `range`, not `selection`, for a parameter that accepts any range.
- **Consistent**: use one name per concept across the crate, never reuse it for anything else, and keep the
  concept narrow enough that every variable with that name behaves the same way. Related pairs share a base
  name: `src_block`, `dst_block`. Two meanings of one primitive (a block index within a file vs. a block number
  on disk) need two names, and two newtypes.
- Follow the Rust API Guidelines naming conventions (`as_`/`to_`/`into_`, no `get_` prefix on getters,
  `iter`/`iter_mut`/`into_iter`) so knowledge of the ecosystem carries over.
- **Hard to pick a name?** The item probably does more than one job. Split it.

## Consistency (Ch17)

- When in Rome: before writing, look at how the crate already does it (error types, module layout, naming,
  constructors, test layout) and do the same.
- Don't introduce a "better" convention in one place. Change a convention only if there is significant new
  information and the change is worth converting every existing use. In that case ask first, then convert all of
  them.
- Respect the crate's `rustfmt.toml`, `clippy.toml`, and `#![deny]`/`[lints]` configuration.
- Dissimilar things should look different: don't reuse a name or a pattern for something that only resembles
  what it was made for.
- Encode invariants in types (private fields plus a validating constructor) so that code doesn't need to check
  them again.

## Code should be obvious (Ch18)

Design for ease of reading, not ease of writing.

- Return a named struct rather than a tuple when the meaning of the fields isn't obvious: `-> (u64, bool)` makes
  every caller remember which is which. Universally understood pairs, such as `(K, V)` or the result of
  `split_at`, are fine.
- Meet expectations: `new` should be cheap and free of side effects. Name a constructor that does I/O, connects,
  or spawns threads or tasks for what it does (`open`, `connect`, `spawn`), and document it. If a `Drop` impl
  blocks or does I/O, document that on the type.
- Separate logical blocks with a blank line, and put the block's comment on its first line.

```rust
// BAD
fn last_vote(&self) -> (u64, bool) { /* ... */ }
let (t, ok) = node.last_vote(); // which is the term? what does `true` mean?

// GOOD
struct VoteState { term: u64, voted_this_term: bool }
fn last_vote(&self) -> VoteState { /* ... */ }
```

## Composition over inheritance; patterns that fit (Ch19)

- A trait gets deeper the more distinct implementations it has. A trait with a single impl is usually a shallow
  layer.
- Default methods are implementation inheritance. Write them only against the documented contract of the
  required methods, so an implementor doesn't need to read them to know what to override.
- Don't emulate inheritance with `Deref`. Hold the shared part as a field (composition) and expose the operations
  you mean.
- Don't force a pattern (builder, wrapper, visitor, observer, a getter and setter per field) onto a problem it
  doesn't fit. Expose operations, not fields: a struct with an invariant keeps its fields private and offers
  domain methods, while a plain-data struct with no invariant can simply have `pub` fields instead of trivial
  getters and setters.
- Grow the code base in abstractions, not features. When a feature needs a new abstraction, design the
  abstraction's core properly then, rather than adding to it one call site at a time.
- Tests are what make refactoring safe. For a bug fix, write the failing regression test first and watch it fail.

## Designing for performance (Ch20)

Simple code is usually fast; clean design and performance rarely conflict.

- Know what is fundamentally expensive (network round trips, disk and syscall I/O, heap allocation, cache misses)
  and choose the naturally efficient option when it's just as simple: `HashMap` unless you need ordering,
  `Vec<T>` rather than `Vec<Box<T>>` (one contiguous allocation), batched round trips.
- If the faster option adds complexity, prefer the simple one unless you have evidence that performance matters
  there. If the added complexity would show in an interface, require even stronger evidence.
- Measure before optimizing (`cargo bench`/criterion, a profiler) and keep the baseline. Back out a change that
  doesn't measurably help, unless it also simplifies the code.
- When optimizing a hot path, first write down the minimal code the common case needs ("the ideal"), then find a
  clean design close to it. Detect all special cases with one check up front (a cached field can make a single
  check possible), and move their handling off the path into a separate `#[cold]` function. Remove shallow layers
  from the path: each crossing costs time and another result check.

```rust
pub fn alloc(&mut self, len: usize) -> &mut [u8] {
    // Common case: room left in the current chunk. `spare` is 0 when there is no chunk,
    // so this one test rules out every special case.
    if len <= self.spare {
        /* bump within the current chunk */
    } else {
        self.alloc_slow(len)
    }
}

#[cold]
fn alloc_slow(&mut self, len: usize) -> &mut [u8] { /* new chunk, first chunk, oversized, ... */ }
```
