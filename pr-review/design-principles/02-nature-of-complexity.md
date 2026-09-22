# 02. The Nature of Complexity

**Thesis:** Complexity is anything about a system's structure that makes it hard to understand and modify; it is caused by dependencies and obscurity, and it accumulates incrementally from many small chunks rather than one catastrophic error.

**Maps to:** design principle(s) #1 "Complexity is incremental: sweat the small stuff". (Ch2 defines no named canonical red flag, but names the symptoms — change amplification, cognitive load, unknown unknowns — and the causes — dependencies, obscurity; it also calls out "the need for extensive documentation" as a sign the design isn't right.)

## Review checklist
- Does a "simple" change in this diff force edits in many places? If the same fact (a color, a constant, a format) is repeated rather than centralized, flag the change amplification.
- Does using the new/changed code require the caller to remember something (e.g. free this memory, call X before Y, know the units)? That cognitive load belongs inside the module, not on every caller.
- Could a future developer touch this code and silently break something they had no way to know about? Look for hidden coupling (e.g. an emphasis color derived from a banner color, a status that also needs a message-table entry) — these are the unknown unknowns.
- Are the dependencies this diff introduces obvious and greppable (a named shared variable, a signature the compiler checks) rather than implicit?
- Are names specific enough to carry information (not `time` with no units)? Is the same name reused for two different purposes anywhere?
- Judge complexity from the reader's seat, not the writer's: if you find the diff hard to follow, that is evidence it is complex, even if the author found it simple.
- Weight your concern by how often this code will be touched — isolated, rarely-touched complexity matters far less than complexity on a hot path (C = sum of c_p weighted by time spent in part p).

## Red flags to catch
- **Change amplification** — one conceptual change requires modifications scattered across many files/pages; a shared value is duplicated instead of referenced from one place.
- **High cognitive load** — the diff adds APIs with many methods, global variables, inconsistencies, or new inter-module dependencies that a developer must hold in their head to use it correctly.
- **Unknown unknowns** — nothing in the code tells a future developer what else must change or what they must know; correctness depends on undocumented, non-obvious knowledge. (The book calls this the worst of the three.)
- **Obscurity** — important information is not obvious: generic names, missing units, dependencies that aren't visibly linked.
- **"Need for extensive documentation"** — if the change requires a lot of prose to explain, treat it as a signal the design itself may be wrong, not just under-documented.

## Questions to raise with the author
- If we later need to change <the value/behavior this touches>, how many places have to change, and how would someone find them all?
- What does a caller have to know or remember to use this correctly? Can we move that responsibility into the module so callers don't carry it?
- Is there any hidden dependency here that a future reader wouldn't discover by reading this code or grepping a name?
- Is this abstraction obvious — could someone make a quick, confident guess about how to change it without reading everything?

## Nuance / don't overdo it
- Complexity is not lines of code: a shorter implementation can be more complex if it raises cognitive load. Don't reward brevity that hides what the code does; sometimes more lines are genuinely simpler.
- Dependencies can't be eliminated — they're intentionally introduced (every new class/API is one). The goal is to reduce them and make the remaining ones simple and obvious, not to chase zero.
- Isolated complexity in code that is almost never touched is nearly as good as no complexity; don't demand cleanups where the payoff (time-weighted) is negligible.
- Any single small dependency or obscurity is defensible on its own; the point is that they add up, so the bar is "don't let this one slide," not "this one is catastrophic."
