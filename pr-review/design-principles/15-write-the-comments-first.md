# 15. Write The Comments First

**Thesis:** Writing interface comments *before* the code makes documentation a design tool — comments capture abstractions early, and a comment that's hard to write cleanly is an early warning that the abstraction (or the module's depth) is wrong.

**Maps to:** design principle #13 "Comments describe non-obvious" (and #4 "deep modules" — comments are used to judge interface depth); red flag "Hard to Describe".

## Review checklist
- Do the interface comments read as coherent, up-front abstractions — behavior from the caller's view, args, return, side effects — rather than after-the-fact narration that tracks the code line by line? Comments written last tend to repeat the code and omit the important non-obvious design ideas (15.1).
- Is any method or variable saddled with a long, complicated comment needed just to describe it completely? That's the canary: it signals a weak abstraction, wrong variable decomposition, or a shallow module.
- Compare each interface comment against the method body: if the comment has to describe all the *major features of the implementation* to be complete, the method is shallow — flag it.
- Are new abstractions actually documented in the diff, not deferred? (The chapter's whole argument is that delayed comments never get written well, if at all.)
- Do variable/boolean comments capture the essence (what the thing *is*), which is the sign of a design-time comment, rather than a restatement derived from the finished code?

## Red flags to catch
- **Hard to Describe** — the comment that should completely *and* simply describe a method or variable can't be kept short and simple. That difficulty indicates a problem with the design of the thing being described (poor abstraction, shallow interface, or the wrong decomposition). Valid only when the comment is genuinely complete and clear — a cryptic or incomplete short comment is not evidence of a simple interface.

## Questions to raise with the author
- "This interface needs a long, complicated comment to explain — is the abstraction right? Could the interface be simpler and the module deeper?"
- "The interface comment restates most of the implementation — does that mean the method is shallow? Worth redesigning the interface?"
- "This reads like it was written from the finished code (it mirrors the statements). Does it capture the design intent that isn't obvious from the code?"

## Nuance / don't overdo it
- The chapter is largely about *process* (write comments first). A reviewer sees the artifact, not the timing, so infer quality from the comments themselves rather than trying to enforce an ordering.
- Comments are only a reliable complexity indicator when they are complete and clear; don't read a terse or incomplete comment as proof of a simple interface.
- The "early comments are expensive" objection is quantified away (comment-writing is ~5% of total development time, and writing first can stabilize abstractions and save coding time) — so cost is not a valid reason to accept missing or bolted-on documentation.
