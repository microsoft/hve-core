---
name: brd-author
description: 'BRD authoring operating guide for Discover, Define, and Govern phases with hard exit gates and artifact contracts - Brought to you by microsoft/hve-core'
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-05-08"
---

# BRD Author Skill

## Overview

This skill defines how to produce and evolve a Business Requirements Document (BRD) across the project lifecycle. It provides a phase-based operating contract with explicit hard exit gates, artifact outputs, status semantics, and lineage rules.

Use this skill with:

* [Requirements Definition](../requirements-definition/SKILL.md)
* [Traceability Naming](../traceability-naming/SKILL.md)
* [BRD Quality Formats](../brd-quality-formats/SKILL.md)

## Lifecycle

| Phase | Primary objective | Entry condition | Exit condition |
|-------|-------------------|-----------------|----------------|
| Discover | Establish business context, stakeholder scope, and problem framing | Request or initiative is in intake | Discover hard gate passes and artifacts are complete |
| Define | Produce complete, testable, and traceable requirements content | Discover artifacts are approved for elaboration | Define hard gate passes with quality evidence |
| Govern | Finalize, approve, and supersede BRD versions under lineage controls | Define package is approved for governance review | Govern hard gate passes and publication artifacts are recorded |

## Discover {#discover}

### Activities

* Capture business context, drivers, constraints, and expected outcomes.
* Identify stakeholders, decision owners, and review participants.
* Define scope boundaries, assumptions, and dependency surfaces.
* Draft initial requirement candidates and map early traceability placeholders.

### Hard exit gate

Discover exits only when:

* Scope is bounded and stakeholder ownership is explicit.
* Core assumptions and constraints are documented and reviewable.
* Seed artifacts needed for Define are present and internally consistent.

### Output artifacts

* Discover summary and scope statement.
* Stakeholder inventory with role and ownership mapping.
* Initial assumption and constraint register.
* Seed requirement and traceability scaffold for Define.

## Define {#define}

### Activities

* Author full BRD content using canonical templates and naming rules.
* Refine business goals and requirement sets with clear acceptance intent.
* Build and verify traceability links across requirements and acceptance criteria.
* Perform quality assessment using the BRD quality reporting contract.

### Hard exit gate

Define exits only when:

* Requirement content is complete, unambiguous, and testable.
* Traceability links satisfy the active ID schema and naming policy.
* Quality findings are generated and reviewed against the defined rubric.

### Output artifacts

* Full BRD draft package with structured sections.
* Traceability matrix aligned to naming and ID conventions.
* BRD quality findings and consolidated quality report payloads.
* Define gate decision record with reviewer notes.

## Govern {#govern}

### Activities

* Prepare final BRD for approval with version metadata and lineage fields.
* Resolve or disposition remaining quality findings.
* Publish approved BRD outputs and downstream handoff payloads.
* Maintain supersession chain when issuing replacement BRD versions.

### Hard exit gate

Govern exits only when:

* Approval status and required reviewers are recorded.
* Version and lineage metadata are valid and complete.
* Handoff artifacts are published for downstream consumers.

### Output artifacts

* Approved BRD release artifact.
* BRD-to-PRD handoff payload.
* Governance decision log with approval evidence.
* Supersession linkage record for replaced BRD versions.

## Status taxonomy

Use the following status values for BRD lifecycle tracking:

* `draft`: Actively authored or revised.
* `in-review`: Under formal review and gate validation.
* `approved`: Accepted for governed use.
* `superseded`: Replaced by a newer approved BRD.

## Quality rubric pointer

Apply the BRD quality rubric and payload contracts from [BRD Quality Formats](../brd-quality-formats/SKILL.md) together with requirement-definition guidance in [Requirements Definition](../requirements-definition/SKILL.md#quality-dimensions-and-rubrics). Treat rubric results as gate evidence for Define and Govern decisions.

## Supersession lineage rules

* A BRD can supersede one or more earlier BRDs when scope is merged.
* A BRD can be superseded by only one approved successor version.
* Every supersession event records `supersedes` and `superseded_by` links.
* Supersession does not delete historical artifacts; it preserves auditability.

## License

This skill is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
