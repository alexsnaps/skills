# 11. Design it Twice

**Thesis:** Your first design idea is rarely the best, so for every major design decision sketch and compare multiple radically-different alternatives before committing — the small extra design time pays for itself in a better result.

**Maps to:** design principle(s) #12 "Design it twice"; #6 "Simple interface over simple implementation" / #5 "Common usage simple" (ease of use is the top comparison criterion); #7 "General-purpose modules are deeper" (generality is a comparison factor)

## Review checklist
- This is primarily a design-discussion / design-doc check, not a line comment: look for evidence that more than one approach was considered for each major decision (interface shape, and separately the implementation).
- Check that the alternatives considered were genuinely different (e.g. line-oriented vs. character-oriented vs. range/string-oriented text interface), not minor variations — you learn more from contrast.
- Confirm the choice is justified against explicit pros/cons, led by ease of use for higher-level software, and also weighing: is one interface simpler, more general-purpose, or does it enable a more efficient implementation?
- Watch for a chosen design whose weaknesses were flagged but not used to drive a better third option (the "each alternative pushes work up into callers" observation should have led to the range-oriented API).
- For implementation decisions, check the comparison goals shift to simplicity and performance (e.g. linked list of lines vs. fixed-size blocks vs. gap buffer).

## Red flags to catch
- Both/all candidate designs force higher-level software to do extra work the module should own — a signal that none is right yet and a better alternative should be synthesized (a text class should handle all text manipulation).
- No sign any alternative was considered — the first idea was implemented directly. (This chapter defines no named red flag of its own.)

## Questions to raise with the author
- What other approaches did you consider for this interface, and why did this one win?
- What's the strongest alternative design here, and what are its concrete pros/cons versus this one on ease of use, generality, simplicity, and efficiency?
- Both options seem to push work onto callers — is there a third design that absorbs that work into the module?
- Did you design the interface and the implementation as separate two-way comparisons (they optimize for different things)?

## Nuance / don't overdo it
- This is a process recommendation and applies mainly at design time / design review, not as a per-line comment on already-written code.
- Designing it twice does not need to take long — an hour or two for a class, small next to the days/weeks of implementation; scale the exploration to the module's size.
- Even when you're sure there's only one reasonable approach, sketch a second anyway — reasoning about a bad design's weaknesses is instructive.
- The best result may not be any single alternative; it's often a combination of features from several. Frame review feedback as "compare and synthesize," not "pick A or B."
- Be aware this principle is hardest for very smart people who are used to their first idea sufficing; resistance to considering alternatives is itself worth naming gently in a design discussion.
