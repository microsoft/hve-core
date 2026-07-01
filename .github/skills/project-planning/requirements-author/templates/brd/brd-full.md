---
brd_id: "{{brd_id}}"
title: "{{title}}"
status: "draft"
version: "0.1.0"
owners: ["{{owner_name}}"]
reviewers: ["{{reviewer_name}}"]
created_date: "{{created_date}}"
last_updated: "{{last_updated}}"
business_goal_ids: ["BG-001"]
business_goal_smart_status: "deferred"
fr_to_ac_coverage_threshold_pct: 80.0
diagram_format: "mermaid"
lineage:
  supersedes: []
  superseded_by: []
last_brd_id: null
requirement_id_prefixes:
  fr: "FR"
  ac: "AC"
  nfr: "NFR"
  con: "CON"
  br: "BR"
license: "CC-BY 4.0 (Microsoft HVE-Core)"
---

# {{title}}

> **{{brd_id}}** | Status: {{status}} | Version: {{version}} | Last Updated: {{last_updated}}

## Executive Summary

{{executive_summary_content}}

*Guidance*: Summarize the business case, strategic drivers, key decisions, and scope boundaries in 3-5 paragraphs. Include the primary success metric.

---

## Business Context

{{business_context_content}}

*Guidance*: Describe market conditions, competitive landscape, organizational strategy, and external constraints influencing this initiative.

---

## Stakeholders

{{stakeholders_list}}

*Guidance*: Identify stakeholders using the Mendelow Power/Interest matrix. For each stakeholder:

- Name / Role
- Power (High / Medium / Low)
- Interest (High / Medium / Low)
- Engagement Strategy

See [stakeholder-analysis.md](../../references/_shared/stakeholder-analysis.md) for Mendelow matrix patterns.

---

## Design Decisions

{{design_decisions}}

*Guidance*: Record material authoring or scope decisions with `DD-###` identifiers from [design-decisions.md](../../references/_shared/design-decisions.md). Example: `DD-008` records a decision that affects scope, traceability, prioritization, or downstream PRD interpretation.

---

## Business Goals

{{business_goals}}

*Guidance*: List business goals with `BG-###` identifiers and SMART framing. Example format:

```text
BG-001: Reduce average claim adjudication time by 30% within 12 months of launch.
Priority: MUST
KPI: 30-day rolling average adjudication time at or below 70% of baseline.
```

Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules.

**SMART Evaluation** (assessed at Define→Govern gate per `requirements-definition` skill):

- [ ] **S**pecific: Clearly defined without ambiguity
- [ ] **M**easurable: Contains quantifiable success metrics
- [ ] **A**chievable: Realistic given resources and constraints
- [ ] **R**elevant: Aligned with organizational strategy
- [ ] **T**ime-bound: Includes explicit deadline

**Status**: {{business_goal_smart_status}} (populated at Define→Govern assessment)

---

## Business Rules

{{business_rules}}

*Guidance*: List standing business rules as `BR-###` items. A business rule is a policy, regulatory obligation, or operating rule the solution must uphold and that typically outlives this solution. Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules. Each rule records:

* `BR-###`: Rule statement.
* Category: Policy, regulatory, contractual, or operational.
* Rationale: Why this rule exists.
* Enforceability: Mandatory or advisory.
* Enforcing FRs: `FR-###` identifiers when known.

---

## Functional Requirements

{{functional_requirements}}

*Guidance*: List user-facing and system capabilities as `FR-###` items. Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules. Each requirement records:

- FR-###: Requirement statement
- Actor: Who uses this capability
- Trigger: When/how capability is invoked
- Expected Outcome: What the system does
* Acceptance Criteria: Link to `AC-###` items.
* Business Goals: Link to supported `BG-###` items.

Quality assessment per `requirements-definition` skill applies the nine ISO/IEC/IEEE 29148:2018 §5.2.5 characteristics (necessary, appropriate, unambiguous, complete, singular, feasible, verifiable, correct, conforming).

---

## Non-Functional Requirements

*Organized by ISO/IEC 25010 Quality Characteristics (per `requirements-definition` skill)*

### Functional Suitability

{{nfr_functional_suitability}}

*Guidance*: Capability appropriateness, accuracy, interoperability, compliance. NFR-### items as needed.

---

### Performance Efficiency

{{nfr_performance_efficiency}}

*Guidance*: Time behavior, resource utilization. NFR-### items as needed.

---

### Compatibility

{{nfr_compatibility}}

*Guidance*: Coexistence with other systems, interoperability. NFR-### items as needed.

---

### Usability

{{nfr_usability}}

*Guidance*: Learnability, user guidance, accessibility. NFR-### items as needed.

---

### Reliability

{{nfr_reliability}}

*Guidance*: Maturity, availability, fault tolerance, recoverability. NFR-### items as needed.

---

### Security

{{nfr_security}}

*Guidance*: Confidentiality, integrity, authentication, non-repudiation. NFR-### items as needed.

---

### Maintainability

{{nfr_maintainability}}

*Guidance*: Modularity, reusability, analyzability, modifiability, testability. NFR-### items as needed.

---

### Portability

{{nfr_portability}}

*Guidance*: Adaptability, installability, replaceability. NFR-### items as needed.

---

## Constraints

{{constraints}}

*Guidance*: List imposed, non-negotiable boundaries as `CON-###` items. Constraints are not standing business rules. They bound the solution, delivery, or operating environment. Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules.

Each constraint records:

* `CON-###`: Constraint statement.
* Imposing source: Regulation, contract, platform standard, fixed external system, budget, timeline, staffing, or governance body.
* Affected boundary: Scope, timeline, budget, technology, integration, operations, compliance, or organization.
* Non-negotiability: Why the boundary cannot be changed within this BRD scope.
* Category: Regulatory, contractual, technical, financial, schedule, organizational, or operational.
* Impact: Requirement, design, delivery, or acceptance effect.

---

## Process Models

{{diagram_fragment}}

*Guidance*: This section resolves at template-fill time to one of:

* `diagram-mermaid.md`: Mermaid flowchart or related Mermaid diagram, the default.
* `diagram-ascii.md`: ASCII process diagram for low-fidelity Discover sketches.
* Omitted entirely when `diagram_format: none`.

The diagram illustrates key business or technical processes central to this BRD. Do not mandate external diagram tools from the BRD template.

---

## Acceptance Criteria

{{acceptance_criteria}}

*Guidance*: Testable conditions for requirement completion as `AC-###` items. Use [id-schema.md](../../references/_shared/id-schema.md) for identifier prefix and digit rules.

Each acceptance criterion:

* `AC-###`: Given [context], When [action], Then [expected outcome].
* Covers: `FR-###` identifiers.
* Status: Not Started, In Progress, Completed, or Blocked.

Patterns from `requirements-definition` skill: Gherkin Given/When/Then format preferred.

---

## Traceability Matrix

*Guidance*: Maintain the traceability matrix as part of the BRD. Use [traceability-matrix.md](../../references/_shared/traceability-matrix.md) for the canonical table shapes and formulas.

### FR-to-AC Coverage

{{fr_to_ac_traceability_table}}

Coverage formula: `(count of FR rows with one or more AC links / count of FR rows) * 100`.

If the BRD has zero FR rows, report `0.0%` coverage. Treat the result as a caution when the BRD is intentionally non-functional-only and as blocking when the active threshold requires functional scope.

### FR-to-BG Alignment

{{fr_to_bg_traceability_table}}

Coverage formula: `(count of FR rows with one or more BG links / count of FR rows) * 100`.

Target: `100.0%`. Any gap requires an active waiver in `signoff.waivers[]` before Govern handoff.

### BR-to-FR Enforcement

{{br_to_fr_traceability_table}}

Use this view to show which functional requirements enforce standing business rules. `(none)` is allowed only when the BR is enforced outside the BRD solution scope or the missing FR is captured as an open item.

---

## Risks and Assumptions

### Key Assumptions

{{assumptions}}

*Guidance*: List assumptions about stakeholders, resources, dependencies, technical feasibility, etc. For each:

* Assumption statement.
* Impact if false: High, medium, or low.
* Mitigation strategy.

### Risk Register

{{risks}}

*Guidance*: Identify risks that could impact BRD realization. For each:

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

* Business Sponsor: {{sponsor_name}} - Approves business case and strategic alignment.
* Product Owner: {{product_owner_name}} - Approves requirements completeness and feasibility.
* Technical Lead: {{technical_lead_name}} - Approves technical feasibility and constraints.
* Quality Lead: {{quality_lead_name}} - Approves quality criteria and acceptance test coverage.
* Legal/Compliance: {{legal_contact}} - Approves regulatory and policy compliance when required.

Approval date: {{approval_date}}

### Waivers

{{waivers}}

*Guidance*: Record waiver ID, covered metric or finding, grantor, rationale, approval date, and expiration date. FR-to-BG coverage gaps require a waiver before `BRD_TO_PRD_HANDOFF_V1` can be emitted.

### Handoff Readiness

{{handoff_readiness}}

*Guidance*: Before Govern exit, record the final quality report reference, BRD artifact SHA-256, identifier counts, traceability metrics, approver decisions, approval dates, and waiver status used to emit the BRD-to-PRD handoff.

---

## Disclaimer

{{disclaimer_text}}

*Guidance*: Populate this section from the shared disclaimer-language instructions when the BRD is prepared for governed use.

---

## Document Metadata

* Template Version: 1.0.0.
* Canonical Template: `requirements-author/templates/brd/brd-full.md`.
* License: CC-BY 4.0 (Microsoft HVE-Core).
* Attribution: Microsoft HVE-Core Team.
