# 09. Better Together Or Better Apart?

**Thesis:** Whether to combine two pieces of code or split them apart should be decided by which structure yields less overall complexity — deeper interfaces, fewer dependencies, better information hiding — not by mechanical rules like method length.

**Maps to:** design principle(s) #4 "Modules should be deep"; #6 "Simple interface over simple implementation"; #7 "General-purpose modules are deeper"; #8 "Separate general/special-purpose code"; #9 "Different layers, different abstractions"; red flag(s) "Repetition", "Special-General Mixture", "Conjoined Methods"

## Review checklist
- Look for the same (or nearly-same) code snippet appearing repeatedly; ask whether it can be factored into one method or refactored so it runs in one place (e.g. cleanup-before-return collapsed to a single tail block).
- When two pieces of code share substantial knowledge of the same thing (e.g. both must understand the HTTP request format to do their job), check whether splitting them forced that knowledge to be duplicated across a boundary — that argues for bringing them together.
- When a diff combines modules, confirm the combined interface is actually simpler (intermediate hand-off interfaces eliminated, some work now done automatically so users needn't know about it, e.g. buffering by default).
- Check that a general-purpose mechanism does not carry code specialized for one particular use of it; special-purpose code should be pulled upward into higher layers, leaving lower layers general-purpose.
- For an extracted helper: verify you can read the child without knowing the parent, and the parent without reading the child's implementation. If not, the extraction was harmful.
- For a method split into two caller-visible methods: verify each resulting interface is simpler than the original and that most callers need only one of them (not both).
- Don't flag a long method just for being long. Ask whether it provides one clean, deep abstraction with a simple signature; independent sequential blocks or tightly-interacting blocks are fine kept together.

## Red flags to catch
- **Repetition** — the same or almost-the-same piece of code appears over and over; signals the right abstraction hasn't been found.
- **Special-General Mixture** — a general-purpose mechanism also contains code specialized for one particular use of it, causing information leakage (e.g. the undo core living in the text class with per-entity handlers; the combined selection+cursor object storing a boolean for which end is the cursor).
- **Conjoined Methods** — you can't understand one method's implementation without also reading another's; applies to any two physically-separated pieces of code that can only be understood together (e.g. the shallow per-error logging methods each read only in tandem with their single call site).

## Questions to raise with the author
- These two classes/methods share a lot of knowledge about X — would combining them shorten the code and drop an interface, as in the read-and-parse HTTP example?
- This helper is one line but heavily documented and called from one place — does extracting it buy anything, or does it just add an interface a reader must cross?
- Is this a general-purpose mechanism with a specific use baked in? Could the special-purpose part move to the higher layer that actually needs it?
- After this split, do callers have to invoke both new methods and pass state between them? If so, is the split really simplifying anything?
- Are the pieces you separated actually closely related (manipulated together, one implemented in terms of the other)? If so, would they be simpler joined?

## Nuance / don't overdo it
- "Separate general from special-purpose" applies within a single mechanism. It's fine — often right — to put special-purpose code for one mechanism alongside general-purpose code for another (text-specific undo code belongs in the text class, not in the general History class).
- Developers tend to split methods too much. Length alone is rarely a reason to split; splitting adds interfaces and separates related code. Deep methods hundreds of lines long can be fine.
- Splitting into two caller-visible methods (Figure 9.3(c)) rarely makes sense — judge it purely by whether it simplifies things for callers; the risk is ending up with several shallow methods.
- Bringing code together is not always right either: things only loosely related (selection vs. cursor) become simpler when separated. Pick the structure with the best information hiding, fewest dependencies, and deepest interfaces.
