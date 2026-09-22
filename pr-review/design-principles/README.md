# Code-review principles from *A Philosophy of Software Design*

John Ousterhout, 2nd-ish ed. (this repo's `psd.pdf`). One markdown file per applicable
chapter, each distilling the chapter into things a reviewer can actually check on a diff —
the **strategic / design** dimension of a review, above correctness and style.

Chapters 1 (Introduction) and 21 (Conclusion) are meta and have no file of their own; their
substance is the two summary lists below and is carried by the per-chapter files.

## How to use these in a review

- Correctness and spec conformance still come first (that's what `pr-review`'s [`REVIEW.md`](../REVIEW.md)
  already covers, dimension 1). These notes are dimension 2: *is the design getting better or worse
  with this change?*
- The unit of judgement is **complexity** — anything that makes the system harder to
  understand or modify (Ch2). A change that adds a feature but makes the next change harder is
  a net loss (Ch3).
- Treat every **red flag** below as a prompt, not a verdict. Name it, point at the code, and
  ask the author — most map to a `should-fix:` or `question:` in the draft, rarely a `blocker:`.
- Design feedback that isn't meant as a line comment (a "this whole approach is shallow"
  conversation) belongs in **For you, not for the PR**, per the skill's convention.

## Summary of Design Principles (verbatim, p. 178)

1. Complexity is incremental: you have to sweat the small stuff. (p. 11)
2. Working code isn't enough. (p. 14)
3. Make continual small investments to improve system design. (p. 15)
4. Modules should be deep. (p. 22)
5. Interfaces should be designed to make the most common usage as simple as possible. (p. 27)
6. It's more important for a module to have a simple interface than a simple implementation. (pp. 55, 71)
7. General-purpose modules are deeper. (p. 39)
8. Separate general-purpose and special-purpose code. (p. 62)
9. Different layers should have different abstractions. (p. 45)
10. Pull complexity downward. (p. 55)
11. Define errors (and special cases) out of existence. (p. 79)
12. Design it twice. (p. 91)
13. Comments should describe things that are not obvious from the code. (p. 101)
14. Software should be designed for ease of reading, not ease of writing. (p. 149)
15. The increments of software development should be abstractions, not features. (p. 154)

## Summary of Red Flags (verbatim, p. 179)

> The presence of any of these symptoms in a system suggests a problem with its design.

| Red flag | Meaning | Covered in |
|---|---|---|
| **Shallow Module** | The interface for a class or method isn't much simpler than its implementation. | [04](04-modules-should-be-deep.md) |
| **Information Leakage** | A design decision is reflected in multiple modules. | [05](05-information-hiding.md) |
| **Temporal Decomposition** | Code structure is based on execution order, not information hiding. | [05](05-information-hiding.md) |
| **Overexposure** | An API forces callers to learn rarely-used features to use common ones. | [05](05-information-hiding.md) |
| **Pass-Through Method** | A method does almost nothing except pass its args to another with a similar signature. | [07](07-different-layer-different-abstraction.md) |
| **Repetition** | A nontrivial piece of code is repeated over and over. | [09](09-better-together-or-better-apart.md) |
| **Special-General Mixture** | Special-purpose code is not cleanly separated from general-purpose code. | [09](09-better-together-or-better-apart.md) |
| **Conjoined Methods** | Two methods are so interdependent you can't understand one without the other. | [09](09-better-together-or-better-apart.md) |
| **Comment Repeats Code** | All the information in a comment is obvious from the code next to it. | [12](12-why-write-comments.md), [13](13-comments-describe-non-obvious.md) |
| **Implementation Documentation Contaminates Interface** | An interface comment describes implementation details users don't need. | [13](13-comments-describe-non-obvious.md) |
| **Vague Name** | A variable/method name is too imprecise to convey useful information. | [14](14-choosing-names.md) |
| **Hard to Pick Name** | It's difficult to find a precise, intuitive name for an entity. | [14](14-choosing-names.md) |
| **Hard to Describe** | To be complete, the doc for a variable/method must be long. | [15](15-write-the-comments-first.md) |
| **Nonobvious Code** | The behaviour or meaning of a piece of code can't be understood easily. | [18](18-code-should-be-obvious.md) |

## Chapters

| # | File | Thesis in one line |
|---|---|---|
| 2 | [Nature of Complexity](02-nature-of-complexity.md) | Complexity = anything making software hard to understand/modify; spot its symptoms and causes. |
| 3 | [Working Code Isn't Enough](03-working-code-isnt-enough.md) | Strategic beats tactical: invest in design continuously, don't just make it work. |
| 4 | [Modules Should Be Deep](04-modules-should-be-deep.md) | Great modules hide a lot behind a small interface. |
| 5 | [Information Hiding (and Leakage)](05-information-hiding.md) | Each module should encapsulate a design decision; leakage is the enemy. |
| 6 | [General-Purpose Modules are Deeper](06-general-purpose-modules-are-deeper.md) | "Somewhat general-purpose" interfaces are usually simpler and deeper. |
| 7 | [Different Layer, Different Abstraction](07-different-layer-different-abstraction.md) | Adjacent layers that share an abstraction signal a problem. |
| 8 | [Pull Complexity Downwards](08-pull-complexity-downwards.md) | It's better for the module to suffer complexity than its users. |
| 9 | [Better Together or Better Apart?](09-better-together-or-better-apart.md) | When to combine vs split code; kill repetition and conjoined methods. |
| 10 | [Define Errors Out of Existence](10-define-errors-out-of-existence.md) | Reduce the number of places that must handle exceptions/special cases. |
| 11 | [Design It Twice](11-design-it-twice.md) | Consider real alternatives before committing to a design. |
| 12 | [Why Write Comments?](12-why-write-comments.md) | The four excuses for not commenting, refuted. |
| 13 | [Comments Describe the Non-Obvious](13-comments-describe-non-obvious.md) | Comments add precision and intuition the code can't; separate interface from implementation. |
| 14 | [Choosing Names](14-choosing-names.md) | Precise, consistent names create a mental image and prevent bugs. |
| 15 | [Write the Comments First](15-write-the-comments-first.md) | Comments are a design tool; hard-to-write comments reveal design smells. |
| 16 | [Modifying Existing Code](16-modifying-existing-code.md) | Stay strategic on every change; keep comments next to code, not in the commit log. |
| 17 | [Consistency](17-consistency.md) | Consistency lowers cognitive load; follow existing conventions. |
| 18 | [Code Should Be Obvious](18-code-should-be-obvious.md) | If a reader has to think hard, the code is nonobvious — a defect. |
| 19 | [Software Trends](19-software-trends.md) | Judge OO/agile/TDD/design-patterns/getters by whether they reduce complexity. |
| 20 | [Designing for Performance](20-designing-for-performance.md) | Simpler code is usually faster; measure, then optimise the critical path. |

Source: [`../../psd.pdf`](../../psd.pdf). Page numbers refer to the book's own numbering.
