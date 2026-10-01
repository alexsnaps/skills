---
name: rust-authoring
description: Author idiomatic, hard-to-misuse Rust. Use when writing or modifying Rust code — choosing types, APIs, error handling, concurrency, and async patterns so misuse is caught at compile time.
---

## When this applies

Apply these practices whenever you write or modify Rust in the current project. They cover the decisions the
compiler cannot make for you: how to shape types and APIs so they are hard to misuse, how to handle errors, and
how to write correct concurrent and async code.

- Write code that fits its surroundings — match the crate's existing naming, module layout, error style, and
  idioms before importing a pattern from here.
- When a rule here conflicts with a strong, consistent local convention, follow the local convention.
- Prefer moving a class of bug to compile time (strong types, enums, typestate) over catching it at runtime.
- "Type" below means a struct, enum, or type alias defined in the current crate.

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

### Ownership and borrowing

- [ ] Every `clone()` is intentional and justified by a comment when non-obvious
- [ ] `Arc<Mutex<T>>` is used only where shared mutable state is truly needed
- [ ] `RefCell` usage is justified
- [ ] Lifetimes are kept simple
- [ ] `Cow` considered where it avoids an allocation

### Unsafe code (most important)

- [ ] Every `unsafe` block has a `SAFETY` comment explaining *why* it is sound
- [ ] Every `unsafe fn` has a `# Safety` doc section listing caller invariants
- [ ] The unsafe boundary is as small as possible
- [ ] A safe alternative was considered first

### Concurrency

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

- [ ] Libraries use `thiserror`; applications use `anyhow` + `.context()`
- [ ] No `unwrap()` / `expect()` in production code
- [ ] Error messages help with debugging
- [ ] `#[must_use]` values are handled; `#[source]` preserves the chain

### Performance

- [ ] No unnecessary `collect()`
- [ ] Large data passed by reference
- [ ] Strings built with `with_capacity` / `write!` where it matters
- [ ] `impl Trait` vs `Box<dyn Trait>` chosen deliberately
- [ ] Hot paths avoid allocations

### Code quality

- [ ] `cargo clippy` is clean and `cargo fmt` applied
- [ ] Doc comments are complete; public APIs have examples
- [ ] Tests cover boundary conditions

### Async

- [ ] No blocking calls (`std::fs`, `thread::sleep`) in async
- [ ] No `std::sync` lock held across `.await`
- [ ] Spawned tasks are `'static`
- [ ] `spawn` used only for genuinely parallel/background work

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
  of the same crate. If a duplicate version is unavoidable, note why.

## Shaping functions and types

### Constructors

When you create a new instance of a type, expose it as an associated function on that type (`Type::new(...)`, or a
named constructor like `Type::from_parts(...)`) rather than a free function. Implement `Default` when the type has
a sensible default so it composes with the rest of the ecosystem.

### Prefer methods over free functions

When a function's primary argument is (a reference to) a struct from the current crate, make it a method in an
`impl` block on that type rather than a free function. Behaviour stays with its data and the call site reads
better.

## Design for illegal-states-unrepresentable

### Enums over groups of booleans

When several booleans together determine a state or a mode — especially when some combinations are invalid — model
the allowed states as an enum instead of loose `bool` fields. One `enum` makes the valid set explicit and lets the
compiler check you handled every case.

### Use strong types, not stringly-typed values

Don't represent distinct domain concepts with the same primitive — e.g. `String` for both an IP address and a file
path, or `u32` for both a user id and a byte count. Wrap each in a newtype so the compiler rejects passing one
where the other is expected.

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
  parameter that varies the behaviour instead of maintaining two bodies.

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

## Unsafe code (most critical)

Avoid `unsafe` — write the safe equivalent whenever one exists. Don't mark a function `unsafe` unless callers must
uphold real invariants the type system can't. When you do need `unsafe`, keep the boundary minimal and document it.

### Every unsafe block gets a SAFETY comment

```rust
// BAD: no explanation
unsafe { *slice.get_unchecked(index) }

// GOOD: SAFETY comment explaining why this is sound
debug_assert!(index < slice.len());
// SAFETY: We verified index < slice.len() via debug_assert.
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

Wrap unsafe FFI calls in safe functions that validate inputs and translate error codes into `Result`.

```rust
extern "C" {
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

## Performance

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

---

## Trait design

### Don't over-abstract

Don't create a trait for everything — concrete types are simpler and faster. Introduce a trait only when you
genuinely need polymorphism.

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

- Default to **generics** (static dispatch) for performance and inlining.
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

## Async code

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
