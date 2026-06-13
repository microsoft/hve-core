---
brd_id: "{{brd_id}}"
title: "{{title}}"
status: "draft"
version: "1.0"
owners: ["{{owner_name}}"]
reviewers: ["{{reviewer_name}}"]
created_date: "{{created_date}}"
last_updated: "{{last_updated}}"
business_goal_ids: ["{{business_goal_id}}"]
business_goal_smart_status: "deferred"
diagram_format: "mermaid"
lineage:
  supersedes: []
  superseded_by: []
last_brd_id: null
requirement_id_prefixes:
  fr: "FR"
  ac: "AC"
  nfr: "NFR"
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

See `stakeholder-analysis` skill for Mendelow matrix patterns.

---

## Business Goals

{{business_goals}}

*Guidance*: List business goals using the SMART framework (Specific, Measurable, Achievable, Relevant, Time-bound).

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

*Guidance*: List policy, regulatory, and operational constraints as BR-### items (per `traceability-naming` skill). Each rule:

- BR-###: Rule statement
- Category: Policy | Regulatory | Operational
- Rationale: Why this rule exists
- Enforceability: Mandatory | Advisory

---

## Functional Requirements

{{functional_requirements}}

*Guidance*: List user-facing and system capabilities as FR-### items (per `traceability-naming` skill). Each requirement:

- FR-###: Requirement statement
- Actor: Who uses this capability
- Trigger: When/how capability is invoked
- Expected Outcome: What the system does
- Acceptance Criteria: Link to AC-### items

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

*Guidance*: Scope, timeline, budget, technical, and organizational constraints. Include:

- Scope Boundaries: In scope / Out of scope / Future consideration
- Timeline: Key milestones and deadlines
- Budget: Resource constraints
- Technical: Platform, architecture, integration requirements
- Organizational: Governance, approval gates, dependencies

---

## Process Models

{{diagram_fragment}}

*Guidance*: This section resolves at template-fill time to one of:

- `diagram-ascii.md` – ASCII process diagram (low-fidelity)
- `diagram-mermaid.md` – Mermaid flowchart (default)
- `diagram-figma.md` – Figma low-fidelity prototype
- Omitted entirely if `diagram_format: none`

The diagram illustrates key business or technical processes central to this BRD.

---

## Acceptance Criteria

{{acceptance_criteria}}

*Guidance*: Testable conditions for requirement completion as AC-### items (per `traceability-naming` skill and `requirements-definition` skill).

Each acceptance criterion:

- AC-###: Given [context], When [action], Then [expected outcome]
- Links to: FR-### (which Functional Requirement does this verify?)
- Status: Not Started | In Progress | Completed | Blocked

Patterns from `requirements-definition` skill: Gherkin Given/When/Then format preferred.

---

## Traceability Matrix

{{traceability_matrix_html}}

*Guidance*: Auto-generated by `update_lineage.py` (Step 2.8) at publish time. Rows: FR-### items. Columns: AC-### items, BR-### items, NFR-### items. Cell content: ✓ (traceability link exists), ○ (optional link), empty (no link).

Required coverage:

- FR↔AC: ≥1 AC per FR (mandatory)
- FR↔BR: As needed (optional)
- BR↔FR: For context (informational)

---

## Risks & Assumptions

### Key Assumptions

{{assumptions}}

*Guidance*: List assumptions about stakeholders, resources, dependencies, technical feasibility, etc. For each:

- Assumption statement
- Impact if false: High / Medium / Low
- Mitigation strategy

### Risk Register

{{risks}}

*Guidance*: Identify risks that could impact BRD realization. For each:

- Risk statement
- Probability: High / Medium / Low
- Impact: High / Medium / Low
- Mitigation action

---

## Glossary

{{glossary}}

*Guidance*: Domain-specific terminology and abbreviations. For each term:

- Term / Abbreviation
- Definition
- Context or examples

---

## Sign-Off

### Approval Checklist

- [ ] Business Sponsor: {{sponsor_name}} – Approves business case and strategic alignment
- [ ] Product Owner: {{product_owner_name}} – Approves requirements completeness and feasibility
- [ ] Technical Lead: {{technical_lead_name}} – Approves technical feasibility and constraints
- [ ] Quality Lead: {{quality_lead_name}} – Approves quality criteria and acceptance test coverage
- [ ] Legal/Compliance (if required): {{legal_contact}} – Approves regulatory and policy compliance

**Approval Date**: {{approval_date}}

---

## Disclaimer

{{disclaimer_text}}

*Guidance*: This section is populated from the shared `disclaimer-language.instructions.md` resource (DD-14) at template-fill time. See Step 5.1 for DT-aware disclaimer extension.

---

## Document Metadata

- **Template Version**: 1.0
- **HVE-Core Reference**: Scenario 6 BRD Builder Upgrade, Phase 2 Step 2.2
- **License**: CC-BY 4.0 (Microsoft HVE-Core)
- **Attribution**: Microsoft HVE-Core Team

---

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
