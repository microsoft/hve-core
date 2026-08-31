---
description: 'Cite-only ISTQB testability heuristics the BRD Builder applies during Define rewriting - five short heuristics that detect requirements which cannot be verified by an obvious method, used before formal ISO 29148 verifiable scoring'
---

# ISTQB Testability Heuristics (Cite-Only)

This document is a cite-only summary. It names the ISTQB Glossary as the source of the testability vocabulary the BRD Builder applies, lists five short heuristics in original Microsoft prose, and explains where they fit in the Define-phase workflow. It does not redistribute ISTQB Glossary text.

## What This Document Is

The ISTQB (International Software Testing Qualifications Board) Glossary is the canonical source for software-testing terminology used across the BRD Builder and downstream PRD workflow. The Glossary defines testability as the degree to which a component or system can be tested; the BRD Builder applies a small set of heuristics derived from that definition during Define-phase requirement rewriting.

The heuristics below are original HVE-Core paraphrases informed by, but not quoted from, the ISTQB Glossary. The Glossary itself is cited by name only; see [https://glossary.istqb.org/](https://glossary.istqb.org/) for the authoritative entries.

## When To Apply

Apply these heuristics during Define-phase requirement rewriting, *before* scoring the requirement against the ISO 29148 *verifiable* attribute in [iso-29148-quality-gate.md](iso-29148-quality-gate.md). The heuristics are diagnostic; they suggest the smallest edit that would restore testability. They are not themselves scored and they do not appear in the combined Define-exit rubric.

The heuristics are also used by the `BRD Quality Reviewer` subagent when it explains a low *verifiable* score in its narrative.

## The Five Heuristics

### 1. Observable Outcome

A requirement is testable only if its outcome can be observed by a tester without opening the implementation.

* If the outcome is internal state with no external indicator, ask the stakeholder which observable signal (UI element, API response, log entry, metric, downstream event) marks the outcome.
* If no observable signal exists or can be added, the requirement is not testable as written and must be rewritten.

### 2. Decidable Pass Condition

A requirement is testable only if the pass condition is decidable: a single examiner can determine pass or fail without negotiation.

* Vague modifiers (`fast`, `responsive`, `intuitive`, `secure`) are not decidable; they must be replaced with a threshold or with a named external standard.
* When a threshold is unknown, capture the open question rather than leaving the modifier in place.

### 3. Bounded Test Conditions

A requirement is testable only if the conditions under which the behavior must hold are bounded.

* Conditions cover input range, environment (browser, locale, network, identity), data state, and timing.
* If any dimension is unbounded ("under all conditions", "for any input"), narrow it explicitly or attach a sampling strategy that defines the scope of verification.

### 4. Independent of Implementation

A requirement is testable only if the test does not require the same code path that implements the requirement.

* A statement of the form "the solution shall implement X" is implementation prescription, not a requirement; rewrite it as a behavior or property the solution must exhibit.
* Verification should reference an external method (test, inspection, demonstration, analysis), not an internal artifact authored by the implementer.

### 5. Repeatable

A requirement is testable only if the verification can be repeated and the result is deterministic given the stated conditions.

* If the requirement's outcome depends on probabilistic behavior (machine-learning models, randomized algorithms, eventual consistency), the requirement must state the acceptable result distribution and the sample size.
* If the requirement depends on a one-time event, attach a re-verification strategy (recorded test data, replay harness, mock service) so the result can be reproduced.

## How To Use The Heuristics

For each requirement under review:

1. Walk the five heuristics in order.
2. The first heuristic that fails is the testability defect; record it as a short note attached to the requirement.
3. Edit the requirement to address the defect, then re-walk the heuristics.
4. When all five heuristics pass, return to the ISO 29148 *verifiable* anchor scale in [iso-29148-quality-gate.md](iso-29148-quality-gate.md) and assign the formal score.

## Why Cite-Only

The ISTQB Glossary is published by the International Software Testing Qualifications Board under terms that allow lookup and citation but do not permit verbatim redistribution in open-source materials. The heuristics above are Microsoft paraphrases informed by the Glossary's testability vocabulary; the Glossary is cited by name only.

## Upstream Source

[https://glossary.istqb.org/](https://glossary.istqb.org/) - ISTQB Glossary, where current entries and their licensing terms are obtained.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The ISTQB Glossary is the property of the International Software Testing Qualifications Board and is subject to the publisher's terms at the upstream source.


