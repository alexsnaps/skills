# 08. Pull Complexity Downwards

**Thesis:** When a module contains unavoidable complexity related to its functionality, the developer should absorb it inside the module rather than exposing it to users — a simple interface matters more than a simple implementation, because modules have more users than developers.

**Maps to:** design principle(s) #10 "Pull complexity downward"; #6 "A simple interface matters more than a simple implementation" (chapter defines no boxed red flag)

## Review checklist
- When code hits unavoidable complexity, does it handle it internally or push it onto callers (throw an exception for the caller to sort out, or expose a config parameter)?
- Does the interface reflect the internal representation for the developer's convenience (line-oriented text API) rather than the caller's needs (character-oriented)? Pull the split/merge work down into the module.
- Are new configuration parameters being added? For each: could the module compute a good value itself (e.g. a retry interval derived from measured response times) rather than exporting a knob?
- Do any exported parameters have sensible automatically-computed defaults, so users set them only in exceptional cases?
- Would this exception or parameter force many callers/administrators to each solve the same problem the module could solve once?

## Red flags to catch
- **Configuration parameter that punts a decision** — a knob exported because the developer isn't sure of the right policy, when users can't easily determine the value or it could be computed automatically (the chapter's central caution; not a boxed red flag).
- **Complexity pushed upward** — throwing an exception or exposing a parameter so every caller/admin must handle what one developer could have handled once.

## Questions to raise with the author
- Will users (or higher-level modules) really be able to pick a better value than the module can compute here? If not, don't export the parameter.
- Can this parameter get an automatically-computed reasonable default?
- Does this module solve its problem completely, or leave an incomplete solution for callers to finish?

## Nuance / don't overdo it
- Pulling complexity down can be overdone (don't pull the whole app into one class). It makes sense only when (a) the complexity is closely related to the class's existing functionality, (b) it simplifies many places elsewhere, and (c) it simplifies the class's interface.
- Sometimes users genuinely know their domain better (e.g. which requests are time-critical), and a config parameter gives better results across domains — expose it then.
- Pulling down *unrelated* complexity (UI knowledge such as `backspace` into the text class) doesn't simplify callers much and just causes information leakage (see Ch5/Ch6).
