# 16. Modifying Existing Code

**Thesis:** A system's design is shaped more by the changes made during its evolution than by its initial conception, so every modification must stay strategic — leaving the design at least a little better, with its comments kept accurate and close to the code — rather than settling for the smallest fix that works.

**Maps to:** design principle(s) #2 "Working code isn't enough"; #3 "Make continual small investments to improve system design"; #14 "Design for ease of reading, not writing". (Ch16 defines no named canonical red flag, but names concrete practices: stay strategic, keep comments near the code, put comments in the code not the commit log, avoid comment duplication, check the diffs, prefer higher-level comments.)

## Review checklist
- Is this the smallest-possible tactical patch, or does it leave the design as if it had been built with this change in mind? If the change fights the current structure, ask whether the code should have been refactored instead of special-cased.
- Does the diff add special cases, dependencies, or other complexity just to avoid a larger (riskier-feeling) change? Flag "smallest change that works" reasoning.
- Even where no refactor was required, did the author take the opportunity to improve the design at least a little while in the code? "If you're not making the design better, you are probably making it worse."
- Are comments touched by the change actually updated? Look for comments the diff has silently invalidated.
- Are interface comments next to the method body (where developers will see them on edits), not stranded in a header/.h file far from the code?
- Are implementation comments pushed down to the narrowest scope covering the code they describe, rather than piled at the top of the method? (A high-level "we proceed in N phases" summary at the top is fine; per-phase detail belongs above each phase.)
- Is important information that motivated the change documented in the code, not only in the commit message? Watch for a subtle-bug-fix explained only in the commit log — a future dev could undo it and re-create the bug.
- Is any design decision documented in exactly one obvious place, with short "see X" pointers elsewhere, rather than duplicated across every affected site?
- Does the diff re-document another module's behavior (e.g. a comment before a call explaining what the callee does) or repeat documentation that already exists externally (a protocol spec, a user manual)? Prefer a reference/URL.

## Red flags to catch
- **Tactical patch on existing code** — the change is the minimal fix that "works" and degrades the design a little; complexity accumulates step by step across the system's evolution.
- **Stale / orphaned comment** — code changed but a nearby (or distant) comment now lies. Comments far from their code are the ones most likely to rot.
- **Knowledge stranded in the commit log** — information a future developer will need lives only in the commit message, where they are unlikely to look.
- **Duplicated documentation** — the same design decision is explained in several places; some copies will drift and go stale silently, with no signal to the reader.
- **Redundant cross-module / external documentation** — a comment restates what a called method's interface comment already says, or re-explains a standard already documented on the Web or in a manual.

## Questions to raise with the author
- If we'd designed this module from scratch knowing about this change, would it look like this? If not, what refactor would get us there, and can we afford a scaled-down version of it now?
- Is there a design imperfection near this change we could fix cheaply while we're already in the code?
- This commit message explains a subtle reason for the change — will a future maintainer find it? Should it live in a code comment so no one undoes it?
- This decision is documented in several places — which one is the single canonical home, and can the rest become short pointers to it?
- Could this comment be raised to a higher level of abstraction so routine code edits won't invalidate it?

## Nuance / don't overdo it
- The investment mindset collides with commercial reality: if the "right" refactor is 3 months and a quick fix is 2 hours against a hard deadline, or the refactor breaks many other teams, the quick-and-dirty path may be unavoidable. Resist it as much as possible, but don't treat "always refactor" as absolute.
- When you can't do the full cleanup now, the reviewable ask is a plan to come back to it (e.g. allocated time after the deadline), not blocking the change.
- Not every comment can be high-level; some (per Chapter 13) must be detailed and precise. The point is that the most useful comments — the ones that don't just repeat the code — also tend to be the easiest to maintain.
