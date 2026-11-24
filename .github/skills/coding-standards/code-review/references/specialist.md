---
description: 'Opt-in non-functional specialist vectors for Code Review (privacy, performance, sssc, and rai). Read only when explicitly requested by the user.'
---

# Non-functional specialist review (opt-in)

> [!IMPORTANT]
> Read this reference and activate the owning criteria skill **only** when the user explicitly requests `privacy`, `performance`, `sssc` (supply-chain security), or `rai` (Responsible AI) review on specific areas or on the whole review. Never preload this file or its criteria skills during a default functional review.

## Goal

Find consequential issues in the assigned areas through the single requested non-functional vector (`privacy`, `performance`, `sssc`, or `rai`). Follow [review-contract.md](review-contract.md) and activate **only** the criteria skill for the assigned vector.

## Vectors

| Vector        | What to inspect in the assigned areas                                                                                          | Criteria skill (load only for this vector)             | Deeper audit follow-up                                  |
|---------------|--------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------|---------------------------------------------------------|
| `privacy`     | Personal data collected, logged, stored, shared, or retained, plus consent, minimization, retention, and deletion controls     | `privacy-by-design`                                    | Privacy Planner / Privacy review                        |
| `performance` | Algorithmic complexity, blocking I/O, repeated queries, and unbounded memory on paths that scale with input or request volume  | Stated project budgets/SLOs; `performance-slo-planner` | Budget and load planning with `performance-slo-planner` |
| `sssc`        | Added or updated dependencies, lockfiles, SHA pinning, workflow permissions, downloaded binaries, checksums, and provenance    | `supply-chain-security`                                | SSSC Planner                                            |
| `rai`         | Model invocations, system/agent prompts, human oversight gates, user-facing AI disclosure, content boundaries, and misuse risk | `rai-standards`                                        | RAI Planner                                             |

A missing or unknown vector stops as `blocked`. Never select or bundle unrequested vectors on your own.

## Review

Read only the criteria references inside the loaded skill that match the assigned files and hunks. When an assigned area contains no surface relevant to the requested vector, complete with a concise `notApplicable` reason naming what was checked.

Every finding requires a reachable changed path, a concrete consequence, captured anchors, a cited `criterion`, and its matching `vector` (`privacy`, `performance`, `sssc`, or `rai`). A `performance` finding also requires evidence of input scale, call frequency, or a stated SLO budget that makes the cost material; otherwise record a factual observation. Check existing controls and counter-evidence first, and never copy secret or personal-data values into results.

## Completion

Record the vector, loaded criteria skill, and reference provenance in `observations`. When a broader repository-wide assessment is warranted, note the deeper follow-up from the table in `observations` without launching it. Stop `unavailable` if the vector's criteria skill cannot be loaded.
