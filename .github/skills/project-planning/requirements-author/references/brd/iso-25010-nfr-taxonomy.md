---
description: 'Cite-only reference naming the eight ISO/IEC 25010:2023 product-quality category names the BRD Builder uses as a Define-exit category-presence checklist per DD-012, with original Microsoft presence indicators'
---

# ISO/IEC 25010 - NFR Category-Presence Checklist (Cite-Only)

This document is a cite-only reference. It names the eight ISO/IEC 25010:2023 product-quality category names the BRD Builder uses as non-functional-requirement (NFR) categories and supplies the original Microsoft presence indicators the `BRD Quality Reviewer` subagent applies at Define exit per DD-012. It does not reproduce, paraphrase, or otherwise redistribute ISO/IEC 25010 definitions, sub-characteristic taxonomy, or other text. Consult the standard at the upstream source for the authoritative definitions.

## What This Document Is

ISO/IEC 25010:2023 is part of the SQuaRE (Systems and software Quality Requirements and Evaluation) series and defines a product-quality model organized under eight top-level quality characteristics. The BRD Builder references only the eight top-level category names and applies its own original presence indicators to each. The standard's definitions and sub-characteristic taxonomy are not included here; the full standard remains paywalled and cite-only. See [https://www.iso.org/standard/78176.html](https://www.iso.org/standard/78176.html) for the authoritative text.

## DD-012 Posture

Per DD-012, the BRD Builder treats ISO/IEC 25010 as a *category-presence checklist*, not a per-attribute enumeration. The Define-exit question for each category is binary: *is at least one NFR in the BRD that targets this category?*

* No N/A justification is required for categories with zero NFRs. The assessor flags missing categories qualitatively in its narrative.
* Missing categories do not by themselves block the Define → Govern gate. The gate blockers are scored at the requirement level under [iso-29148-quality-gate.md](iso-29148-quality-gate.md) and at the business-goal level under [../_shared/smart-rubric.md](../_shared/smart-rubric.md).
* This reference uses only the eight top-level category names. It does not enumerate or map NFRs to the standard's sub-characteristic taxonomy.

## The Eight Categories

Each heading below is an ISO/IEC 25010 top-level category name, used here as a factual label. The presence indicator under each is original Microsoft content describing when the BRD Builder considers that category addressed. None of these indicators reproduces an ISO definition.

### 1. Functional Suitability

Presence indicator: at least one NFR sets a threshold for functional coverage, correctness rate, or appropriateness of the solution relative to a named need.

### 2. Performance Efficiency

Presence indicator: at least one NFR sets a quantitative threshold for response time, throughput, capacity, or resource utilization.

### 3. Compatibility

Presence indicator: at least one NFR names an external system, protocol, schema, or runtime environment the solution must coexist with or interoperate with.

### 4. Usability

Presence indicator: at least one NFR sets a target for task completion rate, time to first success, accessibility conformance level (for example, WCAG), or user-error tolerance.

### 5. Reliability

Presence indicator: at least one NFR sets a target for availability (uptime), mean time between failures, recovery time, or fault tolerance.

### 6. Security

Presence indicator: at least one NFR sets an authentication, authorization, encryption, audit, or data-protection requirement with a stated mechanism or standard.

### 7. Maintainability

Presence indicator: at least one NFR sets a target for modularity, change effort, observability, test coverage, or deployment automation.

### 8. Portability

Presence indicator: at least one NFR names a target environment, install constraint, or replaceability requirement (for example, the solution must run on Linux and Windows; or, it must be deployable to Azure and AWS).

## Define-Exit Checklist

The `BRD Quality Reviewer` subagent emits this checklist as part of `BRD_STANDARD_FINDINGS_V1`:

| Category               | Present (true / false) | Notes |
|------------------------|------------------------|-------|
| Functional suitability |                        |       |
| Performance efficiency |                        |       |
| Compatibility          |                        |       |
| Usability              |                        |       |
| Reliability            |                        |       |
| Security               |                        |       |
| Maintainability        |                        |       |
| Portability            |                        |       |

Per DD-012, this checklist is informational; it does not by itself decide the Define → Govern gate.

## Why Cite-Only

ISO/IEC 25010 is a paywalled international standard. Its definitions, sub-characteristic taxonomy, and other prose are not reproduced or paraphrased in this repository. This reference uses the eight top-level category names as factual labels and cites the standard by name and designator only; the presence indicators are original Microsoft content.

## Upstream Source

[https://www.iso.org/standard/78176.html](https://www.iso.org/standard/78176.html) - ISO catalog entry for ISO/IEC 25010:2023 where the current revision, scope, and purchase terms are obtained.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). ISO/IEC 25010 is the property of ISO and IEC and is subject to the publisher's terms at the upstream source.


