# 17. Consistency

**Thesis:** Consistency — doing similar things in similar ways (and dissimilar things differently) — creates cognitive leverage and reduces mistakes, so new code should conform to established conventions rather than introduce a "better" but inconsistent approach.

**Maps to:** design principle(s) #14 "Design for ease of reading, not writing" (consistency makes behavior more obvious). (Ch17 defines no named canonical red flag, but names the levers of consistency — names, coding style, interfaces, design patterns, invariants — the ways to ensure it — document, enforce, "when in Rome" — and warns against changing existing conventions and against "taking it too far".)

## Review checklist
- Does the new code follow the conventions already visible in the file/module it touches? Declaration order (public before private), method ordering (e.g. alphabetical), camelCase vs snake_case, brace placement, indentation — match what's there.
- When the author made a design decision, did they check whether a similar decision already exists elsewhere in the project and reuse that approach?
- Does the change respect documented conventions (style guide, project wiki) and locally documented conventions such as invariants?
- Does the change uphold invariants the code relies on (e.g. "every line is newline-terminated"), rather than quietly introducing values that violate them?
- If an interface has multiple implementations, does the new implementation provide the same features and shape as the others?
- Does the diff introduce an inconsistency — a new convention that conflicts with an existing one — on the grounds that it's "better"? That is rarely justified.
- Are automated checks (formatters, linters, pre-commit checkers) applied so low-level syntactic conventions are enforced, not left to memory? Nit-pick style in review — it trains the team and keeps code clean.

## Red flags to catch
- **New conflicting convention** — the author "improved" on an existing convention, creating two ways to do the same thing. The value of consistency almost always exceeds the value of one approach over another.
- **Half-migrated convention change** — a convention was replaced but old uses remain, so both coexist; if you upgrade a convention, there should be no sign of the old one left.
- **Broken invariant** — code introduces a state that violates a property other code assumes always holds (adding new special cases downstream).
- **Forced consistency ("taking it too far")** — dissimilar things crammed into the same shape: one variable name reused for genuinely different things, or a design pattern applied to a task that doesn't fit it. This creates confusion, because consistency only pays off when "if it looks like an x, it really is an x."

## Questions to raise with the author
- Is there an existing example of this in the codebase we should mimic instead of inventing a new form?
- This diverges from the current convention — is the change worth the inconsistency? Do you have significant new information the old convention lacked, and is the new way enough better to justify updating every old use?
- Should this convention/invariant be written down (style guide, wiki, or a comment near the relevant code) so others follow it, and can it be enforced by a tool?
- These two cases look alike but behave differently — should they really share this name/pattern, or does that mislead readers?

## Nuance / don't overdo it
- Consistency cuts both ways: don't force dissimilar things into the same approach. Overzealous consistency (same name for different things, wrong-fit design pattern) creates complexity and confusion.
- Reconsidering established conventions is rarely a good use of developer time; a "better idea" alone is not sufficient reason. Change a convention only if the whole organization agrees both that there's significant new justification and that it's worth updating all old uses — and even then, others may reintroduce the old approach later.
- Don't be consistent with a genuinely bad pattern for its own sake; the two-question test exists precisely to weigh a justified upgrade against the cost of inconsistency.
