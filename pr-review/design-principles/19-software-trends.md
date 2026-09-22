# 19. Software Trends

**Thesis:** Every popular development paradigm — OO and inheritance, agile, unit tests, TDD, design patterns, getters/setters — should be judged by a single test: does it actually reduce complexity in large systems? Many sound good on the surface but make complexity worse.

**Maps to:** design principle(s) #15 "Increments should be abstractions, not features" (agile/TDD); #4 "Modules should be deep" and #10 "Pull complexity downward" (inheritance, getters/setters); #2 "Working code isn't enough" (TDD as tactical programming). (Ch19 defines no named canonical red flag; it applies the book's existing principles to evaluate each trend.)

## Review checklist
- **Inheritance — which kind?** Interface inheritance (multiple implementations of one signature) is good: it deepens the interface and reuses knowledge. Implementation inheritance trades change-amplification relief for dependencies between parent and subclasses.
- For implementation inheritance, was composition considered first (e.g. small helper classes the original classes build on)? If inheritance is genuinely needed, is parent-managed state kept separate from subclass state (subclasses using it read-only or via parent methods) to limit information leakage up and down the hierarchy?
- Don't assume OO mechanisms alone yield good design: shallow classes, complex interfaces, or classes exposing internal state are still high-complexity even with private methods/inheritance.
- **Agile / incremental work:** is the increment in this change an abstraction, or just a feature? Watch for minimal special-purpose mechanisms shipped with a "refactor to generic later" promise — that defers design and accumulates complexity.
- **Unit tests:** does the change keep the unit tests updated and coverage intact? Good unit-test coverage is what makes refactoring safe; its absence is what drives the tactical, minimal-change habit that lets complexity accumulate.
- **TDD:** if the author drove the design test-by-test, check that a real design step happened for any abstraction — not just enough code to pass the next test. (Writing the test first is endorsed specifically for bug fixes.)
- **Design patterns:** where a pattern is used, does it genuinely fit, or is a problem being forced into it when a custom approach would be cleaner? More patterns is not better.
- **Getters/setters:** does the diff expose instance variables (directly or via one-line get/set methods)? Prefer not exposing implementation data at all; getters/setters are shallow methods that clutter the interface and leak implementation.

## Red flags to catch
- **Implementation-inheritance coupling** — parent and subclasses share instance variables so that changing one class requires understanding the whole hierarchy (information leakage, high complexity).
- **Feature-sized increment** — work organized around getting a feature working rather than designing an abstraction; design decisions deferred to ship faster (tactical programming, per agile's risk and TDD's core flaw).
- **TDD-as-tactics** — code hacked in to make the next test pass with no obvious point at which design happens; ends in a mess.
- **Forced / over-applied design pattern** — a pattern imposed where it doesn't fit, adding complexity instead of removing it.
- **Exposed instance variables via getters/setters** — shallow one-line methods that surface implementation, violating information hiding and bloating the interface.

## Questions to raise with the author
- Is this inheritance interface or implementation inheritance? For implementation inheritance, would composition (helper classes) give the same benefit with fewer dependencies?
- Is this increment adding an abstraction we'll build on, or just a feature? If we need this abstraction, can we design it reasonably completely now rather than in pieces?
- Does this design pattern actually fit the problem, or would a custom solution be cleaner?
- Do these instance variables need to be exposed at all? Can the behavior live inside the class so the interface stays deep instead of adding getters/setters?
- Is there test coverage that makes future refactoring of this code safe?

## Nuance / don't overdo it
- The trends aren't wholesale bad: interface inheritance, incremental/iterative development, and unit tests are endorsed; implementation inheritance and design patterns are fine when they fit and are used with caution.
- TDD is rejected for design work but explicitly recommended for bug fixing — write a failing test that reproduces the bug first, then fix it, so you know the fix is real.
- Getters/setters can make sense *if* you must expose instance variables (they allow later validation/notification without interface change); the deeper fix is to avoid exposing the variables in the first place.
- The general caution: "X is good" never implies "more X is better" — establishing a pattern tempts developers to overuse it (as happened with getters/setters in Java). Challenge each proposal on whether it reduces complexity, not on its popularity.
