---
prd_id: "{{prd_id}}"
title: "{{title}}"
status: "draft"
version: "0.1.0"
owners: ["{{owner_name}}"]
reviewers: ["{{reviewer_name}}"]
created_date: "{{created_date}}"
last_updated: "{{last_updated}}"
product_goal_ids: ["GOAL-001"]
product_goal_smart_status: "deferred"
fr_to_ac_coverage_threshold_pct: 80.0
fr_to_goal_coverage_threshold_pct: 100.0
diagram_format: "mermaid"
lineage:
  supersedes: []
  superseded_by: []
source_brd_id: null
requirement_id_prefixes:
  fr: "FR"
  ac: "AC"
  nfr: "NFR"
  con: "CON"
  goal: "GOAL"
license: "CC-BY 4.0 (Microsoft HVE-Core)"
---

# {{title}}

> **{{prd_id}}** | Status: {{status}} | Version: {{version}} | Last Updated: {{last_updated}}

## Executive Summary

{{executive_summary_content}}

*Guidance*: Summarize the product opportunity, target users, strategic drivers, and scope boundaries in 3-5 paragraphs. Include the primary success metric and the release horizon.

---

## Product Context

{{product_context_content}}

*Guidance*: Describe the market opportunity, competitive landscape, user problem, and the product vision that frames this release. Capture discovery findings using [product-discovery.md](../../references/prd/product-discovery.md).

---

## Users and Personas

{{users_and_personas}}

*Guidance*: Identify the target users and personas this product serves. For each persona:

- Name / Role
- Primary jobs-to-be-done
- Key pain points
- Success outcome

When a stakeholder map is needed beyond the user personas, use [stakeholder-analysis.md](../../references/_shared/stakeholder-analysis.md) for Mendelow matrix patterns.

---

## Design Decisions

{{design_decisions}}

*Guidance*: Record material authoring or scope decisions with `DD-###` identifiers from [design-decisions.md](../../references/_shared/design-decisions.md). Example: `DD-008` records a decision that affects scope, traceability, prioritization, or downstream implementation.

---

## Product Goals

{{product_goals}}

*Guidance*: List product goals with `GOAL-###` identifiers and SMART framing. Example format:

```text
GOAL-001: Increase activated new accounts by 25% within two release cycles of launch.
Priority: MUST
KPI: 30-day rolling activation rate at or above 1.25x baseline.
```

Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules.

**SMART Evaluation** (assessed at Validate→Finalize gate per `requirements-quality` skill, scored against [smart-rubric.md](../../references/_shared/smart-rubric.md)):

- [ ] **S**pecific: Clearly defined without ambiguity
- [ ] **M**easurable: Contains quantifiable success metrics
- [ ] **A**chievable: Realistic given resources and constraints
- [ ] **R**elevant: Aligned with product strategy
- [ ] **T**ime-bound: Includes explicit deadline or release horizon

**Status**: {{product_goal_smart_status}} (populated at Validate→Finalize assessment)

---

## Functional Requirements

{{functional_requirements}}

*Guidance*: List user-facing and system capabilities as `FR-###` items. Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules. User-story framing is available in [connextra-template.md](../../references/prd/connextra-template.md) and quality screening in [invest.md](../../references/prd/invest.md). Each requirement records:

- FR-###: Requirement statement
- Actor: Who uses this capability
- Trigger: When/how capability is invoked
- Expected Outcome: What the system does
* Acceptance Criteria: Link to `AC-###` items.
* Product Goals: Link to supported `GOAL-###` items.

Quality assessment per `requirements-quality` skill applies the nine ISO/IEC/IEEE 29148:2018 §5.2.5 characteristics (necessary, appropriate, unambiguous, complete, singular, feasible, verifiable, correct, conforming).

---

## Non-Functional Requirements

*Organized by NIST SP 800-160 NFR category buckets (per `requirements-quality` skill, see [nist-800-160-nfr.md](../../references/prd/nist-800-160-nfr.md))*

### Performance and Capacity

{{nfr_performance_and_capacity}}

*Guidance*: Timing and resource behavior under stated load. NFR-### items as needed.

---

### Reliability and Resilience

{{nfr_reliability_and_resilience}}

*Guidance*: Availability, mean time between failures, recovery time objective, fault tolerance. NFR-### items as needed.

---

### Security

{{nfr_security}}

*Guidance*: Authentication, authorization, encryption, audit, and data protection with a stated mechanism or standard. NFR-### items as needed.

---

### Privacy

{{nfr_privacy}}

*Guidance*: Data classification, minimization, retention, consent, de-identification. NFR-### items as needed.

---

### Scalability and Elasticity

{{nfr_scalability_and_elasticity}}

*Guidance*: Scaling dimension and the load range over which the solution must scale. NFR-### items as needed.

---

### Maintainability and Operability

{{nfr_maintainability_and_operability}}

*Guidance*: Change effort, deployment automation, configurability, operational tooling. NFR-### items as needed.

---

### Observability

{{nfr_observability}}

*Guidance*: Required logs, metrics, traces, and alerting thresholds. NFR-### items as needed.

---

### Usability and Accessibility

{{nfr_usability_and_accessibility}}

*Guidance*: Task completion, time to first success, accessibility conformance level (for example, WCAG). NFR-### items as needed.

---

### Compatibility and Interoperability

{{nfr_compatibility_and_interoperability}}

*Guidance*: External systems, protocols, schemas, or runtimes the solution must interoperate with. NFR-### items as needed.

---

### Portability

{{nfr_portability}}

*Guidance*: Target environments, install constraints, replaceability requirements. NFR-### items as needed.

---

## Constraints

{{constraints}}

*Guidance*: List imposed, non-negotiable boundaries as `CON-###` items. Constraints bound the solution, delivery, or operating environment. Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules.

Each constraint records:

* `CON-###`: Constraint statement.
* Imposing source: Regulation, contract, platform standard, fixed external system, budget, timeline, staffing, or governance body.
* Affected boundary: Scope, timeline, budget, technology, integration, operations, compliance, or organization.
* Non-negotiability: Why the boundary cannot be changed within this PRD scope.
* Category: Regulatory, contractual, technical, financial, schedule, organizational, or operational.
* Impact: Requirement, design, delivery, or acceptance effect.

---

## Process Models

{{diagram_fragment}}

*Guidance*: This section resolves at template-fill time to one of:

* A Mermaid flowchart or related Mermaid diagram, the default.
* An ASCII process diagram for low-fidelity Discover sketches.
* Omitted entirely when `diagram_format: none`.

See [diagram-format-selector.md](../../references/_shared/diagram-format-selector.md) for selection guidance. The diagram illustrates key user or system flows central to this PRD. Do not mandate external diagram tools from the PRD template.

---

## Acceptance Criteria

{{acceptance_criteria}}

*Guidance*: Testable conditions for requirement completion as `AC-###` items. Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules.

Each acceptance criterion:

* `AC-###`: Given [context], When [action], Then [expected outcome].
* Covers: `FR-###` identifiers.
* Status: Not Started, In Progress, Completed, or Blocked.

Patterns from `requirements-quality` skill: Gherkin Given/When/Then format (see [given-when-then.md](../../references/_shared/given-when-then.md)) and EARS phrasing (see [ears-acceptance.md](../../references/prd/ears-acceptance.md)).

---

## Traceability Matrix

*Guidance*: Maintain the traceability matrix as part of the PRD. Use [traceability-matrix.md](../../references/_shared/traceability-matrix.md) for the canonical table shapes and formulas.

### FR-to-AC Coverage

{{fr_to_ac_traceability_table}}

Coverage formula: `(count of FR rows with one or more AC links / count of FR rows) * 100`.

If the PRD has zero FR rows, report `0.0%` coverage. Treat the result as a caution when the PRD is intentionally non-functional-only and as blocking when the active threshold requires functional scope. Default threshold: `{{fr_to_ac_coverage_threshold_pct}}%`.

### FR-to-GOAL Alignment

{{fr_to_goal_traceability_table}}

Coverage formula: `(count of FR rows with one or more GOAL links / count of FR rows) * 100`.

Target: `{{fr_to_goal_coverage_threshold_pct}}%`. Any gap requires an active waiver in `signoff.waivers[]` before Finalize exit.

---

## MVP and Release Framing

{{mvp_framing}}

*Guidance*: Define the minimum viable scope and the release boundary using [mvp-framing.md](../../references/prd/mvp-framing.md). Identify which `FR-###` and `GOAL-###` items are in the first release versus deferred, and the rationale for the cut line.

---

## Success Metrics

{{success_metrics}}

*Guidance*: Define the measurement plan for each product goal using [metrics-frameworks.md](../../references/prd/metrics-frameworks.md). For each metric:

* Metric name and definition.
* Baseline and target.
* Measurement window and data source.
* Linked `GOAL-###` identifier.

---

## Risks and Assumptions

### Key Assumptions

{{assumptions}}

*Guidance*: List assumptions about users, resources, dependencies, technical feasibility, etc. For each:

* Assumption statement.
* Impact if false: High, medium, or low.
* Mitigation strategy.

### Risk Register

{{risks}}

*Guidance*: Identify risks that could impact PRD realization. For each:

* Risk statement.
* Probability: High, medium, or low.
* Impact: High, medium, or low.
* Mitigation action.

---

## Glossary

{{glossary}}

*Guidance*: Domain-specific terminology and abbreviations. For each term:

* Term or abbreviation.
* Definition.
* Context or examples.

---

## Sign-Off

### Approval Checklist

* Product Sponsor: {{sponsor_name}} - Approves product opportunity and strategic alignment.
* Product Owner: {{product_owner_name}} - Approves requirements completeness and feasibility.
* Technical Lead: {{technical_lead_name}} - Approves technical feasibility and constraints.
* Quality Lead: {{quality_lead_name}} - Approves quality criteria and acceptance test coverage.
* Legal/Compliance: {{legal_contact}} - Approves regulatory and policy compliance when required.

Approval date: {{approval_date}}

### Waivers

{{waivers}}

*Guidance*: Record waiver ID, covered metric or finding, grantor, rationale, approval date, and expiration date. FR-to-GOAL coverage gaps require a waiver before Finalize exit.

### Handoff Readiness

{{handoff_readiness}}

*Guidance*: Before Finalize exit, record the final quality report reference, PRD artifact SHA-256, identifier counts, traceability metrics, approver decisions, approval dates, and waiver status used to confirm the PRD is ready for downstream implementation.

---

## Disclaimer

{{disclaimer_text}}

*Guidance*: Populate this section from the shared disclaimer-language instructions when the PRD is prepared for governed use.

---

## Document Metadata

* Template Version: 1.0.0.
* Canonical Template: `requirements-author/templates/prd/prd-full.md`.
* License: CC-BY 4.0 (Microsoft HVE-Core).
* Attribution: Microsoft HVE-Core Team.
