# 14. Choosing Names

**Thesis:** Names are a form of abstraction and documentation; each name should create a precise, unambiguous image of the entity in the reader's mind and be used consistently, because vague or overloaded names cause real bugs.

**Maps to:** design principle #14 "Software designed for ease of reading, not writing" (also #1 "complexity is incremental" — one mediocre name barely matters, thousands do); red flags "Vague Name" and "Hard to Pick Name".

## Review checklist
- Apply the isolation test to each new name: seeing it *without* its declaration, docs, or surrounding code, could a reader guess what it refers to — and what it is *not*?
- Names are precise, not generic: `count` → `numIndexlets`/`getActiveIndexlets`; `x`/`y` for a text position → `charIndex`/`lineIndex`; a sentinel string → `NOT_YET_VOTED`.
- Boolean names are predicates whose true/false meaning is clear (`cursorVisible`, not `blinkStatus` where "status" gives no clue what true means).
- Names aren't *too specific* either: an argument that accepts any range shouldn't be named `selection` (implies it's UI-selected) — use `range`.
- `result` is not used as a variable name in a method that has no return value (misleadingly implies it's the return value and says nothing about content); reserve `result` for values that do become the return.
- A common concept uses one name everywhere (a file system always uses `fileBlock` for a block index within a file), and that name is *never* reused for a different behavior — the `block` (physical vs logical) collision was a six-month data-corruption bug.
- Multiple variables of the same kind use the common name plus a distinguishing prefix (`srcFileBlock` / `dstFileBlock`).
- Loop variables: `i` in the outermost loop, `j` when nested; short generic names only where the loop is short and the whole usage is visible.
- The greater the distance between a name's declaration and its uses, the longer the name should be.

## Red flags to catch
- **Vague Name** — a name broad enough to refer to many things (`count`, `status`, `result`, `x`, `data`); it conveys little and invites misuse (the reader assumes the wrong meaning).
- **Hard to Pick Name** — struggling to find a precise, intuitive, short (two-or-three-word) name hints the underlying entity lacks a clean definition, often because one variable is doing several jobs; consider splitting it.

## Questions to raise with the author
- "This name is generic — what exactly does it hold? Units? For the boolean, what does `true` mean?"
- "`block`/`x`/`result` is reused here with a different meaning than elsewhere — should these be distinct names so a reader can't make the wrong assumption?"
- "You seem to have had trouble naming this — is it representing more than one thing? Would separating it into two variables give each a simpler definition?"

## Nuance / don't overdo it
- Generic `i`/`j` are fine as loop iterators when the loop spans only a few lines — if the whole range of use is visible, meaning is obvious from the code.
- The Go style guide's short-name view is presented as a legitimate different opinion: readability is judged by *readers*, not writers; if readers find short names clear, that's acceptable. Ousterhout's disagreement is specifically with reusing one short name for many different things (`ch`, `d`), which invites the `block`-style confusion.
- Don't over-lengthen: names beyond two or three words become unwieldy; the goal is the few words that capture the most important aspects.
