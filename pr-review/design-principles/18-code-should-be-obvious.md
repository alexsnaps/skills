# 18. Code Should be Obvious

**Thesis:** Obscurity is a main cause of complexity; code is "obvious" when a reader can skim it quickly and their first guesses about its behavior are correct, so aim to give readers the information they need — through good names, consistency, white space, and comments — and flag anything that violates their expectations.

**Maps to:** design principle(s) #14 "Design for ease of reading, not writing"; #13 "Comments should describe things that aren't obvious from the code". Red flag: **"Nonobvious Code"** — the meaning/behavior of code can't be understood from a quick reading.

## Review checklist
- Could a reader skim this and guess its behavior correctly on the first try? "Obvious" is judged from the reader's seat — if the reviewer finds it nonobvious, it's nonobvious, no matter how clear it seemed to the author.
- Are names precise and meaningful enough that readers don't have to trace the code to deduce what a named entity means?
- Is the change consistent with patterns already used elsewhere, so readers can reuse prior knowledge?
- Is white space used to reveal structure? Blank lines between major blocks of a method (especially where each block starts with a comment), spacing within statements, and readable formatting of parameter docs.
- Where code is unavoidably nonobvious, is there a comment supplying exactly the information a reader would otherwise lack — put yourself in the reader's position and name what would confuse them?
- Event-driven / callback code: does each handler's interface comment say when it is invoked, to compensate for the hidden, indirect flow of control?
- Generic containers (`Pair`, `std::pair`): are values returned/grouped under generic names like `getKey()`/`getValue()` that hide their meaning? Prefer a purpose-specific class/struct with meaningful field names.
- Does a variable's declared type differ from the type actually allocated (e.g. declared `List`, allocated `ArrayList`)? Match declaration to allocation so the reader isn't misled about performance/thread-safety properties.
- Does the code violate reader expectations (e.g. a `main` that returns but keeps running via threads spawned in a constructor)? If so, is the surprising behavior documented at the point where a reader would expect the normal behavior?

## Red flags to catch
- **Nonobvious Code** — the meaning and behavior can't be grasped in a quick reading; important information isn't immediately clear to the reader. This is the chapter's canonical red flag.
- **Hidden flow of control** — event handlers / callbacks invoked indirectly, so you can't tell from the code which function runs or when.
- **Meaning-hiding generic container** — grouped values named `getKey`/`getValue` (etc.) that give no clue to their actual meaning; convenient to write, confusing to read.
- **Declaration/allocation type mismatch** — declared as a supertype but allocated as a specific subtype whose properties matter.
- **Violated reader expectation** — code does something most readers would not assume (e.g. app keeps running after `main` returns) without a comment flagging it.

## Questions to raise with the author
- What would a first-time reader most likely misunderstand here, and does the code (or a comment) prevent that?
- Could this generic container become a small named struct/class so the fields document themselves?
- When/where is this handler actually invoked — should that be stated in its interface comment?
- This surprised me on first read (returns but keeps running / declared type differs from real type) — should it be documented, or can we make it conform to expectations instead?
- Could we reduce the information the reader needs at all — via abstraction or eliminating a special case — rather than explaining it?

## Nuance / don't overdo it
- Some nonobvious techniques (event-driven programming among them) are the right tool in some situations; you may use them anyway. The response is not to ban them but to add documentation that minimizes reader confusion.
- The best fix for obscurity is to reduce the information the reader needs (abstraction, removing special cases), then to lean on knowledge readers already have (conventions, expectations), and only then to present the missing information in the code (names, strategic comments). Adding comments is the last resort, not the first.
- Obviousness can't be self-certified: the reliable test is a code review, so treat "this is obvious to me" from the author as insufficient.
