# 12. Why Write Comments? The Four Excuses

**Thesis:** Comments are not optional polish but an essential part of abstraction — the common excuses for skipping them ("self-documenting code", "no time", "they go stale", "all comments are worthless") don't hold up.

**Maps to:** design principle #13 "Comments describe non-obvious"; no named red flag is defined in this chapter (it foreshadows "Comment Repeats Code", defined in Ch13).

## Review checklist
- Does every new/changed class, method, and class variable carry an interface comment? The chapter argues the *only* abstraction a bare declaration gives is name + arg/result types — too little to use the thing without reading its body.
- Are the informal parts of an interface written down: what a method does, the meaning of its result, the conditions under which it makes sense to call it, side effects? These cannot be expressed in code.
- Is the rationale for a non-obvious design decision recorded somewhere in the diff?
- Did the change touch code but leave an adjacent comment describing the *old* behavior? Code review is the book's named mechanism for catching stale comments (12.3).
- Watch for documentation being silently deprioritized in a feature diff ("I'll add comments later") — the chapter's point is that deferred docs become no docs.

## Red flags to catch
- The chapter defines no named red flag. The observable smells it describes are: **missing interface documentation** (readers forced to read the method body to learn its behavior — no abstraction is being provided) and **stale comments** left behind by a code change.

## Questions to raise with the author
- "A caller can't tell from the declaration whether `end` is inclusive, or what happens when `start > end` — can the interface comment state it?" (the book's own substring example)
- "What's the rationale for doing it this way? That reasoning isn't recoverable from the code."
- "This behavior/result meaning is only in the method body — can we lift it into a comment so callers don't have to read the implementation?"
- "Did the new behavior change what this existing comment promises?"

## Nuance / don't overdo it
- The fourth excuse ("all comments I've seen are worthless") is conceded to have the *most merit* — worthless comments are real. The remedy is good comments, not no comments; later chapters give the framework.
- Keeping docs current is not an enormous effort: large doc changes are only needed when code changes are large, and the code change costs more than the doc change (12.3). Don't use "it'll go stale" to justify omission.
- Writing comments is estimated at under ~10% of development time, and abstraction-level comments (class/method) pay for themselves immediately by serving as a design tool (12.2) — so "no time" is not a valid reason on review.
