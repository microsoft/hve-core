---
name: code-review-specialist
description: 'Review assigned changes through one added non-functional lens: privacy, performance, supply chain, or responsible AI. Use for the added reviewers in Code Review.'
license: CC-BY-4.0
user-invocable: false
---

# Specialist review

## Goal

Find consequential problems in the assigned change through the one lens the
parent names. Use `code-review-core`, activating it when not preloaded, and
activate the lens's criteria skill by name.

## Lenses

| Lens             | What to look at in the changed code                                                                                            | Criteria                                                                                | Deeper follow-up                                        |
|------------------|--------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|---------------------------------------------------------|
| `privacy`        | Personal data that is collected, logged, stored, shared, or kept, and how consent, minimization, retention, and deletion apply | `privacy-by-design`                                                                     | Privacy Reviewer                                        |
| `performance`    | Work on changed paths that grows with input or traffic: complexity, blocking I/O, unbounded memory, and repeated calls         | Budgets and SLOs the project states; `performance-slo-planner` for how they are defined | Budget and load planning with `performance-slo-planner` |
| `supply-chain`   | New or updated dependencies, lockfiles, pinning, workflow permissions, downloaded tools and their checksums, and provenance    | `supply-chain-security`                                                                 | SSSC Reviewer                                           |
| `responsible-ai` | Model calls, prompts and agent instructions, AI output shown to people, human oversight, disclosure, and misuse paths          | `rai-standards`                                                                         | RAI Reviewer                                            |

A missing or unknown lens is a blocked result. Do not pick one yourself.

## Review

Read only the criteria references that fit the changed surface. When the
assigned area has nothing the lens covers, complete with a not-applicable
reason that says what you checked.

A finding needs a reachable changed path, a concrete consequence for someone
affected, and evidence from the captured change or its context. Cite the
criterion it relies on. A performance finding also needs evidence of the input
size, call frequency, or stated budget that makes the cost matter. Without that
evidence, record an observation. Check existing controls and counter-evidence
before reporting.

Leave correctness to functional review, exploitable weaknesses to security
review, and user barriers to accessibility review. Note an overlap in an
observation instead of grading it a second time. Describe personal data and
secrets by type; never copy their values into a result.

## Completion

Record the lens, the criteria you applied, and where they came from in the
result's observations. When the change needs a full audit, name the deeper
follow-up from the table in an observation; do not start one. Stop unavailable
when the lens's criteria skill cannot be loaded. No applicable criteria means
missing evidence, not a clean review.
