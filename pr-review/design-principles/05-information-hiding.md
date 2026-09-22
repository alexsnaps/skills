# 05. Information Hiding (and Leakage)

**Thesis:** Each module should encapsulate its design decisions (data structures, algorithms, assumptions) in the implementation so they never appear in the interface — hidden information simplifies the interface, removes cross-module dependencies, and makes the module deeper.

**Maps to:** design principle(s) #4 "Modules should be deep" (information hiding is the primary technique); #5 "Interfaces make common usage simple" (defaults); red flag(s) "Information Leakage", "Temporal Decomposition", "Overexposure"

## Review checklist
- Does new code embed a design decision (file format, URL/encoding, protocol version, wire structure, a data-structure layout) in more than one module? That is leakage.
- Are two classes both reading/writing (or parsing/emitting) the same format? Consider merging into one class that owns that knowledge.
- Is the module split along execution order ("read" then "parse" then "write") rather than by the knowledge each part needs?
- Does a method return a reference to an internal collection/Map (e.g. `getParams()` handing back the internal map), exposing the internal representation and forcing "don't mutate this" rules on callers?
- Are `private` fields real hiding, or is the same information re-exposed through public getters/setters?
- Does a common call force callers to supply values they can't reasonably know (HTTP protocol version, Date header)? Prefer a sensible default.
- Does the interface do decoding/type conversion for the caller (`getIntParameter`, URL-decoding), or push that onto every caller?
- Within a class: is each instance variable used in as few places as possible?

## Red flags to catch
- **Information Leakage** — the same knowledge (e.g. a file format) lives in two+ modules, so any change forces edits in all of them; "back-door" leakage (not in any interface) is more pernicious because it isn't obvious.
- **Temporal Decomposition** — module structure follows execution order, so operations that happen at different times sit in different classes and shared knowledge gets encoded in each (e.g. one class reads the HTTP request to a string, another parses it — but headers must be parsed to know the request length, so both must understand the format).
- **Overexposure** — a commonly-used feature's API forces callers to learn rarely-used features, raising cognitive load on people who don't need them.

## Questions to raise with the author
- What single piece of knowledge does this module encapsulate, and would a change to that decision stay inside this one module?
- If knowledge is leaking between two small, tightly-coupled classes, should they merge — or be replaced by a new class whose interface genuinely abstracts the detail away (not just re-leaks it)?
- Is exposing this parameter/config necessary, or could the module determine or adjust it itself?

## Nuance / don't overdo it
- Hide only information that isn't needed outside the module. If callers genuinely need it (e.g. performance-critical config that varies per use), expose it — hiding needed info behind an interface just creates obscurity (a "false abstraction").
- Partial information hiding still has value (info reachable only via a separate, rarely-used method creates fewer dependencies).
- Making a class slightly larger often improves hiding and raises the interface level, but you can take "larger classes" too far (one class for the whole app); Ch9 covers when to split.
