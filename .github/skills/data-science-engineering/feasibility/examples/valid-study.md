---
title: Northwind recommendation feasibility study
description: Valid profile fixture covering evidence, a capability candidate, revision history, and dependency traceability
---

## Recommendation

Proceed with a bounded pilot after confirming the retained-data access path.

<!-- BEGIN FEASIBILITY-STUDY-INTERCHANGE -->
```yaml
profile: feasibility-study-interchange
profile_version: 1.0.0
study:
  study_id: urn:uuid:10000000-0000-4000-8000-000000000001
  study_revision_id: urn:uuid:10000000-0000-4000-8000-000000000003
  revision_of: urn:uuid:10000000-0000-4000-8000-000000000002
  title: Northwind recommendation feasibility study
  status: active
  location: docs/data/northwind-feasibility-study.md
  created_at: "2026-08-01T09:00:00Z"
  modified_at: "2026-08-02T12:00:00Z"
  provenance:
    attributed_to: Northwind delivery team
    source_refs:
      - docs/data/northwind-catalog.md
    generated_at: "2026-08-02T12:00:00Z"
items:
  - item_id: urn:uuid:20000000-0000-4000-8000-000000000001
    item_revision_id: urn:uuid:20000000-0000-4000-8000-000000000002
    revision_of: null
    display_ref: FS-001
    narrative_anchor: fs-001
    class: evidence
    title: Historical recommendation outcomes are available
    statement: Six months of recommendation outcomes can be joined to customer interactions.
    status: accepted
    planning_relevance: context
    confidence: high
    criteria_status: not-applicable
    acceptance_criteria: []
    evidence_refs: []
    relations: []
    provenance:
      attributed_to: Data owner
      source_refs:
        - docs/data/northwind-catalog.md#recommendation-outcome
      generated_at: "2026-08-01T11:00:00Z"
    review:
      needs_review: false
      reasons: []
    location: "#fs-001"
    lifecycle:
      effective_at: null
      reason: null
      predecessor_ids: []
      successor_ids: []
  - item_id: urn:uuid:20000000-0000-4000-8000-000000000010
    item_revision_id: urn:uuid:20000000-0000-4000-8000-000000000012
    revision_of: urn:uuid:20000000-0000-4000-8000-000000000011
    display_ref: FS-002
    narrative_anchor: fs-002
    class: capability-candidate
    title: Rank recommendation candidates
    statement: The proposed system ranks eligible recommendations for each account.
    status: proposed
    planning_relevance: candidate
    confidence: medium
    criteria_status: partial
    acceptance_criteria:
      - The pilot produces a ranked list for every eligible account in the holdout set.
    evidence_refs:
      - urn:uuid:20000000-0000-4000-8000-000000000001
    relations:
      - relation_id: urn:uuid:30000000-0000-4000-8000-000000000001
        type: evidenced-by
        target: urn:uuid:20000000-0000-4000-8000-000000000001
        rationale: Historical outcomes provide evaluation labels.
        confidence: high
        provenance:
          attributed_to: Feasibility team
          source_refs:
            - "#fs-001"
          generated_at: "2026-08-02T10:00:00Z"
        review:
          needs_review: false
          reasons: []
    provenance:
      attributed_to: Product owner
      source_refs:
        - notes/recommendation-workshop.md
      generated_at: "2026-08-02T10:00:00Z"
    review:
      needs_review: true
      reasons:
        - threshold-not-yet-defined
    location: "#fs-002"
    lifecycle:
      effective_at: null
      reason: null
      predecessor_ids: []
      successor_ids: []
revision_registry:
  - concept_id: urn:uuid:10000000-0000-4000-8000-000000000001
    concept_kind: study
    revision_id: urn:uuid:10000000-0000-4000-8000-000000000002
    revision_of: null
    recorded_at: "2026-08-01T09:00:00Z"
  - concept_id: urn:uuid:10000000-0000-4000-8000-000000000001
    concept_kind: study
    revision_id: urn:uuid:10000000-0000-4000-8000-000000000003
    revision_of: urn:uuid:10000000-0000-4000-8000-000000000002
    recorded_at: "2026-08-02T12:00:00Z"
  - concept_id: urn:uuid:20000000-0000-4000-8000-000000000001
    concept_kind: item
    revision_id: urn:uuid:20000000-0000-4000-8000-000000000002
    revision_of: null
    recorded_at: "2026-08-01T11:00:00Z"
  - concept_id: urn:uuid:20000000-0000-4000-8000-000000000010
    concept_kind: item
    revision_id: urn:uuid:20000000-0000-4000-8000-000000000011
    revision_of: null
    recorded_at: "2026-08-01T14:00:00Z"
  - concept_id: urn:uuid:20000000-0000-4000-8000-000000000010
    concept_kind: item
    revision_id: urn:uuid:20000000-0000-4000-8000-000000000012
    revision_of: urn:uuid:20000000-0000-4000-8000-000000000011
    recorded_at: "2026-08-02T10:00:00Z"
```
<!-- END FEASIBILITY-STUDY-INTERCHANGE -->

## Problem definition and desired outcome

Determine whether historical interaction and outcome data supports a recommendation pilot.

## Evidence and analysis

The retained outcomes provide labels, while the acceptance threshold remains a product decision.

## Item narratives

### FS-001: Historical recommendation outcomes are available

The data owner confirmed the join path and the retained time window.

### FS-002: Rank recommendation candidates

The candidate is actionable, but the product owner must define the ranking-quality threshold.

## Review notes

The threshold gap remains explicit and prevents false completion.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
