---
title: ASR Trigger Taxonomy
description: Closed enum of eight Architecturally Significant Requirement (ASR) trigger kinds enforced by the ADR frontmatter validator (GP-07)
author: microsoft/hve-core
ms.date: 2026-05-02
ms.topic: reference
keywords:
  - adr
  - architecture-decision-record
  - asr
  - madr
  - project-planning
---

# ASR Trigger Taxonomy (GP-07)

Architecturally Significant Requirement (ASR) triggers recorded in ADR frontmatter under `asrTriggers[].kind` are drawn from a closed enum of eight kinds. No other values are permitted. The frontmatter validator rejects unknown values with a `ASR_KIND_UNKNOWN` error. Adding a new kind requires a separate ADR amending the taxonomy; ad-hoc extension during authoring is prohibited.

## cost

- **Triggers**: a decision that materially changes cloud spend, license fees, total cost of ownership, or the cost model (capex vs opex, per-seat vs per-transaction).
- **Signals**: monthly run-rate change above the project's threshold, a new vendor contract, a switch between reserved and on-demand pricing, or a unit-economics shift.
- **Evidence**: link to a cost estimate, FinOps dashboard, vendor quote, or budget approval.

## performance

- **Triggers**: a decision that changes latency, throughput, response-time distribution (p95/p99), or resource utilization characteristics for a user-facing or batch workload.
- **Signals**: a stated SLO, a performance test result, a known hot path, or a workload profile that drives the choice between options.
- **Evidence**: link to a benchmark, load-test report, SLO document, or profiling capture.

## security

- **Triggers**: a decision that affects authentication, authorization, secret handling, data protection, attack surface, or trust boundaries.
- **Signals**: a new external interface, a change in data classification handled, a threat-model finding, or a security review action item.
- **Evidence**: link to a threat model, security review, STRIDE analysis, or compliance control mapping.

## compliance

- **Triggers**: a decision driven by regulatory, contractual, or policy obligations (for example, GDPR, HIPAA, PCI-DSS, SOC 2, FedRAMP, internal data-residency policy).
- **Signals**: a named regulation or contractual clause, an auditor request, a data-residency constraint, or a retention requirement.
- **Evidence**: link to the regulation citation, contract section, audit finding, or policy document.

## availability

- **Triggers**: a decision that changes the failure modes, recovery characteristics, or uptime profile of the system (RTO, RPO, redundancy posture, blast radius).
- **Signals**: a stated availability SLO, a single-point-of-failure observation, a regional-failover requirement, or a disaster-recovery commitment.
- **Evidence**: link to an availability SLO, DR runbook, failure-mode analysis, or incident postmortem.

## scalability

- **Triggers**: a decision that affects horizontal or vertical scaling headroom, partitioning, sharding, or the system's response to demand growth.
- **Signals**: a projected growth curve, a saturation observation in current capacity, a known scaling cliff, or a multi-tenant fan-out concern.
- **Evidence**: link to a capacity plan, growth forecast, load-test extrapolation, or saturation metric.

## maintainability

- **Triggers**: a decision that affects long-term changeability, contributor onboarding, technology consolidation, or technical-debt trajectory.
- **Signals**: a deprecation deadline, a polyglot proliferation concern, a single-maintainer risk, or a documentation-debt observation.
- **Evidence**: link to a deprecation notice, technology-radar entry, contributor survey, or technical-debt register.

## evolvability

- **Triggers**: a decision that materially changes the system's capacity to absorb future technology shifts, swap dependencies, or extend behavior without rewrite. Distinct from `maintainability`, which targets near-term changeability and contributor experience; `evolvability` targets long-horizon adaptability and protection of optionality.
- **Signals**: an anticipated platform migration, an expected protocol or standard evolution, a multi-year horizon for replaceability of a core component, a modular boundary that preserves substitution headroom, or coupling that would foreclose a known future change.
- **Evidence**: link to a roadmap, technology-radar entry, dependency end-of-life schedule, architectural fitness function, or extensibility evaluation.

## Per-Trigger Schema

Each entry in `asrTriggers[]` conforms to the following shape. Field rules:

- `kind`: required. One of the eight values above. Closed enum; unknown values are rejected.
- `evidence`: required free-text reference (link, document title, ticket ID, requirement ID, or quoted constraint). Empty strings are rejected.
- `note`: required free-text rationale of 280 characters or fewer explaining why the trigger applies. Strings longer than 280 characters are rejected.

```yaml
asrTriggers:
  - kind: <one of: cost | performance | security | compliance | availability | scalability | maintainability | evolvability>
    evidence: <required, non-empty reference>
    note: <required, ≤ 280 chars>
```

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
