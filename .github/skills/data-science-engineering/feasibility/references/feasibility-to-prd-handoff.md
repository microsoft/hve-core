---
description: 'Producer contract for the feasibility-to-PRD handoff: emission trigger, field set, verdict presence rules, candidate semantics, and regeneration obligation'
---

# Feasibility-to-PRD Handoff — Producer Contract

## Purpose

The handoff is a short, derived summary that carries a confirmed feasibility verdict and its evidence-backed candidates into PRD authoring. It exists so a PRD session can act on the study's conclusions without re-reading the whole study.

The durable study remains the authority for every machine fact. The handoff never redefines a study fact, and a disagreement between the two is always resolved in favor of the study.

`feasibility` owns this producer contract. The PRD consumer rules live in the `requirements-author` skill.

## Recognition

The payload declares its artifact kind:

```yaml
kind: feasibility-to-prd-handoff
```

`kind` states what the artifact is. It is not a compatibility version, and a consumer does not compare it against a generation number. This repository ships producer and consumer together, so there is no independent-deployment skew to negotiate.

## Emission

Emit the handoff at a confirmed Recommend exit, after the study content is final. Write it as a sibling of the study using the study filename plus the `-feasibility-to-prd-handoff.yml` suffix.

Emit for every verdict. A negative verdict still carries useful evidence into PRD authoring, so suppressing the artifact would discard it.

## Regeneration

Regenerate the handoff after every material study revision, once the revised study is final and before any downstream handoff. A material revision changes a verdict, recommendation, candidate, constraint, gap, or the evidence a candidate rests on.

The handoff carries the `study_revision_id` it was generated from. A reader compares that value against the study's current revision to judge freshness. Do not add a content hash: nothing in this repository recomputes one, so a hash field would assert a check no reader performs.

## Field set

| Field                   | Presence              | Meaning                                                                  |
|-------------------------|-----------------------|--------------------------------------------------------------------------|
| `kind`                  | Required              | Always `feasibility-to-prd-handoff`                                      |
| `handoff_id`            | Required              | UUID URN identifying this handoff instance                               |
| `generated_at`          | Required              | ISO 8601 timestamp of generation                                         |
| `study_path`            | Required              | Workspace-relative path to the study this summarizes                     |
| `study_revision_id`     | Required              | UUID URN of the exact study revision this was generated from             |
| `verdict`               | Required              | One of the four verdicts below                                           |
| `recommendation`        | Required              | Prose recommendation carried from the study                              |
| `evidence_sections`     | Required              | Named study sections supporting the recommendation                       |
| `constraints`           | Required              | Constraints the PRD must respect; each `category` uses the PRD set below |
| `gaps`                  | Required              | Unresolved evidence gaps, including unmet readiness items                |
| `functional_candidates` | Forward verdicts only | Proposed capability candidates                                           |
| `nfr_candidates`        | Forward verdicts only | Proposed quality-attribute candidates                                    |

Each candidate carries `candidate_id`, `study_item_id`, `statement`, `evidence_refs`, and an advisory `concern_hint`.

Each constraint carries a `category` and a `statement`. The `category` value comes from the PRD's own set and no other: `regulatory`, `contractual`, `technical`, `financial`, `schedule`, `organizational`, or `operational`. Describe the specific limit in `statement`, not by inventing a narrower category name.

## Evidence reference types

The handoff carries two kinds of evidence reference. They sit at different levels, resolve against different parts of the study, and are never interchangeable.

| Field               | Level          | Resolves to                                   |
|---------------------|----------------|-----------------------------------------------|
| `evidence_sections` | Top level      | A named section heading in the study          |
| `evidence_refs`     | Candidate only | An `FS-###` display reference on a study item |

`evidence_sections` values come from this closed set and no other:

* `Recommendation`
* `Problem definition and desired outcome`
* `Evidence and analysis`
* `Item narratives`
* `Review notes`

Candidate `evidence_refs` values match `FS-[0-9]{3,}` and must resolve to an item `display_ref` in the referenced study, with its matching narrative anchor.

`study_item_id` remains the durable identity. It is the item's UUID URN, and an `FS-###` display reference never substitutes for it. A display reference is a human-facing alias that can be renumbered; the UUID is what survives a revision.

The study interchange block uses its own `evidence_refs` field, whose values are UUID URNs pointing at items of class `evidence`. That field belongs to the study and is unrelated to the handoff's candidate field of the same name. Resolve each against the artifact that declares it.

## Verdict presence rules

| Verdict                        | Direction | Candidate fields                                                     |
|--------------------------------|-----------|----------------------------------------------------------------------|
| `proceed`                      | Forward   | Both present; empty arrays only when evidence supports no candidates |
| `proceed-with-scope-reduction` | Forward   | Both present; empty arrays only when evidence supports no candidates |
| `do-not-proceed`               | Negative  | Both omitted                                                         |
| `insufficient-evidence`        | Negative  | Both omitted                                                         |

Negative verdicts always retain `recommendation`, `evidence_sections`, `constraints`, and `gaps`.

## Candidate semantics

Candidates are evidence-backed proposals, never final requirements. The producer does not allocate `FR-###`, `NFR-###`, or `CON-###`, and does not route a candidate to any downstream planner.

`concern_hint` is advisory evidence describing what the concern appears to touch, such as privacy, Responsible AI, or observability. It does not select a final PRD category and does not name an owner. PRD Build decides every classification.

## Producer validation

Before publishing, confirm:

* Candidate IDs are unique, and candidate counts match the underlying study records.
* Every `evidence_sections` entry is drawn from the closed section set above.
* Every candidate `evidence_refs` entry matches `FS-[0-9]{3,}` and resolves to an item `display_ref` in the referenced study.
* Every candidate `study_item_id` is the item's UUID URN, not an `FS-###` alias.
* Constraint categories are drawn from the PRD set: `regulatory`, `contractual`, `technical`, `financial`, `schedule`, `organizational`, or `operational`.
* `study_revision_id` matches the revision of the finalized study.
* No `concern_hint` names a final PRD category or a downstream planner.

## Example — forward verdict

```yaml
kind: feasibility-to-prd-handoff
handoff_id: urn:uuid:6f3a1c58-9c2b-4d21-8f0e-2b7c5d9a4e13
generated_at: 2026-08-03T14:22:00Z
study_path: docs/data/claims-triage-feasibility.md
study_revision_id: urn:uuid:1d9b7f42-05c8-4a6e-9b31-7c2e8a5f0d64
verdict: proceed-with-scope-reduction
recommendation: >
  Adjudicated claims support automated triage. Provider notes lack the
  retention needed for the original scope, so exclude them from the first
  release.
evidence_sections:
  - Evidence and analysis
  - Item narratives
constraints:
  - category: regulatory
    statement: Provider notes retain for 90 days, below the 24-month training window.
gaps:
  - Label quality for denial reasons is unmeasured beyond a 200-row sample.
functional_candidates:
  - candidate_id: FC-01
    study_item_id: urn:uuid:2a4c6e80-3f19-4b72-a5d8-9e1f3c7b0a25
    statement: Rank incoming claims by predicted adjudication complexity.
    evidence_refs:
      - FS-001
    concern_hint: none
nfr_candidates:
  - candidate_id: NC-01
    study_item_id: urn:uuid:8b1d3f57-6c40-4e29-b7a3-5d0e2f9c4b18
    statement: Triage scores need an explanation a reviewer can act on.
    evidence_refs:
      - FS-002
    concern_hint: responsible-ai
```

## Example — negative verdict

```yaml
kind: feasibility-to-prd-handoff
handoff_id: urn:uuid:c47e2a91-8d63-4f05-b2ae-1f6d0c8b3947
generated_at: 2026-08-03T16:05:00Z
study_path: docs/data/inventory-forecast-feasibility.md
study_revision_id: urn:uuid:5e8a0b36-2c74-49d1-8f63-0a4b7d1e9c52
verdict: insufficient-evidence
recommendation: >
  Store-level demand history is too sparse to judge forecast feasibility.
  Revisit after two additional seasonal cycles are captured.
evidence_sections:
  - Evidence and analysis
  - Problem definition and desired outcome
constraints:
  - category: technical
    statement: Only 14 of 190 stores have continuous two-year history.
gaps:
  - No held-out period exists for seasonal validation.
```

## Ownership boundary

This contract defines production only. PRD Assess ingestion, Create persistence, Build disposition, and BRD coexistence are owned by the `requirements-author` skill. Downstream consumers remain read-only toward the study and own their own requirement mapping.
