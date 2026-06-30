---
name: requirements-author
description: 'Requirements authoring guide for BRD and PRD across Discover, Define, and Govern with canonical templates and handoff contracts'
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.1"
  last_updated: "2026-06-14"
---

# Requirements Author Skill

## Overview

This skill defines how to produce and evolve requirements documents across the project lifecycle for two document types: the Business Requirements Document (BRD) and the Product Requirements Document (PRD). Shared requirements-engineering knowledge lives in `references/_shared/`, while BRD-specific and PRD-specific knowledge live in `references/brd/` and `references/prd/` so each consuming agent loads only what its document needs.

The canonical BRD template is [brd-full.md](templates/brd/brd-full.md) with its [brd-frontmatter-overlay.md](templates/brd/brd-frontmatter-overlay.md), and the canonical PRD template is [prd-full.md](templates/prd/prd-full.md). The BRD Builder dispatches into the BRD phase anchors (`#discover`, `#define`, `#govern`); the PRD Builder dispatches into the PRD phase anchors (`#prd-assess` through `#prd-finalize`).

Use this skill with the references for the active document scope:

Shared (`references/_shared/`):

* [Requirements Definition](references/_shared/requirements-definition.md)
* [Traceability Naming](references/_shared/traceability-naming.md)
* [Traceability Matrix](references/_shared/traceability-matrix.md)

BRD scope (`references/brd/`):

* [BRD-to-PRD Handoff](references/brd/brd-to-prd-handoff-v1.md)
* [BRD Quality Formats](references/brd/brd-quality-formats.md)

PRD scope (`references/prd/`):

* [Product Discovery](references/prd/product-discovery.md)
* [EARS Acceptance](references/prd/ears-acceptance.md)
* [PRD Quality Formats](references/prd/prd-quality-formats.md)

## BRD Lifecycle

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

* Author full BRD content using [brd-full.md](templates/brd/brd-full.md) and the canonical naming rules.
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

Before emitting `BRD_TO_PRD_HANDOFF_V1`, the BRD Builder applies the coverage and waiver validation rules in [BRD-to-PRD Handoff](references/brd/brd-to-prd-handoff-v1.md), including zero-FR coverage handling. It records the following values from the signed-off BRD and final quality review:

* A lowercase SHA-256 hash of the exact BRD artifact bytes at signoff.
* Counts for FR, NFR, BR, CON, AC, and BG identifiers using [id-schema.md](references/_shared/id-schema.md).
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

Apply the BRD quality rubric and payload contracts from [BRD Quality Formats](references/brd/brd-quality-formats.md) together with guidance in [Requirements Definition](references/_shared/requirements-definition.md). Treat rubric results as gate evidence for Define and Govern decisions. The BRD Quality Reviewer emits both standard findings and the consolidated quality report.

## Supersession lineage rules

* A BRD can supersede one or more earlier BRDs when scope is merged.
* A BRD can be superseded by only one approved successor version.
* Every supersession event records `supersedes` and `superseded_by` links.
* Supersession preserves historical artifacts for auditability.

## PRD Lifecycle

The PRD Builder agent runs a seven-phase lifecycle. Each phase has its own section anchor below so the agent loads only the guidance for the active phase.

| Phase     | Section anchor   | Primary objective                                            |
|-----------|------------------|--------------------------------------------------------------|
| Assess    | `#prd-assess`    | Determine whether enough context exists to create PRD files. |
| Discover  | `#prd-discover`  | Establish the PRD title, scope, and product goals.           |
| Create    | `#prd-create`    | Generate the PRD file and state file once context is clear.  |
| Build     | `#prd-build`     | Gather detailed requirements iteratively.                    |
| Integrate | `#prd-integrate` | Incorporate references, documents, and external materials.   |
| Validate  | `#prd-validate`  | Ensure completeness and quality before approval.             |
| Finalize  | `#prd-finalize`  | Deliver the complete, actionable PRD.                        |

## PRD Assess {#prd-assess}

### Activities

* Determine whether enough product context exists to create PRD artifacts.
* Identify the initiative, problem statement, and primary target users.
* Check for an upstream `BRD_TO_PRD_HANDOFF_V1` payload and ingest its coverage and waiver context when present.
* Decide whether to gather more context or proceed to file creation.

### Hard exit gate

Assess exits only when:

* A meaningful kebab-case PRD name can be derived.
* Problem framing and primary users are identified.
* Any available BRD handoff payload has been validated and its coverage metrics recorded.

### Output artifacts

* Assess summary noting context sufficiency.
* Derived working title for the PRD.
* Ingested handoff context when a BRD handoff payload exists.

## PRD Discover {#prd-discover}

### Activities

* Ask focused questions to establish the PRD title, scope, and product goals.
* Explore the problem space using [Product Discovery](references/prd/product-discovery.md) and [MVP Framing](references/prd/mvp-framing.md).
* Capture target users, candidate success metrics, and explicit non-goals using [Metrics Frameworks](references/prd/metrics-frameworks.md).

### Hard exit gate

Discover exits only when:

* Title and scope are explicit.
* Primary users and candidate success metrics are named.
* In-scope and out-of-scope boundaries are recorded.

### Output artifacts

* Discovery summary.
* Scope and non-goals statement.
* Candidate success metrics.

## PRD Create {#prd-create}

### Activities

* Generate the PRD file from [prd-full.md](templates/prd/prd-full.md) and create the session state file once title and context are clear.
* Populate the skeleton with the established scope, users, and goals.
* Seed the iterative requirement and metric structure for Build.

### Hard exit gate

Create exits only when:

* The PRD file and state file exist.
* The skeleton matches the canonical PRD structure.
* Initial scope and goals are seeded.

### Output artifacts

* PRD draft skeleton.
* PRD session state file.
* Seeded scope and goals sections.

## PRD Build {#prd-build}

### Activities

* Gather detailed functional and non-functional requirements iteratively.
* Author acceptance criteria using [EARS Acceptance](references/prd/ears-acceptance.md) and the [Connextra Template](references/prd/connextra-template.md).
* Classify non-functional requirements with the [NIST 800-160 NFR taxonomy](references/prd/nist-800-160-nfr.md) and check stories against [INVEST](references/prd/invest.md).
* Maintain author traceability across requirements, goals, and metrics using [Traceability Naming](references/_shared/traceability-naming.md), [Traceability Matrix](references/_shared/traceability-matrix.md), and [id-schema.md](references/_shared/id-schema.md).

### Hard exit gate

Build exits only when:

* Requirements are complete, testable, and traceable.
* Acceptance criteria follow EARS or Given-When-Then form.
* Non-functional requirements are categorized.
* Coverage meets the active thresholds or records a blocker.

### Output artifacts

* Full PRD requirement set.
* Author-maintained traceability matrix.
* Acceptance criteria and NFR classifications.

## PRD Integrate {#prd-integrate}

### Activities

* Incorporate user-provided references, documents, and external materials.
* Reconcile incoming content with existing requirements and resolve conflicts.
* Link supporting evidence to requirements and metrics.

### Hard exit gate

Integrate exits only when:

* Provided references are incorporated or explicitly deferred.
* Conflicts between sources are resolved.
* Supporting evidence is linked.

### Output artifacts

* Updated PRD sections with integrated references.
* Reference and evidence linkage record.

## PRD Validate {#prd-validate}

### Activities

* Assess completeness and quality before approval.
* Run the PRD Quality Reviewer to emit `PRD_STANDARD_FINDINGS_V1` and `PRD_QUALITY_REPORT_V1` per [PRD Quality Formats](references/prd/prd-quality-formats.md).
* Review findings against the rubric and resolve or disposition gaps.

### Hard exit gate

Validate exits only when:

* Quality findings and the consolidated report are generated.
* The report authorizes Validate exit via `gate_decisions.validate_exit`.
* Coverage and quality thresholds are met or waived.

### Output artifacts

* PRD quality findings and report payloads.
* Validate gate decision record.

## PRD Finalize {#prd-finalize}

### Activities

* Deliver the complete, actionable PRD.
* Resolve remaining findings and record version and approval metadata.
* Run a Finalize drift check and publish downstream artifacts.

### Hard exit gate

Finalize exits only when:

* Approval status and required reviewers are recorded.
* The final quality report authorizes Finalize exit via `gate_decisions.finalize_exit`.
* No unresolved blocking findings remain.

### Output artifacts

* Approved PRD release artifact.
* Finalize decision log with approval evidence.

## References

The skill bundles reference documents under `references/`, organized into three scopes: shared requirements-engineering knowledge in `references/_shared/`, BRD-specific knowledge in `references/brd/`, and PRD-specific knowledge in `references/prd/`. Load a reference body only when its phase activity requires it; each body links to its own sub-references (standards pointers, scoring sheets, and worked examples).

### Shared references (`references/_shared/`)

* [requirements-definition.md](references/_shared/requirements-definition.md) - Requirement categories, canonical statement form, acceptance-criteria formats, and quality dimensions.
* [stakeholder-analysis.md](references/_shared/stakeholder-analysis.md) - Mendelow Power/Interest grid and RACI accountability variants.
* [process-modeling.md](references/_shared/process-modeling.md) - Optional process, decision, and structural diagram guidance.
* [prioritization-schemes.md](references/_shared/prioritization-schemes.md) - Required MoSCoW prioritization scheme.
* [traceability-naming.md](references/_shared/traceability-naming.md) - Requirement, goal, and decision identifier routing plus traceability conventions.
* [id-schema.md](references/_shared/id-schema.md) - Canonical prefix, digit, and adjacent identifier rules.
* [traceability-matrix.md](references/_shared/traceability-matrix.md) - Author-maintained FR-to-AC, FR-to-BG, and BR-to-FR matrix views.
* [design-decisions.md](references/_shared/design-decisions.md) - Registry for `DD-###` design decision codes.
* [quality-rubric.md](references/_shared/quality-rubric.md) - Operational status taxonomy (`RISK` / `CAUTION` / `COVERED` / `NOT_APPLICABLE`) and the gate decision rule.
* [standards-excerpts.md](references/_shared/standards-excerpts.md) - Cite-only registry of third-party standards (ISO, IIBA, PMI, ISTQB) referenced by name.

### BRD references (`references/brd/`)

* [brd-quality-formats.md](references/brd/brd-quality-formats.md) - Producer and consumer map for the BRD data contracts.
* [requirements-quality-rubric.md](references/brd/requirements-quality-rubric.md) - Combined per-requirement, per-NFR-category, and per-business-goal scoring sheets.
* [handoff-payload-schema.md](references/brd/handoff-payload-schema.md) - BRD-author view of the BRD-to-PRD handoff payload.

### PRD references (`references/prd/`)

* [product-discovery.md](references/prd/product-discovery.md) - Problem-space exploration and discovery questioning for PRD scope.
* [mvp-framing.md](references/prd/mvp-framing.md) - MVP framing and scope-boundary guidance.
* [metrics-frameworks.md](references/prd/metrics-frameworks.md) - JTBD, HEART, and AARRR success-metric frameworks.
* [ears-acceptance.md](references/prd/ears-acceptance.md) - EARS acceptance-criteria patterns for PRD requirements.
* [nist-800-160-nfr.md](references/prd/nist-800-160-nfr.md) - NIST 800-160 non-functional requirement taxonomy.
* [invest.md](references/prd/invest.md) - INVEST quality criteria for user stories.
* [connextra-template.md](references/prd/connextra-template.md) - Connextra user-story template.
* [prd-quality-formats.md](references/prd/prd-quality-formats.md) - Producer and consumer map for the PRD data contracts.

## Templates

Templates under `templates/` are selected by the document frontmatter and canonical document shape.

* [brd-full.md](templates/brd/brd-full.md) - Canonical BRD template covering every section from Executive Summary through Sign-Off.
* [brd-frontmatter-overlay.md](templates/brd/brd-frontmatter-overlay.md) - Schema for BRD YAML frontmatter, including `diagram_format`, lineage, coverage thresholds, and requirement-prefix overrides.
* [diagram-mermaid.md](templates/brd/diagram-mermaid.md) - Mermaid flowchart fragment; the default diagram format.
* [diagram-ascii.md](templates/brd/diagram-ascii.md) - ASCII process-diagram fragment for low-fidelity Discover-phase sketches.
* [prd-full.md](templates/prd/prd-full.md) - Canonical PRD template covering every section from product overview through acceptance and metrics.

## Data Contracts

Versioned payload contracts govern quality assessment and downstream handoff for each document type. Each `schema_version` is a fixed identifier; consumers fail fast on any other value, so the constants MUST NOT change.

BRD data contracts:

| Contract           | `schema_version`           | Reference                                                                 |
|--------------------|----------------------------|---------------------------------------------------------------------------|
| Standard findings  | `BRD_STANDARD_FINDINGS_V1` | [brd-standard-findings-v1.md](references/brd/brd-standard-findings-v1.md) |
| Quality report     | `BRD_QUALITY_REPORT_V1`    | [brd-quality-report-v1.md](references/brd/brd-quality-report-v1.md)       |
| BRD-to-PRD handoff | `BRD_TO_PRD_HANDOFF_V1`    | [brd-to-prd-handoff-v1.md](references/brd/brd-to-prd-handoff-v1.md)       |

PRD data contracts:

| Contract          | `schema_version`           | Reference                                                                 |
|-------------------|----------------------------|---------------------------------------------------------------------------|
| Standard findings | `PRD_STANDARD_FINDINGS_V1` | [prd-standard-findings-v1.md](references/prd/prd-standard-findings-v1.md) |
| Quality report    | `PRD_QUALITY_REPORT_V1`    | [prd-quality-report-v1.md](references/prd/prd-quality-report-v1.md)       |

The PRD lifecycle consumes `BRD_TO_PRD_HANDOFF_V1` as an upstream input during Assess.

## Mandatory Load Directives

The BRD Builder and PRD Builder agents each enforce a phase → section load contract. Each phase MUST load its section of this skill before executing phase work, and MUST append the section anchor to `state.phaseSkillsLoaded`.

BRD Builder directives:

| Phase    | Section anchor | Required `phaseSkillsLoaded` entry |
|----------|----------------|------------------------------------|
| Discover | `#discover`    | `brd-author#discover`              |
| Define   | `#define`      | `brd-author#define`                |
| Govern   | `#govern`      | `brd-author#govern`                |

PRD Builder directives:

| Phase     | Section anchor   | Required `phaseSkillsLoaded` entry |
|-----------|------------------|------------------------------------|
| Assess    | `#prd-assess`    | `prd-author#assess`                |
| Discover  | `#prd-discover`  | `prd-author#discover`              |
| Create    | `#prd-create`    | `prd-author#create`                |
| Build     | `#prd-build`     | `prd-author#build`                 |
| Integrate | `#prd-integrate` | `prd-author#integrate`             |
| Validate  | `#prd-validate`  | `prd-author#validate`              |
| Finalize  | `#prd-finalize`  | `prd-author#finalize`              |

The agent loads sections via `read_file` against this skill file and records the entry in `state.phaseSkillsLoaded` before any phase work executes. Re-entering a previously loaded phase does not require reloading; the agent checks `phaseSkillsLoaded` first.

## Source Attribution

The bundled reference bodies cite third-party standards and frameworks by name and clause only; no upstream prose is reproduced or paraphrased. Where a reference names a standard's characteristics or categories, the accompanying review criteria, anchors, and indicators are original Microsoft content under CC BY 4.0, not reproductions of the standard's definitions; the authoritative definitions live in the cited standards. The cite-only registry in [standards-excerpts.md](references/_shared/standards-excerpts.md) is the single place new standards citations are added. Standards referenced by name include ISO/IEC/IEEE 29148:2018, ISO/IEC 25010:2023, IIBA BABOK v3, PMI Business Analysis for Practitioners, the ISTQB Glossary, OMG BPMN / DMN / UML, the Cucumber Gherkin pattern, and MoSCoW prioritization, each the property of its respective rights holder.

## License

This skill is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).


