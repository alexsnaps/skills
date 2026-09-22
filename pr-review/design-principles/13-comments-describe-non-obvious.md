# 13. Comments Should Describe Things that Aren't Obvious from the Code

**Thesis:** A good comment adds information at a *different level of detail* than the code — lower-level for precision or higher-level for intuition — and never merely restates what the adjacent code already shows.

**Maps to:** design principle #13 "Comments describe non-obvious"; red flags "Comment Repeats Code" and "Implementation Documentation Contaminates Interface".

## Review checklist
- Every new class has an interface comment giving the abstraction it provides, what each *instance* represents, and its limitations (e.g. "single-threaded, one request at a time"). No implementation details.
- Every new/changed method's interface comment covers: behavior as the *caller* perceives it (high level), each argument, the return value, side effects, exceptions it can emanate, and any preconditions.
- Every new class/instance variable has a comment; check it supplies what the declaration can't: units, whether boundaries are inclusive/exclusive, what a null value means, who is responsible for freeing/closing a resource, and any invariants.
- Comments use *different words* than the entity's name — not the name re-formed into a sentence (the "downcast PARAMETER to TYPE" anti-pattern where the only new word was "to").
- Apply the book's test: could someone who has never seen the code write this comment just from the code next to it? If yes, it adds nothing.
- Interface/method comments contain **no** implementation details users don't need (internal RPC names, private config/tuning vars, internal data structures, "implemented in a DCFT module").
- Variable comments describe *what the variable represents* (nouns), not *how it is manipulated* across the class (verbs).
- Longer/complex loops and each major block of a long method have a high-level "what / why" comment; there is no line-by-line narration.
- Bug-fix code whose purpose isn't obvious explains *why*, or references the tracker issue (e.g. "Fixes RAM-436…") instead of duplicating details.
- Cross-module design decisions are documented where a developer will actually discover them — a natural central point (e.g. the `Status` enum listing all files to update) or a `designNotes` file with `// See "X" in designNotes` back-references.
- Comments follow the project's doc-tool conventions (Javadoc / Doxygen / godoc).

## Red flags to catch
- **Comment Repeats Code** — one comment per line echoing that line; a comment reusing the words of the name it documents; anything deducible purely from the adjacent declaration. Also shows up as vague-but-redundant variable comments ("Current offset in resp Buffer") that add no precision.
- **Implementation Documentation Contaminates Interface** — a method/class interface comment describing internals users don't need (algorithm, RPC names, private parameters, "each execution tries to make small progress…"). If the interface comment *must* describe the implementation to be complete, the method/class is shallow.

## Questions to raise with the author
- "What is a 'normalized resource name', and what are the elements of the returned array?" — i.e. name the precision gaps the comment leaves open.
- "Is this range inclusive? What are the units — pixels or characters? Can this be null, and what does null mean? Who frees this?"
- "This interface comment describes how it works internally — does the user need that? If the abstraction can't be stated without the implementation, is the method shallow?"
- "Where will a developer touching the sender side discover that the receiver depends on this decision?"
- On disputes: if a reviewer says something isn't obvious, treat it as not obvious — the target reader is a first-timer, not the author.

## Nuance / don't overdo it
- Occasionally a declaration is so obvious there is nothing useful to add (some getters/setters). This is rare — it's easier to comment everything than to agonize over each case.
- Implementation comments are *often unnecessary*: short simple methods, short loops, and local variables whose entire usage is visible within a few lines usually need none.
- A class comment need not document every method detail; a usage example is optional but helpful for deep classes with non-obvious usage patterns.
- "Obvious" is judged from the reader's perspective, not the author's.
