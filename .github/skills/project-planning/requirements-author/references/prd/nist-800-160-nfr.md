---
description: 'PRD NFR taxonomy reference - non-functional-requirement category-presence checklist derived from NIST SP 800-160 Vol. 1 Appendix E with repository-original category buckets and presence indicators; deliberately substitutes for ISO 25010 on the PRD side per DD-02'
---

# NIST SP 800-160 NFR Taxonomy (PRD Side)

This document supplies the non-functional-requirement (NFR) category checklist the PRD Builder applies at PRD validation. It is anchored to NIST SP 800-160 Volume 1 (Appendix E design-principle and quality framing) and presents the categories as a binary presence checklist in original Microsoft prose. Per DD-02, the PRD side deliberately uses the NIST 800-160 framing for its NFR taxonomy instead of the ISO/IEC 25010 model used on the BRD side. This is a scoped divergence, not a merged taxonomy.

## Why NIST 800-160 on the PRD side (DD-02)

The BRD NFR taxonomy uses ISO/IEC 25010 ([iso-25010-nfr-taxonomy.md](../brd/iso-25010-nfr-taxonomy.md)). The PRD side substitutes NIST SP 800-160 Vol. 1 because:

* NIST SP 800-160 Vol. 1 is a U.S. Government publication in the public domain, so its category vocabulary can be named freely without a paywall barrier.
* Its systems-security-engineering framing aligns the PRD's NFR conversation with the security, privacy, and operational sections of the canonical PRD template.

The two taxonomies are kept separate by design. The PRD does not map its NFRs onto ISO 25010 categories, and the BRD does not adopt the NIST buckets. Each side's quality reviewer scores only its own taxonomy.

## DD-02 posture

The PRD Builder treats the NFR taxonomy as a *category-presence checklist*, not a per-attribute enumeration. The validation question for each category is binary: *is at least one NFR in the PRD that targets this category?* Missing categories are flagged qualitatively and do not by themselves block PRD finalization; requirement-level quality uses the neutral characteristics in [iso-29148-quality-attrs.md](../_shared/iso-29148-quality-attrs.md) with PRD-owned scoring rules, and goal-level quality uses [smart-rubric.md](../_shared/smart-rubric.md).

## The NFR category buckets (repository-original)

The buckets below are repository-original groupings informed by the NIST SP 800-160 Vol. 1 design-principle framing. Each bucket names a presence indicator the PRD Builder checks.

### 1. Performance & Capacity

Timing and resource behavior under stated load.

Presence indicator: at least one NFR sets a quantitative threshold for response time, throughput, capacity, or resource utilization.

### 2. Reliability & Resilience

Continuity of operation under stress, fault, and recovery conditions.

Presence indicator: at least one NFR sets a target for availability, mean time between failures, recovery time objective, or fault tolerance.

### 3. Security

Protection of data and functions from unauthorized access, modification, or disclosure.

Presence indicator: at least one NFR sets an authentication, authorization, encryption, audit, or data-protection requirement with a stated mechanism or standard.

### 4. Privacy

Lawful, minimal, and transparent handling of personal data.

Presence indicator: at least one NFR sets a data-classification, minimization, retention, consent, or de-identification requirement.

### 5. Scalability & Elasticity

Ability to grow or shrink capacity to meet demand.

Presence indicator: at least one NFR names a scaling dimension and the load range over which the solution must scale.

### 6. Maintainability & Operability

Ease of change, deployment, and day-2 operation.

Presence indicator: at least one NFR sets a target for change effort, deployment automation, configurability, or operational tooling.

### 7. Observability

Ability to understand internal state from external signals.

Presence indicator: at least one NFR names required logs, metrics, traces, or alerting thresholds.

### 8. Usability & Accessibility

Effectiveness, efficiency, and inclusiveness for specified users.

Presence indicator: at least one NFR sets a target for task completion, time to first success, or an accessibility conformance level (for example, WCAG).

### 9. Compatibility & Interoperability

Ability to coexist and exchange data with other systems.

Presence indicator: at least one NFR names an external system, protocol, schema, or runtime the solution must interoperate with.

### 10. Portability

Ability to move between environments.

Presence indicator: at least one NFR names a target environment, install constraint, or replaceability requirement.

## Validation checklist

The PRD Quality Reviewer emits this checklist as part of `PRD_STANDARD_FINDINGS_V1`:

| Category                         | Present (true / false) | Notes |
|----------------------------------|------------------------|-------|
| Performance & Capacity           |                        |       |
| Reliability & Resilience         |                        |       |
| Security                         |                        |       |
| Privacy                          |                        |       |
| Scalability & Elasticity         |                        |       |
| Maintainability & Operability    |                        |       |
| Observability                    |                        |       |
| Usability & Accessibility        |                        |       |
| Compatibility & Interoperability |                        |       |
| Portability                      |                        |       |

This checklist is informational; it does not by itself decide PRD finalization.

## Cite-only attribution

* **Publisher** — National Institute of Standards and Technology (NIST), U.S. Department of Commerce.
* **Edition / year** — NIST SP 800-160 Volume 1, Revision 1, 2022 ("Engineering Trustworthy Secure Systems").
* **URL** — [https://csrc.nist.gov/pubs/sp/800/160/v1/r1/final](https://csrc.nist.gov/pubs/sp/800/160/v1/r1/final)
* **Why the PRD Builder cites it** — Source publication whose design-principle and quality framing anchors the PRD NFR category buckets. NIST SP 800-160 Vol. 1 is a U.S. Government work in the public domain; the buckets and presence indicators above are repository-original groupings and reproduce no upstream tables verbatim.

## License

This reference file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). NIST SP 800-160 Vol. 1 is a U.S. Government publication in the public domain; it is cited by designator, and the category buckets are HVE-Core original groupings.


