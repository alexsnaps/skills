---
name: make-change-easy
description: Prepare a codebase before building a feature or changing behavior — first make the change easy (a preparatory, behavior-preserving refactor that opens the seam), then make the easy change (minimal code to green). Runs a four-phase, human-gated lock-step: agree a frozen test, plan the refactors, refactor, then make it pass — committing nothing itself. Use when about to add or change non-trivial functionality that touches existing code and needs a new seam; not for one-line tweaks, config edits, or brand-new standalone files.
---

# Make the change easy, then make the easy change

Kent Beck's maxim: *"For each desired change, make the change easy (warning: this may be hard), then make the easy change."* Most of the risk lives in the first half. This skill splits that work into four phases with a hard human gate between each, so the preparatory refactor and the actual feature land as **separate, independently reviewable, independently revertible** commits — made by the user, never by Claude.

The shape:

```
Phase 1  Contract   → agree a FROZEN test + the new interface + modules touched
Phase 2  Plan       → assess coverage, derive an ordered refactor list + a sketch
Phase 3  Easy       → do the behavior-preserving refactor (suite green throughout)
Phase 4  Change     → land the frozen test, minimal code to green
```

Each phase ends by **halting and waiting for the user's explicit "go."** Claude never advances a gate on its own.

## When to use / not use

**Use it** when about to add or change non-trivial functionality that touches existing code and needs a new seam to sit cleanly — the kind of change where "just wedge it in" would leave a mess.

**Skip it** for one-line tweaks, config edits, pure additions in a brand-new standalone file, or anything where no refactor is needed to make room. If in doubt, say what you'd do and let the user opt in.

## Hard rules

1. **Claude never touches git history or the index.** No `git add`, `commit`, `push`, `stash`, `reset`, or `rebase`. The user reviews and commits. Claude may read git state (`status`, `diff`, `log`) freely.
2. **Halt and wait at every gate.** Present the phase's output, then stop. Nothing in the next phase happens without the user's explicit "go."
3. **The test is frozen after phase 1** (see the two flags below).
4. **Two hard flags are stops, not speed bumps** — when one fires, stop and reopen the earlier phase; do not grind through.
5. **Keep the scratch plan file current** as the single source of truth for the frozen test and where we are.

## The scratch plan file

State lives in `.make-change-easy/<slug>.md`, where `<slug>` is a short kebab-case name for the change. It survives context compaction and is what "frozen" is measured against.

Keep it **out of git** so it can't be swept into a feature commit: append `/.make-change-easy/` to `.git/info/exclude` once (repo-local; never edit the tracked `.gitignore`). Never stage it.

Template:

```markdown
# make-change-easy: <feature name>

Phase: 1 · Contract   [ ] agreed
Phase: 2 · Plan       [ ] agreed
Phase: 3 · Easy       [ ] refactor committed by user
Phase: 4 · Change     [ ] feature committed by user

## Frozen test (agreed <date>)
<the minimal test, as concrete code>

## New interface / seam
<the signature(s) the test drives, invariants, error modes>

## Modules touched
<files / modules the change reaches>

## Coverage assessment (phase 2)
<is the change site under a green safety net? if not, the characterization tests to add first>

## Refactor plan (phase 2)
1. <behavior-preserving step> — opens seam: <what>
2. ...

## Implementation sketch (phase 2, NOT frozen)
<a few lines showing roughly how the feature sits once the seam exists>

## Flags log
<any frozen-test drift or "not easy" events, and how they were resolved>
```

---

## Phase 1 — Contract

Agree the smallest test that pins the new behavior, plus the interface it drives. This is the feature's contract.

**What a good test is here:**
- It exercises behavior through the **public interface / seam**, never internals. A **seam** is a place where you can change behavior without editing in that place — the boundary you observe the feature at.
- It reads like a specification: the name states the capability ("returns cached value on second call"), not the mechanism.
- Its expected values come from an **independent source of truth** (a known-good literal, a worked example, the spec) — never recomputed the way the code would, which would make it pass by construction.
- It is **one minimal vertical slice**, not a battery of edge cases. One capability, one test.

**Steps:**
1. Identify the seam and the interface the feature needs — the signature(s), the inputs, the observable result.
2. Write the test **as concrete code** (real syntax for this project's test framework), even though it can't compile yet — the seam doesn't exist. This is authored on paper; it does **not** enter the working tree until phase 4.
3. Name the modules the change will touch.
4. Record all of the above in the plan file.
5. **Gate:** present the frozen test + interface + modules and **stop.** Advance only on the user's explicit "go."

Once agreed, the test is **frozen** — see the flags.

---

## Phase 2 — Make the change easy, on paper

Work out how the feature meets the existing code, and what must move first so that meeting is trivial.

**Steps:**
1. **Assess the safety net.** Does the code the refactor will touch sit under a green test suite? If coverage is thin or absent, refactoring is flying blind. In that case the plan **leads with characterization tests** that pin *current* behavior (new test code only, no production change), scoped tightly to just the code the refactor will reshape. No net, no refactor.
2. **Analyze the naive implementation.** Imagine writing the feature against today's code with no refactor. Where does the structure fight it? Those friction points name the refactors.
3. **Derive the refactor list** — an *ordered list of the smallest behavior-preserving steps* that together open the seam the frozen test needs. Annotate each with the seam it opens and why.
4. **Sketch the implementation** — a few lines showing roughly how the feature will sit *once the seam exists*. This justifies the refactors ("after step 2, the feature is ~10 lines in `X`"). The sketch is **not frozen**; phase-4 code may differ.
5. For an unfamiliar codebase, fan out with **read-only search agents** to build this rather than guessing.
6. Record the coverage assessment, refactor list, and sketch in the plan file.
7. **Gate:** present the plan and **stop.** Advance only on the user's explicit "go."

---

## Phase 3 — Make the change easy

Execute the refactor. It must be **behavior-preserving**: the feature does not exist yet at the end of this phase.

**Steps:**
1. Run the existing suite and confirm it is **green (baseline).** If it is already red, stop and report — do not refactor on top of red.
2. If phase 2 called for characterization tests, add them first and confirm they pass.
3. Perform the refactors as **one cohesive whole** (the user reviews the refactor as a unit; the intermediate micro-steps need not each be green).
4. Run the full suite again and confirm it is **green** at the end. Behavior is unchanged.
5. Summarize the diff.
6. **Gate:** the user reviews and **commits the refactor themselves.** Wait for them to confirm the commit is done, then "go." If the tree is still dirty at this gate, point out the refactor is uncommitted and recommend committing it separately — but honor an explicit "go anyway, I'll commit both at the end." Claude commits nothing.

---

## Phase 4 — Make the easy change

Now the change should be easy. Make it.

**Steps:**
1. Land the **frozen test** in the working tree.
2. Run it and confirm it is **red for the right reason** — the feature is missing, not a typo, wrong import, or compile error in the test itself.
3. Write the **minimal** code to make it green. If it needs a substantive change to the frozen test, that's a flag (below). If it turns out not to be easy, that's the other flag.
4. Run the full suite and confirm everything is **green.**
5. **Gate:** the user reviews and **commits the feature + test themselves.** Claude commits nothing.
6. Update the plan file's checklist. The `.make-change-easy/<slug>.md` file can be deleted once the change is done.

---

## The two hard flags

Both are **stops.** When one fires, name it plainly, record it in the plan file's flags log, and reopen the earlier phase for the user's decision — do not paper over it.

**Flag 1 — the frozen test needs a substantive change.**
A *substantive* change touches the new API or the seams the test requires — the thing the contract is about. If reality forces one, **stop and reopen phase 1**; get the user's OK on the new contract before editing the test. Silently editing the test to match whatever the code does is spec drift and makes the test pass by construction.
*Not* substantive, and free to do without ceremony (note it in passing): imports, fixture wiring, test-framework boilerplate, renaming to a symbol's final name.

**Flag 2 — the easy change isn't easy.**
If phase 4 starts sprawling — the minimal change isn't minimal, it needs a seam phase 3 didn't create, or it forces touching modules that weren't in the plan — the preparation was incomplete. **Stop and reopen phase 2**: add the missing refactor, re-gate, re-refactor. A hard phase 4 is a signal, not a task to grind through. That is the whole point of making the change easy first.
