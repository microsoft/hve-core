---
name: brd-author
description: 'BRD authoring guide for Discover, Define, and Govern with canonical templates and handoff contracts - Brought to you by microsoft/hve-core'
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-06-08"
---

# BRD Author Skill

## Overview

This skill defines how to produce and evolve a Business Requirements Document (BRD) across the project lifecycle. The canonical BRD template is [brd-full.md](templates/brd-full.md), and the canonical frontmatter overlay is [brd-frontmatter-overlay.md](templates/brd-frontmatter-overlay.md).

Use this skill with:

* [Requirements Definition](references/requirements-definition.md)
* [Traceability Naming](references/traceability-naming.md)
* [Traceability Matrix](references/traceability-matrix.md)
* [BRD-to-PRD Handoff](references/brd-to-prd-handoff-v1.md)
* [BRD Quality Formats](references/brd-quality-formats.md)

## Lifecycle

| Phase    | Primary objective                                                    | Entry condition                                  | Exit condition                                                 |
|----------|----------------------------------------------------------------------|--------------------------------------------------|----------------------------------------------------------------|
| Discover | Establish business context, stakeholder scope, and problem framing   | Request or initiative is in intake               | Discover hard gate passes and artifacts are complete           |
| Define   | Produce complete, testable, and traceable requirements content       | Discover artifacts are approved for elaboration  | Define hard gate passes with quality evidence                  |
| Govern   | Finalize, approve, and supersede BRD versions under lineage controls | Define package is approved for governance review | Govern hard gate passes and publication artifacts are recorded |

## Discover {#discover}

### Activities

* Capture business context, drivers, imposed constraints, and expected outcomes.
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

* Author full BRD content using [brd-full.md](templates/brd-full.md) and the canonical naming rules.
* Refine business goals and requirement sets with clear acceptance intent.
* Build and verify author-maintained traceability links across FR, AC, BG, and BR records.
* Perform quality assessment using the BRD quality reporting contract.

### Hard exit gate

Define exits only when:

* Requirement content is complete, unambiguous, and testable.
* Traceability links satisfy the active ID schema and naming policy.
* FR-to-AC coverage meets the active `fr_to_ac_coverage_threshold_pct` or has a recorded blocker.
* Quality findings are generated and reviewed against the defined rubric.

### Output artifacts

* Full BRD draft package with structured sections.
* Author-maintained traceability matrix aligned to naming and ID conventions.
* BRD quality findings and consolidated quality report payloads.
* Define gate decision record with reviewer notes.

## Govern {#govern}

### Activities

* Prepare final BRD for approval with version metadata and lineage fields.
* Bump approved BRDs from draft `0.x.y` versions to `1.0.0` or higher.
* Resolve or disposition remaining quality findings.
* Publish approved BRD outputs and downstream handoff payloads.
* Maintain supersession chain when issuing replacement BRD versions.

### Govern handoff production

Before emitting `BRD_TO_PRD_HANDOFF_V1`, the BRD Builder applies the coverage and waiver validation rules in [BRD-to-PRD Handoff](references/brd-to-prd-handoff-v1.md), including zero-FR coverage handling. It records the following values from the signed-off BRD and final quality review:

* A lowercase SHA-256 hash of the exact BRD artifact bytes at signoff.
* Counts for FR, NFR, BR, CON, AC, and BG identifiers using [id-schema.md](references/id-schema.md).
* FR-to-AC and FR-to-BG coverage metrics from the author-maintained traceability matrix.
* The final `BRD_QUALITY_REPORT_V1` reference, overall status, and Govern decision.
* Signoff approvers, roles, decisions, approval timestamps, comments, and active waivers.
* Waiver records for any accepted FR-to-AC threshold gap or FR-to-BG target gap.

### Hard exit gate

Govern exits only when:

* Approval status and required reviewers are recorded.
* Version and lineage metadata are valid and complete.
* The final quality report authorizes Govern exit.
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

Apply the BRD quality rubric and payload contracts from [BRD Quality Formats](references/brd-quality-formats.md) together with guidance in [Requirements Definition](references/requirements-definition.md). Treat rubric results as gate evidence for Define and Govern decisions. The BRD Quality Reviewer emits both standard findings and the consolidated quality report.

## Supersession lineage rules

* A BRD can supersede one or more earlier BRDs when scope is merged.
* A BRD can be superseded by only one approved successor version.
* Every supersession event records `supersedes` and `superseded_by` links.
* Supersession preserves historical artifacts for auditability.

## References

The skill bundles the following reference documents under `references/`. Load a section body only when its phase activity requires it; each body links to its own sub-references (standards pointers, scoring sheets, and worked examples).

Domain section bodies:

* [requirements-definition.md](references/requirements-definition.md) - Requirement categories, canonical statement form, acceptance-criteria formats, BR/CON separation, and Define-phase quality dimensions.
* [stakeholder-analysis.md](references/stakeholder-analysis.md) - Mendelow Power/Interest grid and RACI accountability variants.
* [process-modeling.md](references/process-modeling.md) - Optional process, decision, and structural diagram guidance.
* [prioritization-schemes.md](references/prioritization-schemes.md) - Required MoSCoW prioritization scheme.
* [traceability-naming.md](references/traceability-naming.md) - Requirement, business-goal, and decision identifier routing plus traceability conventions.
* [id-schema.md](references/id-schema.md) - Canonical prefix, digit, and adjacent identifier rules.
* [traceability-matrix.md](references/traceability-matrix.md) - Author-maintained FR-to-AC, FR-to-BG, and BR-to-FR matrix views.
* [design-decisions.md](references/design-decisions.md) - Registry for `DD-###` design decision codes.
* [brd-quality-formats.md](references/brd-quality-formats.md) - Producer and consumer map for the three versioned data contracts.

Rubrics and standards:

* [quality-rubric.md](references/quality-rubric.md) - Operational status taxonomy (`RISK` / `CAUTION` / `COVERED` / `NOT_APPLICABLE`) and the Define → Govern gate decision rule.
* [requirements-quality-rubric.md](references/requirements-quality-rubric.md) - Combined per-requirement, per-NFR-category, and per-business-goal scoring sheets.
* [handoff-payload-schema.md](references/handoff-payload-schema.md) - BRD-author view of the BRD-to-PRD handoff payload.
* [standards-excerpts.md](references/standards-excerpts.md) - Cite-only registry of third-party standards (ISO, IIBA, PMI, ISTQB) referenced by name.

## Templates

Templates under `templates/` are selected by the BRD frontmatter overlay's `diagram_format` field and the canonical BRD shape.

* [brd-full.md](templates/brd-full.md) - Canonical BRD template covering every section from Executive Summary through Sign-Off.
* [brd-frontmatter-overlay.md](templates/brd-frontmatter-overlay.md) - Schema for BRD YAML frontmatter, including `diagram_format`, lineage, coverage thresholds, and requirement-prefix overrides.
* [diagram-mermaid.md](templates/diagram-mermaid.md) - Mermaid flowchart fragment; the default diagram format.
* [diagram-ascii.md](templates/diagram-ascii.md) - ASCII process-diagram fragment for low-fidelity Discover-phase sketches.

## Data Contracts

Three versioned payload contracts govern BRD quality assessment and downstream handoff. Each `schema_version` is a fixed identifier; consumers fail fast on any other value, so the constants MUST NOT change.

| Contract           | `schema_version`           | Reference                                                             |
|--------------------|----------------------------|-----------------------------------------------------------------------|
| Standard findings  | `BRD_STANDARD_FINDINGS_V1` | [brd-standard-findings-v1.md](references/brd-standard-findings-v1.md) |
| Quality report     | `BRD_QUALITY_REPORT_V1`    | [brd-quality-report-v1.md](references/brd-quality-report-v1.md)       |
| BRD-to-PRD handoff | `BRD_TO_PRD_HANDOFF_V1`    | [brd-to-prd-handoff-v1.md](references/brd-to-prd-handoff-v1.md)       |

## Mandatory Load Directives

The BRD Builder agent enforces a phase → section load contract. Each phase MUST load its section of this skill before executing phase work, and MUST append the section anchor to `state.phaseSkillsLoaded`:

| Phase    | Section anchor | Required `phaseSkillsLoaded` entry |
|----------|----------------|------------------------------------|
| Discover | `#discover`    | `brd-author#discover`              |
| Define   | `#define`      | `brd-author#define`                |
| Govern   | `#govern`      | `brd-author#govern`                |

The agent loads sections via `read_file` against this skill file and records the entry in `state.phaseSkillsLoaded` before any phase work executes. Re-entering a previously loaded phase does not require reloading; the agent checks `phaseSkillsLoaded` first.

## Source Attribution

The bundled reference bodies cite third-party standards and frameworks by name and clause only; no upstream prose is redistributed, and paraphrased summaries are original Microsoft content under CC BY 4.0. The cite-only registry in [standards-excerpts.md](references/standards-excerpts.md) is the single place new standards citations are added. Standards referenced by name include ISO/IEC/IEEE 29148:2018, ISO/IEC 25010, IIBA BABOK v3, PMI Business Analysis for Practitioners, the ISTQB Glossary, OMG BPMN / DMN / UML, the Cucumber Gherkin pattern, and MoSCoW prioritization, each the property of its respective rights holder.

## License

This skill is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
