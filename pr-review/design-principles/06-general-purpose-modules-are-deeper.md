# 06. General-Purpose Modules are Deeper

**Thesis:** Build modules "somewhat general-purpose" — functionality reflects today's needs, but the interface is general enough for multiple uses; this produces simpler, deeper interfaces and cleaner separation than special-purpose APIs, even if the module is only ever used for its original purpose.

**Maps to:** design principle(s) #7 "General-purpose modules are deeper"; #8 "Separate general-purpose and special-purpose code"; #6 "A simple interface matters more than a simple implementation" (chapter defines no boxed red flag, but flags special-purpose methods informally and ties over-specialization to Information Leakage, Ch5)

## Review checklist
- Do the new class's methods/args mirror higher-level or UI concepts (`backspace`, `delete`, `deleteSelection`, `Cursor`, `Selection`) instead of the module's own domain (`insert`/`delete` over generic `Position`)?
- Could several special-purpose methods collapse into one general method (three delete variants → one `delete(start, end)`) without losing capability?
- Is a method used in only one place / by one caller? That is a sign it may be too special-purpose.
- Does adding a caller/UI feature require adding a matching method to the lower module? That ties the two together and leaks caller abstractions into the module.
- Is the general API still easy to use today, or does the caller now write lots of glue/loops (e.g. a character-at-a-time API forcing loops)? Then it's too general.
- Does a method purport to hide detail the caller actually needs (e.g. `backspace` hiding which characters get deleted)? False abstraction.

## Red flags to catch
- **Single-use / special-purpose method** (chapter's informal red flag) — a method designed for one particular use or invoked in a single place; try to replace several such methods with one general-purpose method.
- **Hard-to-use over-general API** (the counter red flag) — needing lots of extra caller code, or lots of extra arguments just to cut method count, means it has gone too far.
- **False abstraction** — hiding behind an interface a detail the caller genuinely needs, creating obscurity and information leakage between the layers.

## Questions to raise with the author
- What is the simplest interface that covers all current needs? (Fewer methods with the same capability usually means more general methods.)
- In how many situations will this method be used? If just one, can it be generalized?
- Is this API easy to use for the current need without a pile of caller-side code?
- Does this detail belong in the caller — where it matters and can be made obvious — rather than behind a false abstraction in the module?

## Nuance / don't overdo it
- "Somewhat" is the point: don't build something so general it's awkward for today's needs.
- Cutting method count only helps while each method's API stays simple; don't trade fewer methods for many extra arguments.
- Built-in support for ranges of characters beats single-character ops even though the latter is "simpler and general" — it's easier to use and more efficient.
