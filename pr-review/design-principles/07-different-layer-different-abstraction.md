# 07. Different Layer, Different Abstraction

**Thesis:** In a layered system each layer should present a different abstraction from those above and below it; adjacent layers with the same abstraction (pass-through methods, decorators, pass-through variables) are a red flag — they add infrastructure and complexity without adding functionality.

**Maps to:** design principle(s) #9 "Different layers should have different abstractions"; #6 "A simple interface matters more than a simple implementation" (interface-vs-implementation section); red flag(s) "Pass-Through Method"

## Review checklist
- Does a new method just forward its arguments to another method with the same/similar signature and add nothing? Pass-through method.
- What fraction of a class's public methods are pass-throughs? (The example class: 13 of 15.)
- Does the interface to a feature live in a different class from where that feature is actually implemented?
- If two methods share a signature, does each add distinct functionality (a dispatcher choosing a target; multiple implementations of one interface), or is it empty forwarding?
- Is a new class a decorator/wrapper adding boilerplate + pass-throughs for a small feature? Could the feature instead go in the underlying class, an existing decorator, the use case, or a stand-alone class?
- Does the class's public interface mirror its internal representation (`getLine`/`putLine` over line-based storage) instead of offering a different, deeper abstraction (character-oriented `insert`/`delete`)?
- Is a variable threaded through a long chain of methods that don't use it (a `cert` passed through `m1`, `m2` only to reach `m3`)? Pass-through variable.
- If a context object is used, is it turning into a grab-bag, and are its fields immutable (thread safety)?

## Red flags to catch
- **Pass-Through Method** — a method that does nothing but pass its arguments to another method, usually with the same API; indicates no clean division of responsibility between the classes.
- **Adjacent layers with the same abstraction** (chapter's opening red flag) — suggests a problem with the class decomposition.
- **Pass-through variable** — a variable passed down a long method chain; every intermediate method must know about it though it has no use for it, and adding one later forces edits across many signatures.
- **Shallow decorator** — a wrapper full of pass-through methods, lots of boilerplate for little new functionality; overuse yields an explosion of shallow classes (Java I/O).

## Questions to raise with the author
- Exactly which features/abstractions is each of these two classes responsible for, and where do they overlap?
- Should callers use the lower class directly, should functionality be redistributed, or should the two classes merge?
- Does this decorator need to wrap the base at all, or could it be a stand-alone or merged class?
- For a pass-through variable: is there a shared object or context object that could carry it instead? (Avoid globals — they block multiple instances and complicate testing.)
- Does each added element (interface, argument, class) eliminate more complexity than it introduces?

## Nuance / don't overdo it
- Same-signature methods are fine when each adds distinct functionality: dispatchers (choose which method runs) and multiple implementations of one interface (disk drivers, which actually reduce cognitive load); these are usually same-layer and don't call each other.
- Decorators sometimes make sense, but there is usually a better alternative.
- Context objects are the author's usual fix for pass-through variables but are "far from ideal" — they carry globals' disadvantages; keep them disciplined and prefer immutable fields.
