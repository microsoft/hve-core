---
description: 'Cite-only summary of ISO/IEC 25010 product-quality model - the eight quality characteristics presented as a Define-exit category-presence checklist per DD-012, with sub-characteristics listed for awareness only - Brought to you by microsoft/hve-core'
---

# ISO/IEC 25010 - NFR Category-Presence Checklist (Cite-Only)

This document is a cite-only summary. It names the eight ISO/IEC 25010 product-quality characteristics the BRD Builder treats as non-functional-requirement (NFR) categories, defines each category in original Microsoft prose, and supplies the binary presence checklist the `BRD Quality Reviewer` subagent uses at Define exit per DD-012. It does not redistribute ISO/IEC 25010 text.

## What This Document Is

ISO/IEC 25010 (initially published in 2011 and subsequently revised) is part of the SQuaRE (Systems and software Quality Requirements and Evaluation) series.
It defines a product-quality model with eight top-level quality characteristics and a number of sub-characteristics.
The BRD Builder adopts the eight top-level characteristics as a category-presence checklist.
It does not score sub-characteristics.
The full standard remains paywalled and cite-only; see [https://www.iso.org/standard/35733.html](https://www.iso.org/standard/35733.html) for the authoritative text.

## DD-012 Posture

Per DD-012, the BRD Builder treats ISO/IEC 25010 as a *category-presence checklist*, not a per-attribute enumeration. The Define-exit question for each category is binary: *is at least one NFR in the BRD that targets this category?*

* No N/A justification is required for categories with zero NFRs. The assessor flags missing categories qualitatively in its narrative.
* Missing categories do not by themselves block the Define → Govern gate. The gate blockers are scored at the requirement level under [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md) and at the business-goal level under [smart-rubric.md](smart-rubric.md).
* Sub-characteristics are listed below for awareness only; the BRD Builder does not require BRD authors to map NFRs to specific sub-characteristics.

## The Eight Categories

### 1. Functional Suitability

Coverage and correctness of the functions the solution provides relative to stated needs.

Sub-characteristics (for awareness only): functional completeness, functional correctness, functional appropriateness.

Presence indicator: at least one NFR sets a threshold for functional coverage, correctness rate, or appropriateness of the solution relative to a named need.

### 2. Performance Efficiency

Resource use and timing characteristics under stated conditions.

Sub-characteristics (for awareness only): time behaviour, resource utilization, capacity.

Presence indicator: at least one NFR sets a quantitative threshold for response time, throughput, capacity, or resource utilization.

### 3. Compatibility

Ability of the solution to coexist with and interoperate with other systems.

Sub-characteristics (for awareness only): co-existence, interoperability.

Presence indicator: at least one NFR names an external system, protocol, schema, or runtime environment the solution must coexist with or interoperate with.

### 4. Usability

Effectiveness, efficiency, and satisfaction with which specified users achieve specified goals.

Sub-characteristics (for awareness only): appropriateness recognizability, learnability, operability, user error protection, user interface aesthetics, accessibility.

Presence indicator: at least one NFR sets a target for task completion rate, time to first success, accessibility conformance level (for example, WCAG), or user-error tolerance.

### 5. Reliability

Ability of the solution to perform under stated conditions for a stated period or number of operations.

Sub-characteristics (for awareness only): maturity, availability, fault tolerance, recoverability.

Presence indicator: at least one NFR sets a target for availability (uptime), mean time between failures, recovery time, or fault tolerance.

### 6. Security

Protection of information and data such that unauthorized persons or systems cannot read or modify them, and authorized persons or systems are not denied access.

Sub-characteristics (for awareness only): confidentiality, integrity, non-repudiation, accountability, authenticity.

Presence indicator: at least one NFR sets an authentication, authorization, encryption, audit, or data-protection requirement with a stated mechanism or standard.

### 7. Maintainability

Effectiveness and efficiency with which the solution can be modified to correct, improve, or adapt it to changes.

Sub-characteristics (for awareness only): modularity, reusability, analysability, modifiability, testability.

Presence indicator: at least one NFR sets a target for modularity, change effort, observability, test coverage, or deployment automation.

### 8. Portability

Effectiveness and efficiency with which the solution can be transferred from one environment to another.

Sub-characteristics (for awareness only): adaptability, installability, replaceability.

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

ISO/IEC 25010 is a paywalled international standard. Its prose is not redistributed in this repository. The eight characteristics and their sub-characteristics above are Microsoft paraphrases informed by the standard's clauses; the standard is cited by name and designator only.

## Upstream Source

[https://www.iso.org/standard/35733.html](https://www.iso.org/standard/35733.html) - ISO catalog entry where the current revision, scope, and purchase terms are obtained.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). ISO/IEC 25010 is the property of ISO and IEC and is subject to the publisher's terms at the upstream source.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
