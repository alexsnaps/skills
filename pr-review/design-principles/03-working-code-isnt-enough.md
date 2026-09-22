# 03. Working Code Isn't Enough (Strategic vs. Tactical Programming)

**Thesis:** Getting code to work is not the goal; the primary goal is a great long-term design that also happens to work, achieved through continual small investments (strategic programming) rather than the fastest path to a working feature (tactical programming).

**Maps to:** design principle(s) #2 "Working code isn't enough"; #3 "Make continual small investments to improve system design". (Ch3 defines no named canonical red flag but describes the tactical mindset, quick kludges/patches, and the "tactical tornado.")

## Review checklist
- Does this change get the feature working at the cost of a kludge, a quick patch, or a workaround that adds complexity? Ask whether it improves or degrades the long-term structure.
- When the diff patches around a problem instead of fixing it, flag it: patch-on-patch is the tactical spiral the chapter warns about.
- Look for evidence of the investment mindset: did the author consider a cleaner alternative design for a new class/API rather than shipping the first idea that worked?
- When the diff touches code that has an obvious pre-existing design problem, was it fixed (reactive investment) or stepped around? A little extra time to fix beats ignoring it.
- Is there proactive investment where warranted — good documentation, a design that anticipates likely future changes?
- Watch for high-volume changes that ship fast but leave a mess for others to clean up (the tactical-tornado pattern) — velocity is not the review criterion.

## Red flags to catch
- **Tactical programming** — the change is optimized to finish the task quickly; a "bit of complexity" or "a small kludge or two" is accepted to close the ticket sooner.
- **Quick patch / workaround** — a problem is worked around rather than fixed, creating complexity that will require further patches.
- **Tactical tornado** — a prolific author who produces code fast but tactically, leaving a wake others must clean up (they, not the tornado, are the real heroes).
- **"No time to clean up now"** — deferring design fixes until after the crunch; the chapter notes this delay tends to become permanent.

## Questions to raise with the author
- Is this the cleanest design you found, or the first one that worked? Did you try an alternative?
- This works, but does it make the system easier or harder to extend next time? What does the next person building on this pay?
- There's an existing design problem in the code you touched — is now the right moment to invest a little and fix it rather than patch around it?
- Are we taking on complexity here to hit a deadline? If so, is it acknowledged as debt rather than treated as done?

## Nuance / don't overdo it
- The code must still work — strategic programming does not mean gold-plating or ignoring correctness; a great design "also happens to work."
- Don't demand a huge up-front design (that's the waterfall method, which the book says doesn't work). The ideal design emerges in bits and pieces; favor lots of small continual investments.
- The book's rule of thumb is ~10–20% of development time on investment — enough to matter, small enough not to wreck schedules. Calibrate review pressure to that, not to perfection on every diff.
- Even under startup-style pressure, the payoff for good/bad design comes quickly; but the standard is continual small investment, not stopping the line for a rewrite.
