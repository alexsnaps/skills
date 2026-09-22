# 10. Define Errors Out Of Existence

**Thesis:** Exceptions are one of the worst sources of complexity, so the goal is to reduce the number of places where exceptions must be handled — best of all by redefining semantics so the error condition no longer exists.

**Maps to:** design principle(s) #11 "Define errors (and special cases) out of existence"; #10 "Pull complexity downward" (masking); #4 "Modules should be deep" (fewer exceptions in the interface); #6 "Simple interface over simple implementation"

## Review checklist
- Ask whether each newly-thrown exception is necessary, or whether the method's semantics could be redefined so the "error" is just normal behavior (e.g. `unset` ensures a variable no longer exists rather than failing if it's absent; `substring` clamps out-of-range indices instead of throwing).
- Watch for over-defensive code that rejects anything slightly suspicious with an exception, and for "punt to the caller" exceptions thrown because the author didn't want to handle a hard case — the caller usually won't know what to do either.
- Count the exceptions a class/method adds to its interface; exceptions are a particularly complex, propagating interface element that make a class shallower. Fewer is better.
- Look for many near-identical handlers doing the same thing (e.g. one try/catch per `getParameter` call) — these should aggregate into a single handler higher up (or near the top of a request-handling loop) that reads an error message carried in the exception.
- Check whether a low-level, widely-used method could mask the exception internally (retry, recover) so callers never see it — this pulls complexity downward and deepens the class.
- For rare, unrecoverable errors (out of memory, I/O hard error, socket-open failure, internal inconsistency), confirm the code just prints diagnostics and crashes (e.g. a `ckalloc` wrapper) rather than threading unhandled recovery paths everywhere.
- Look for special-case `if` handling (e.g. a "no selection" flag) that could be designed away by making the normal representation cover the special case (an always-present, sometimes-empty selection).

## Red flags to catch
- **Repetition** — duplicated exception-handling code across many call sites is the aggregation signal (this chapter's Web-server example reuses the Ch9 Repetition red flag).
- Proliferation of exceptions on an interface (an "over-defensive" API) — a smell that errors are being generated rather than defined away.
- Special-case `if`-riddled code that a redefined normal case could eliminate.

## Questions to raise with the author
- Could this method's contract be redefined so this exception simply doesn't arise (make the post-condition the goal, not the action)?
- Is this exception thrown because the situation is genuinely the caller's business, or because it was the easy way out here? Will the caller actually know what to do with it?
- These handlers all generate the same error response — can they aggregate into one handler and carry their message in the exception record?
- Could this failure be masked at a low level (retry/recover) so higher layers never learn about it?
- For this rare, unrecoverable condition, is crashing with a clear message simpler and safer than partial recovery code that will rarely run and probably doesn't work?
- Does this special case need to exist in the implementation, or only in the user's mental model (different layer, different abstraction)?

## Nuance / don't overdo it
- Defining away or masking an exception is only valid when the information isn't needed outside the module. A network module that swallowed all errors left applications unable to detect lost messages or failed peers — there the exceptions must be exposed.
- "Errors catch bugs" is a real objection, but the error-ful approach also adds code (checks, ignores) that itself breeds bugs; the net win is a simpler API. Weigh it, don't assume.
- Crashing is right only for errors that are rare and not worth handling; a replicated storage system must recover from an I/O error, not abort.
- Exception aggregation and masking pull in opposite directions on the stack: masking works best low (a shared library method), aggregation works best after propagating several levels up. Judge which positions the handler to catch the most exceptions.
- Error/crash promotion (RAMCloud crashing a server on a corrupted object) reduces distinct recovery mechanisms but raises recovery cost — fine when the error is rare, wrong for frequent errors like lost packets.
- Overall: hide what's unimportant (the more the better), but expose what's important.
