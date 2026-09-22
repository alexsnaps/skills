# 04. Modules Should Be Deep

**Thesis:** The best modules are deep — they provide powerful functionality behind a simple interface, so most of their complexity is hidden from the rest of the system; shallow modules (interface nearly as complex as what they do) add complexity without paying it back.

**Maps to:** design principle(s) #4 "Modules should be deep"; #5 "Interfaces should make the most common usage as simple as possible"; #6 "A simple interface matters more than a simple implementation"; red flag "Shallow Module".

## Review checklist
- For each new class/method/module, compare interface cost against functionality benefit: is the interface much simpler than the implementation (deep), or nearly as complex (shallow)?
- Watch for shallow methods that wrap almost nothing — e.g. a one-line setter/pass-through where calling the method is no simpler (or takes more keystrokes) than doing the operation directly. Ask what abstraction it actually provides.
- Check whether the interface leaks implementation detail the caller shouldn't need (e.g. the caller has to know a value lands in some `data` variable). If the whole implementation is visible through the interface, it offers no abstraction.
- Does a new interface make the common case simple? If a near-universal need (e.g. buffering for file I/O) must be requested explicitly, that's a design smell — make the common case the default and separate the rare opt-out cleanly.
- Count the interfaces the diff introduces relative to functionality added. Many small classes/methods, each with its own interface and boilerplate, is classitis — individually simple, collectively complex.
- Confirm the interface captures the informal contract too (ordering constraints, side effects like "deletes the file named by an argument", flush/durability guarantees) in comments — anything a caller must know is part of the interface and, if omitted, becomes an unknown unknown.
- Check the abstraction omits only unimportant details: not so many that important behavior is hidden (false abstraction), not so few that irrelevant detail bloats the interface.

## Red flags to catch
- **Shallow Module** — the interface is complicated relative to the functionality provided; the cost of learning/using the interface negates the benefit of hiding internals. Small modules tend to be shallow.
- **Classitis** — "classes are good, so more classes are better": functionality chopped into many tiny classes/methods (e.g. arbitrary "split any method over N lines" rules), multiplying interfaces and boilerplate and raising system-level complexity.
- **False abstraction** — an interface that looks simple but omits details the caller actually needs, producing obscurity.
- **Common case made hard** — a feature almost everyone needs is not the default and must be assembled explicitly (the Java `FileInputStream`/`BufferedInputStream`/`ObjectInputStream` pattern), which is verbose and error-prone.

## Questions to raise with the author
- What does this module hide? If a caller can see essentially the whole implementation through the interface, what is the abstraction buying us?
- Could this small class/method be folded into its caller or a deeper module, rather than adding another interface to learn?
- Is the common usage of this interface as simple as it can be? What does the typical caller have to do, and can the rare case be pushed behind a separate constructor/method?
- Which details are you exposing in the interface, and is each one genuinely important to callers? Which are you hiding, and does the caller ever actually need them?

## Nuance / don't overdo it
- Shallow modules are "sometimes unavoidable" — the point isn't to ban them, but to notice they don't help against complexity and not to create them gratuitously.
- Depth is about interface simplicity, not implementation simplicity: a deep module (Unix I/O's five calls, a garbage collector with no interface at all) can have a huge, complex implementation. Don't penalize a complex implementation that hides behind a clean interface.
- Interfaces are good, but more/larger interfaces are not automatically better — resist the reflex that splitting things up is always an improvement.
- "Make the common case simple" still allows for choice; the rare/advanced case should remain possible, just cleanly separated so most developers never see it.
