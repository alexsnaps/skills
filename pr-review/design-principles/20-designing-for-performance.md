# 20. Designing for Performance

**Thesis:** Clean design and high performance are compatible — simpler code usually runs faster — so use basic awareness of what's expensive to pick "naturally efficient" clean designs, and when you must optimize, measure first and redesign around the critical path rather than tweaking on intuition.

**Maps to:** design principle(s) #4 "Modules should be deep" (deep classes cross fewer layers, so they're faster); #1 "Complexity is incremental" (beware optimizations that add complexity); #2 "Working code isn't enough". (Ch20 defines no named canonical red flag, but reuses the book's "shallow layers / pass-through method" red flag as both a design and a performance problem.)

## Review checklist
- Does the change optimize prematurely — adding complexity to speed up code with no evidence it's on a hot path? Neither extreme (optimize every statement / ignore performance entirely) is right; prefer designs that are naturally efficient *and* simple.
- Where a cheap option is as clean as a slow one, is the cheap one chosen? (e.g. hash table over ordered map unless ordering is needed; storing structs inline in an array vs. an array of pointers.)
- If the faster design adds complexity, is that complexity small and hidden behind the interface? Reject changes that add a lot of implementation complexity, or complicate interfaces, for speed without clear evidence performance matters here.
- **Measure before modifying:** does a performance change cite measurements of the real system, or is it based on intuition? Programmers' performance intuitions are unreliable, even for experts.
- Do the measurements go deep enough to pinpoint a small number of specific hot spots (not just "the system is slow"), and is there a baseline to re-measure against afterward?
- After the change, is there evidence performance actually improved? If a complexity-adding change made no measurable difference, it should be backed out (unless it also made the code simpler) — there's no point keeping complexity that doesn't buy a real speedup.
- **Critical-path redesign:** does the optimization target the minimum code that must run in the common case? Look for special cases collapsed into ideally a single up-front test, with special-case handling branched off the critical path.
- Does the optimized path remove shallow layers / pass-through methods rather than threading through several method calls that each re-check the same condition?

## Red flags to catch
- **Intuition-driven tuning** — performance changes made without measurement; wastes effort and usually adds complexity for no gain.
- **Speculative / premature optimization** — every statement micro-optimized, adding complexity, much of which won't help; or a complex "fast" design chosen with no evidence performance matters.
- **Complexity that doesn't pay** — a complicating change that didn't produce a measurable speedup and wasn't backed out.
- **Special cases on the critical path** — extra conditionals/method calls handling rare cases inline, slowing the common case (each addition costs a little; they add up).
- **Shallow layers / pass-through methods** — several stacked methods with identical signatures providing the same abstraction, whose results each caller re-checks; a design red flag that is also a performance cost from repeated layer crossings.

## Questions to raise with the author
- What measurement motivated this optimization, and what's the baseline we can re-measure against?
- Did performance measurably improve? If not, can we back this out (unless it also simplifies the code)?
- What is the smallest amount of code that must run in the common case here — can we design around that "ideal" critical path instead of the current structure?
- Can these special-case checks be collapsed into one up-front test, with the rare cases handled off the critical path?
- Is the added complexity hidden behind the interface, or does it leak into callers? Do we have clear evidence performance will matter in this specific spot?

## Nuance / don't overdo it
- Redesigning existing code to run faster should be a last resort and shouldn't happen often; first prefer a "fundamental fix" (a cache, a better algorithm/data structure) implemented with normal clean-design techniques.
- The critical-path "ideal" is a target, not literal code — you may add a bit back (e.g. a call into a general-purpose hash table class) to keep clean abstractions; in practice you can usually get very close to the ideal while staying clean.
- Some extra overhead on the common path can be worth it to keep a frequently-read value cheap to fetch (RAMCloud kept `totalLength` updated in `alloc` rather than recomputing it per query). Optimize the whole set of critical paths, not one in isolation.
- Special-case code off the critical path should be structured for simplicity, not speed — performance only matters on the common path.
