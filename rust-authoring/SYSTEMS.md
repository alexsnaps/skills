# Unsafe, FFI, atomics and no_std

Guidance distilled from Jon Gjengset's *Rust for Rustaceans* (chapter numbers point at the book), updated for
edition 2024. Read it before you write `unsafe` code, an FFI binding, lock-free or atomic code, or a `no_std`
crate. For wording `# Safety` docs and `// SAFETY:` comments, use the `unsafe-rust-review` skill if it's
installed.

## Unsafe code (Ch2, 9)

`unsafe` doesn't switch off Rust's rules. It lets you uphold them with reasoning the compiler can't check.

- **The two uses of the keyword.** `unsafe fn` is a contract the *caller* must meet; document it in `# Safety`.
  `unsafe {}` is you certifying that every contract inside the block is met; say how in `// SAFETY:`. Inside an
  `unsafe fn`, still wrap unsafe operations in `unsafe {}` blocks (in edition 2024, leaving them out triggers the
  `unsafe_op_in_unsafe_fn` warning).
- **Prefer a safe design.** Unchecked methods (`get_unchecked`, `from_utf8_unchecked`) are rarely worth it;
  measure first.
- **Keep the privacy boundary small.** Soundness depends on every piece of code that can touch the relevant fields
  or add impls for the type, not just on the unsafe block. Put the unsafe code in one private module (or its own
  crate) with an entirely safe interface, and keep the fields private. Recheck the unsafe code whenever an impl is
  added to the type: adding a safe `impl Unpin` can break a `Pin::new_unchecked` elsewhere.
- **Don't drop the `unsafe` marker** from internal functions to reduce noise. It's what prompts the next person to
  check the invariants.
- **A `SAFETY:` comment must hold in every build.** A `debug_assert!` can back it up in tests, but it isn't the
  proof, because it doesn't run in release builds.
- **Unsafe code may rely on the *safety* of safe code, not its *correctness*.** A user's `Hash`, `Ord`, `Eq` or
  `Deref` impl may be wrong or inconsistent; your unsafe code must stay sound anyway.
- **Panic safety.** Assume any call into user code (closures, `T::default()`, `Clone`, trait methods) can panic
  and unwind, and that `?` can return early. Update lengths and other invariants only after the values they
  describe are initialized (call `Vec::set_len` after writing the elements), or protect the gap with a drop
  guard.
- **Validity applies even to values you never use.** A reference must never dangle, be misaligned, or point to an
  invalid value; a `bool` must be 0 or 1; nothing may be read from uninitialized memory. Use `MaybeUninit<T>` for
  memory that isn't a valid `T` yet, and `&raw const`/`&raw mut` (or `ptr::addr_of!`) to point at fields of packed
  or partially initialized structs without creating a reference.
- **Layout.** Don't transmute or pointer-cast between `repr(Rust)` types, even between "identical" ones or the
  same generic type with different parameters, because their layout isn't guaranteed. Use `#[repr(C)]`, or
  `#[repr(transparent)]` for a single-field wrapper, when you need a layout.
- **Pointer types.** Use `NonNull<T>` where you'd have written `&T` and the pointer is never null: it is covariant,
  and the niche makes `Option<NonNull<T>>` pointer-sized. Use `*const T` if the pointer may be null, and `*mut T`
  where you'd have written `&mut T`.
- **Owning through a raw pointer.** A type that owns a `T` through a raw pointer holds `PhantomData<T>` so the drop
  checker knows it drops a `T`.
- **`unsafe impl Send`/`Sync` carries bounds**: write `unsafe impl<T: Send> Send for MyType<T> {}`, not an impl
  for every `T`.
- **Make a trait `unsafe`** only if safe code relying on a correct implementation could become memory-unsafe when
  the implementation is wrong, not merely to flag logic errors.
- **`static mut`.** Taking a reference to one is an error in edition 2024. Use atomics, `Mutex`/`OnceLock`, or raw
  pointers via `&raw mut`.
- **Check your work.** Run the tests under Miri (`cargo +nightly miri test`; mark tests too slow for it with
  `#[cfg_attr(miri, ignore)]`), and under sanitizers (ASan, TSan) where available. Assert assumptions liberally: a
  panic beats undefined behaviour. Read the Rustonomicon before writing nontrivial unsafe code.

```rust
// BAD: the debug_assert disappears in release builds, so this proves nothing.
debug_assert!(index < slice.len());
// SAFETY: We verified index < slice.len() via debug_assert.
unsafe { *slice.get_unchecked(index) }

// GOOD: the bound is checked in every build.
if index < slice.len() {
    // SAFETY: `index < slice.len()` was checked just above.
    Some(unsafe { *slice.get_unchecked(index) })
} else {
    None
}
```

## FFI (Ch11)

- **Edition 2024 syntax.** Foreign declarations go in `unsafe extern "C" { ... }`; mark an item `safe fn` only if
  no argument values can make calling it unsound. Exported items use `#[unsafe(no_mangle)]` with
  `pub extern "C" fn`.
- **Types.** Use `core::ffi` (`c_int`, `c_char`, `c_void`, `CStr`, `CString`) rather than guessing widths. Pass
  slices as a pointer plus a length. Keep endianness-specific C types (`__be32`) as byte arrays. Give shared
  structs `#[repr(C)]`.
- **Enums.** A `#[repr(C)]` or `#[repr(u32)]` Rust enum is valid only for its listed values. A C "enum" that can
  hold ORed flags or unknown values must be a newtype over an integer with associated constants (or use
  `bitflags`); converting an unlisted integer into a Rust enum is undefined behaviour.
- **Nullable pointers.** `Option<NonNull<T>>`, `Option<&T>` and `Option<extern "C" fn(..)>` have the same layout
  as a nullable C pointer.
- **Allocation.** Memory must be freed by the allocator that allocated it. Memory Rust hands out comes back
  through a Rust `*_free` function (`Box::into_raw`/`Box::from_raw`). For large or frequent data, prefer letting the
  caller provide the buffers.
- **Panics must not unwind across `extern "C"`.** In a callback or exported function, use `catch_unwind` and turn
  the panic into an error code, or use `extern "C-unwind"` deliberately.
- **Safe wrappers.**
  - Take `&mut` wherever foreign code may mutate the data.
  - Encode "must outlive" rules as lifetimes: a `Device<'ctx>` borrows its `Context`.
  - Don't implement `Send`/`Sync` unless the library documents its thread safety; a `PhantomData<*const ()>`
    field opts a handle out of both.
  - Give each opaque handle its own type instead of `*mut c_void`, so handles can't be mixed up.
- **Bindings.** Generate them with `bindgen` (in `build.rs`, so they match the target) into a separate `<lib>-sys`
  crate, and wrap them safely in the main crate. To export a C API, generate the header with `cbindgen`. For C++,
  consider `cxx`. Keep build scripts deterministic: they shouldn't depend on quirks of the build machine.

```rust
// One opaque type per handle: a `*mut Session` can't be passed where a `*mut Device` is expected.
// The marker makes the type !Send, !Sync and !Unpin until a wrapper decides otherwise.
#[repr(C)]
pub struct Session {
    _data: [u8; 0],
    _marker: PhantomData<(*mut u8, PhantomPinned)>,
}
```

## Atomics and lock-free code (Ch10)

- Start with `Mutex`, `RwLock` or channels. Reach for atomics only for simple flags and counters, or for a measured
  bottleneck.
- **Orderings.** Use `SeqCst` until you can justify something weaker, and say why in a comment. `Relaxed` is fine
  for a counter or flag that doesn't publish other data. To publish data, pair a `Release` store with an `Acquire`
  load (`AcqRel` for read-modify-write operations).
- Use `compare_exchange` for conditional updates, and `compare_exchange_weak` inside a retry loop. Use `fetch_add`
  and the other `fetch_*` methods for commutative updates; they never fail and retry. Beware of ABA.
  `fetch_update` is a compare-exchange loop.
- **Contention.** A hot atomic or lock serializes the cores that touch it. Split it (shard it) before tuning
  orderings. Pad per-thread data to a cache line (`#[repr(align(64))]`, `crossbeam_utils::CachePadded`) only when a
  benchmark shows false sharing.
- **Testing.** Use stress tests full of assertions, `loom` for the core of a primitive, and ThreadSanitizer for
  larger tests. Debug with `tracing` or a per-thread buffer rather than `println!`: stdout's lock can hide the race.

## no_std (Ch12)

- A library that can work without std uses `#![cfg_attr(not(feature = "std"), no_std)]` with a default, additive
  `std` feature that *enables* the std-only APIs. Never add a `no_std` feature that removes them.
- Import from `core::` and `alloc::` (with `extern crate alloc;`). `HashMap` isn't in `alloc`; use `BTreeMap` or
  `hashbrown`.
- Check that the crate really is std-free by building for a target without std (e.g.
  `--target thumbv7m-none-eabi`). `#![no_std]` alone stops neither `use std::` nor a dependency that pulls std in.
- Where running out of memory must be handled, offer `try_` variants built on fallible APIs (`Vec::try_reserve`).
- Without an allocator, use fixed-capacity containers (const generics, `heapless`).
- Memory-mapped I/O uses `ptr::read_volatile`/`write_volatile`. Model registers with typestate, and hand out each
  peripheral only once (a singleton constructor) so the types enforce the hardware's rules.
