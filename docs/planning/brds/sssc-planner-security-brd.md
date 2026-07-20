---
title: SSSC Planner Security Governance BRD
description: Business requirements for an SSSC Planner that helps HVE-Core and downstream projects keep supply chain security planning consistent, auditable, and actionable.
author: GitHub Copilot
ms.date: 2026-06-13
ms.topic: concept
sidebar_position: 1
keywords: [brd, sssc, supply chain security, planner, governance]
tags: [security, supply-chain, planning]
---

## Document Control

| Field            | Value                                                                                                         |
|------------------|---------------------------------------------------------------------------------------------------------------|
| Document title   | SSSC Planner Security Governance BRD                                                                          |
| Initiative       | Secure Software Supply Chain Planner for HVE-Core and downstream adopters                                     |
| Version          | 0.1 draft                                                                                                     |
| Status           | Draft for stakeholder review                                                                                  |
| Last updated     | 2026-06-13                                                                                                    |
| Primary audience | HVE-Core maintainers, security reviewers, agent authors, release managers, downstream project security owners |
| Source context   | Current changeset introducing a generalized SSSC Planner and supporting validation updates                    |

## Progress Tracker

| BRD area                       | Status         | Notes                                                                   |
|--------------------------------|----------------|-------------------------------------------------------------------------|
| Business context               | Complete draft | Updated to reflect downstream project reuse and cascading security risk |
| Objectives and success metrics | Complete draft | Metrics require maintainer confirmation                                 |
| Stakeholders and roles         | Complete draft | Roles inferred from repository ownership and release workflow           |
| Scope                          | Complete draft | Focused on planner capability, state, validation, and handoff           |
| Business requirements          | Complete draft | Requirements trace to objectives and changeset evidence                 |
| Risks and dependencies         | Complete draft | Open for reviewer additions                                             |
| Final approval                 | Pending        | Requires maintainer and supply chain security review                    |

## Business Context and Background

HVE-Core distributes reusable AI-assisted engineering assets, including agents,
prompts, instructions, skills, validation scripts, and generated extension or
plugin packaging. Other projects use these assets to assess and improve their
own supply chain security posture. As a result, HVE-Core is not only securing
itself. It is also publishing repeatable security planning behavior that can
shape how downstream teams identify risks, create backlog items, choose
controls, and automate engineering workflows.

That reuse changes the risk profile. A weak or inconsistent SSSC planning
process can create cascading risk beyond this repository because insecure
guidance, incomplete validation, missing handoff controls, or unclear human
review boundaries can be copied into many projects. The planner must therefore
be designed as a reusable security governance capability, not only as an
internal HVE-Core planning aid.

The current changeset expands the Secure Software Supply Chain (SSSC) Planner
from a narrower telemetry-oriented planning surface into a generalized
phase-based planner. The changed artifacts include the SSSC planner agent,
consolidated SSSC planner instructions, collection updates, state schema tests,
context preservation tests, and state fixtures. Together, these changes move the
project toward a repeatable security planning capability that can assess supply
chain posture, map gaps to recognized standards, preserve state across sessions,
and generate actionable work items.

The business need is to make supply chain security planning durable rather than
dependent on individual memory, ad hoc prompts, or fragmented instruction files.
The SSSC Planner gives HVE-Core and downstream projects a consistent way to
identify supply chain risks, document evidence, validate state transitions, and
hand off prioritized remediation work while preserving clear expectations for
local security review.

## Problem Statement and Business Drivers

HVE-Core needs a reliable way to keep supply chain security practices visible,
reviewable, and actionable across both this repository and projects that adopt
its reusable AI-assisted workflows. Without a generalized SSSC Planner, supply
chain concerns can remain split across telemetry guidance, security instructions,
test fixtures, and collection metadata. That fragmentation increases the chance
that agents miss required review disclaimers, skip phase gates, lose context
between sessions, or produce backlog items that are not traceable to recognized
supply chain standards.

For downstream projects, those failures can be more severe than a local planning
defect. A copied planner pattern may be applied to different languages, package
managers, CI/CD systems, release channels, compliance expectations, and threat
models. If HVE-Core does not make contextual review and evidence requirements
explicit, adopters may apply recommendations that do not fit their environment
or may mistake planning output for approval to change security controls.

The primary business drivers are:

* Protect users of HVE-Core assets from insecure or incomplete supply chain guidance.
* Reduce cascading risk when downstream projects reuse HVE-Core security planners, prompts, skills, or generated backlog patterns.
* Reduce operational ambiguity by consolidating planner identity, phase behavior, and state management in one SSSC planning model.
* Improve auditability through persistent state, notice logging, schema validation, and test-backed context preservation.
* Convert security findings into backlog-ready work items that maintainers can prioritize and execute.
* Make local-context review explicit so adopters adapt recommendations to their own stack, release process, and risk tolerance.
* Align supply chain planning with recognized practices including OpenSSF Scorecard, SLSA, Sigstore, SBOM expectations, and OpenSSF Best Practices Badge criteria.

## Business Objectives and Success Metrics

| Objective ID | Objective                                                                                 | Success metric                                                                                                          | Target                                                                        |
|--------------|-------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| OBJ-001      | Establish a single generalized SSSC planning workflow for HVE-Core supply chain security. | SSSC planner identity and instructions are discoverable through the relevant security and project-planning collections. | 100% of targeted collections reference the generalized planner artifacts.     |
| OBJ-002      | Preserve planning continuity across sessions and handoffs.                                | SSSC state files validate against the canonical schema and include required notice, gate, and reference fields.         | 100% schema validation pass rate in planner state tests.                      |
| OBJ-003      | Make supply chain gaps actionable for maintainers.                                        | Generated backlog items include priority, acceptance criteria, adoption steps, and target backlog system format.        | All planner-generated work items meet story quality and handoff requirements. |
| OBJ-004      | Reduce risk of unsupported AI-assisted security decisions.                                | Planner displays required disclaimer and professional-review reminders and records them in state.                       | Required notice fields present in all complete phase fixtures.                |
| OBJ-005      | Improve evidence quality for supply chain reviews.                                        | Assessments record file paths, standards mappings, gap rationale, and artifact integrity choices.                       | Every completed assessment includes evidence for each applicable capability.  |
| OBJ-006      | Reduce downstream misuse risk for projects adopting HVE-Core security workflows.          | Planner records downstream context assumptions, local review expectations, and applicability notes before handoff.      | All handoffs include applicability notes and human-review boundaries.         |

## Stakeholders and Roles

| Stakeholder                           | Role in initiative                                                  | Primary interest                                                                         |
|---------------------------------------|---------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| HVE-Core maintainers                  | Own planner artifacts, collections, and release readiness           | Consistent, validated supply chain security planning                                     |
| Security reviewers                    | Review SSSC outputs before execution                                | Accurate assessment, defensible standards mapping, and human sign-off                    |
| Agent and instruction authors         | Maintain planner behavior and prompts                               | Clear source of truth for SSSC orchestration                                             |
| Release managers                      | Package and publish updated collections and extensions              | Confidence that distributed assets include the right planner guidance                    |
| Downstream project owners             | Use HVE-Core workflows to secure their own repositories             | Practical remediation guidance, local applicability checks, and backlog-ready work items |
| Downstream security reviewers         | Validate HVE-Core-generated planning outputs before local execution | Clear evidence, assumptions, review gates, and non-approval disclaimers                  |
| Compliance or governance stakeholders | Review evidence of supply chain controls                            | Traceable planning artifacts and standards alignment                                     |

## Scope

### In Scope

* A generalized SSSC Planner identity and instruction model for phase-based supply chain security planning.
* Six-phase planning flow covering scoping, supply chain assessment, standards mapping, gap analysis, backlog generation, and review or handoff.
* Persistent state management, including phase gates, references processed, disclaimer timestamps, notice logs, and planner preferences.
* Support for BRD, PRD, and security-plan seeded entry modes.
* Downstream adoption context capture, including repository type, release model, package ecosystem, governance expectations, and local review owner.
* Standards-aware assessment against OpenSSF Scorecard, SLSA, Sigstore, SBOM, and OpenSSF Best Practices Badge references.
* Backlog handoff outputs for Azure DevOps and GitHub issue workflows.
* Applicability notes that distinguish reusable guidance from project-specific approval.
* Automated validation through schema tests, state fixtures, and context preservation tests.

### Out of Scope

* Automatic remediation of supply chain gaps without human review.
* Replacement of qualified supply chain security review, compliance review, or release approval.
* Full implementation of every downstream reusable workflow referenced by planner outputs.
* Certification that a downstream project is secure because it used HVE-Core planning assets.
* Runtime monitoring or production telemetry instrumentation outside planner-generated supply chain evidence and audit trails.

## Current and Future Business Processes

### Current Process

Supply chain security planning guidance can be distributed across agent descriptions, telemetry-specific instructions, collection metadata, tests, and fixtures. Contributors must infer the intended workflow by reading multiple files and understanding which pieces are still current.

This creates inconsistent execution risk when planner state, disclaimers, artifact integrity, or backlog handoff expectations are not enforced from a single business process.

### Future Process

The SSSC Planner provides a structured workflow:

1. A user starts an SSSC planning session from capture mode or from an existing BRD, PRD, or security plan.
2. The planner displays the required disclaimer, standards attribution, and local-review expectations before analysis.
3. The planner scopes the repository, confirms technology and release surfaces, records downstream adoption context when applicable, and records state.
4. The planner assesses supply chain capabilities and maps evidence to recognized standards.
5. The planner identifies gaps, prioritizes remediation, and generates backlog-ready work items.
6. The planner produces handoff artifacts, records review reminders, captures applicability notes, and optionally supports artifact signing.
7. Tests and schema validation verify that the planner state model remains consistent as the repository evolves.

## Business Requirements

| ID     | Requirement                                                                                                                               | Linked objective | Impacted stakeholders                                    | Acceptance criteria                                                                                                                                                                           | Priority    |
|--------|-------------------------------------------------------------------------------------------------------------------------------------------|------------------|----------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| BR-001 | The project shall provide a generalized SSSC Planner for end-to-end supply chain security planning, not only telemetry-specific guidance. | OBJ-001          | Maintainers, agent authors, security reviewers           | Planner description and instructions define a six-phase SSSC workflow covering scoping through handoff.                                                                                       | Must have   |
| BR-002 | The planner shall maintain persistent state for phase, gates, references, notices, preferences, and completion flags.                     | OBJ-002          | Maintainers, security reviewers                          | State examples and schema validation include phase gates, `referencesProcessed`, `disclaimerShownAt`, `noticeLog`, and handoff fields.                                                        | Must have   |
| BR-003 | The planner shall require explicit user confirmation at high-risk transition points.                                                      | OBJ-002, OBJ-004 | Security reviewers, maintainers                          | Phases 1, 4, and 6 use hard gates with nullable `confirmedAt` fields until confirmed.                                                                                                         | Must have   |
| BR-004 | The planner shall display and record required AI-assisted security planning notices.                                                      | OBJ-004          | Security reviewers, compliance stakeholders              | Disclaimer and professional-review reminders are required by planner instructions and represented in state fixtures.                                                                          | Must have   |
| BR-005 | The planner shall assess supply chain posture against recognized external standards and project capability references.                    | OBJ-003, OBJ-005 | Security reviewers, downstream adopters                  | Assessment flow references OpenSSF Scorecard, SLSA, Sigstore, SBOM, and OpenSSF Best Practices Badge guidance through durable skill references.                                               | Must have   |
| BR-006 | The planner shall convert assessed gaps into actionable backlog items.                                                                    | OBJ-003          | Maintainers, release managers, downstream adopters       | Generated work items include priority, acceptance criteria, adoption steps, and target system support for ADO, GitHub, or both.                                                               | Must have   |
| BR-007 | The planner shall preserve context across resumptions and seeded entry modes.                                                             | OBJ-002, OBJ-005 | Agent authors, maintainers                               | BRD, PRD, and security-plan entry modes populate state from existing artifacts and record processed references.                                                                               | Should have |
| BR-008 | The planner shall support artifact integrity expectations for final handoff materials.                                                    | OBJ-004, OBJ-005 | Release managers, compliance stakeholders                | Phase 6 offers artifact signing or manifest generation and records signing preference and manifest path in state.                                                                             | Should have |
| BR-009 | The repository shall include automated tests and fixtures that detect regressions in SSSC state defaults and context preservation.        | OBJ-002, OBJ-004 | Maintainers, release managers                            | Planner state tests validate required default fields and SSSC fixtures model complete phase behavior.                                                                                         | Must have   |
| BR-010 | Collections shall expose the generalized SSSC Planner in the appropriate HVE-Core distribution bundles.                                   | OBJ-001          | Maintainers, downstream adopters                         | Security, project-planning, and HVE-Core collection metadata reflect the generalized planner capability.                                                                                      | Should have |
| BR-011 | The planner shall capture downstream adoption context before applying reusable guidance to another project.                               | OBJ-005, OBJ-006 | Downstream project owners, downstream security reviewers | Planning state or handoff artifacts record repository type, package ecosystem, CI/CD surface, release model, governance needs, and local review owner when the target is not HVE-Core itself. | Must have   |
| BR-012 | The planner shall distinguish reusable recommendations from project-specific security approval.                                           | OBJ-004, OBJ-006 | Security reviewers, downstream project owners            | Handoffs include applicability notes, assumptions, and explicit reminders that local security owners must validate recommendations before execution.                                          | Must have   |

## Data and Reporting Requirements

The planner and supporting validation should produce or preserve the following information:

| Data element                                                             | Business purpose                                                                         | Expected location or artifact              |
|--------------------------------------------------------------------------|------------------------------------------------------------------------------------------|--------------------------------------------|
| Project slug and plan file path                                          | Identify the planning session and its primary artifact                                   | SSSC `state.json`                          |
| Technology stack, package managers, CI/CD platform, and release strategy | Scope supply chain risk surfaces                                                         | SSSC `state.json` and assessment artifact  |
| References processed                                                     | Trace BRD, PRD, security plan, standard, SBOM, or scorecard inputs                       | SSSC `state.json`                          |
| Downstream adoption context                                              | Show where reusable HVE-Core guidance is being applied outside this repository           | SSSC `state.json` and handoff artifact     |
| Local applicability assumptions                                          | Identify stack, release, governance, and threat-model assumptions behind recommendations | Assessment and handoff artifacts           |
| Phase gates and confirmation timestamps                                  | Show review points and user approval for high-risk transitions                           | SSSC `state.json`                          |
| Disclaimer and notice log                                                | Demonstrate that AI-assisted security planning warnings were shown                       | SSSC `state.json`                          |
| Capability assessment evidence                                           | Support reviewer validation of current-state posture                                     | Supply chain assessment artifact           |
| Standards mappings                                                       | Connect findings to recognized supply chain frameworks                                   | Standards mapping artifact                 |
| Gap priorities and backlog items                                         | Enable remediation planning and execution                                                | Gap analysis and backlog handoff artifacts |
| Signing manifest path                                                    | Support artifact integrity for final handoff materials                                   | SSSC `state.json` and manifest artifact    |

## Assumptions, Dependencies, and Constraints

### Assumptions

* HVE-Core maintainers want a reusable planner that can be distributed through security and project-planning collections.
* SSSC assessments are planning aids and require qualified human security review before execution.
* Downstream teams may use different technology stacks, governance requirements, and backlog systems, so context capture and dual-format handoff support remain valuable.
* Downstream adopters are responsible for validating local applicability before using planner-generated backlog items to change security controls.
* The supply chain security skill remains the durable source for standards and capability reference material.

### Dependencies

* The canonical SSSC state schema remains available under repository linting schemas.
* Planner tests continue to run through the repository validation pipeline.
* Collection generation and extension preparation include the updated planner artifacts.
* The supply-chain-security skill maintains current references for standards, maturity models, and capability mappings.

### Constraints

* The planner must not invent standards mappings or telemetry vocabulary when durable references exist.
* The planner must keep AI-assisted security planning disclaimers visible and auditable.
* The planner must make local-context assumptions visible when HVE-Core guidance is reused by another project.
* The planner must preserve human approval gates for high-risk transitions.
* The planner must avoid direct automatic remediation unless separately authorized by maintainers.

## Risks and Issues

| Risk ID | Risk                                                                             | Impact                                                                                          | Mitigation                                                                                                                   | Owner                         |
|---------|----------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|-------------------------------|
| R-001   | Planner guidance becomes fragmented again across multiple instruction files.     | Users receive inconsistent supply chain planning behavior.                                      | Treat the generalized SSSC planner instruction file as the source of truth and keep collections aligned.                     | Maintainers                   |
| R-002   | State schema changes are not reflected in fixtures or tests.                     | Planner sessions fail to resume or omit required review fields.                                 | Keep schema tests and complete phase fixtures updated with every planner state change.                                       | Maintainers                   |
| R-003   | Users treat planner output as final security approval.                           | Supply chain gaps may be accepted without qualified review.                                     | Require disclaimer display, notice logging, and professional-review reminders.                                               | Security reviewers            |
| R-004   | Backlog items are too generic for execution.                                     | Remediation work stalls or is deprioritized.                                                    | Require acceptance criteria, standards traceability, and adoption steps for every work item.                                 | Agent authors                 |
| R-005   | Artifact integrity is optional and therefore skipped for important handoffs.     | Final planning artifacts may be harder to trust or audit.                                       | Offer signing during Phase 6 and record the user's signing decision in state.                                                | Release managers              |
| R-006   | Downstream projects copy HVE-Core guidance without adapting it to local context. | Controls may be misapplied across different stacks, release models, or compliance environments. | Require downstream context capture, applicability notes, and local security owner review before handoff execution.           | Downstream security reviewers |
| R-007   | A defect in reusable planner guidance propagates to many projects.               | One weak pattern can create repeated supply chain planning gaps across adopters.                | Treat distributed planner artifacts as high-impact guidance, validate them through tests, and review changes before release. | Maintainers                   |

## Implementation and Change Considerations

The current changeset already establishes the foundation for this BRD by consolidating planner behavior and expanding validation. Implementation should continue to emphasize small, reviewable changes that preserve the planner's business controls:

* Keep SSSC planner identity, state expectations, and phase protocols aligned between agent and instruction artifacts.
* Keep generated collection metadata synchronized so users can discover the planner in expected bundles.
* Keep state fixtures representative of complete and resumed sessions.
* Keep tests focused on business-critical invariants such as notices, phase gates, references, and context preservation.
* Keep downstream adoption assumptions visible so generalized guidance does not obscure project-specific risk decisions.
* Keep final handoff artifacts tied to human review and, when requested, artifact integrity checks.

## Benefits and High-Level Economics

| Benefit                               | Business value                                                                                                         | Measurement approach                                                                                          |
|---------------------------------------|------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| Reduced planning inconsistency        | Maintainers and users follow one documented SSSC workflow.                                                             | Fewer conflicting planner instructions and fewer reviewer corrections.                                        |
| Better supply chain visibility        | Security gaps are assessed against recognized standards with evidence.                                                 | Completed assessments include standards mapping and file-path evidence.                                       |
| Faster remediation planning           | Gaps become backlog-ready work items.                                                                                  | Time from assessment completion to backlog handoff decreases.                                                 |
| Stronger audit posture                | Notices, gates, references, and artifact integrity choices are recorded.                                               | State validation and fixture coverage demonstrate required records.                                           |
| Safer distribution of HVE-Core assets | Downstream adopters receive consistent guidance for supply chain controls and know where local validation is required. | Collection releases include the generalized SSSC planner, current references, and applicability expectations. |
| Reduced cascading security risk       | Reusable planner guidance is less likely to propagate weak assumptions across projects.                                | Handoffs include downstream context, assumptions, and reviewer ownership.                                     |

## Open Questions

* Who is the named business owner for approving the SSSC Planner BRD?
* Should the target backlog system default remain both ADO and GitHub for HVE-Core, or should one be primary?
* What minimum OpenSSF Scorecard score or SLSA target should HVE-Core use as the initial success threshold?
* Should artifact signing be required for all Phase 6 handoffs or remain an opt-in planner option?
* Which release milestone should include this generalized SSSC Planner capability?
* What minimum downstream context fields are required before the planner can generate project-specific backlog items?
* Should downstream adoption handoffs require a named local security owner before Phase 6 completion?

## Approval Criteria

The BRD is ready for approval when:

* Business objectives and success metrics are accepted by HVE-Core maintainers.
* Security reviewers confirm that the requirements reflect supply chain planning needs.
* Downstream reuse risks, applicability assumptions, and local-review expectations are represented in objectives, requirements, and risks.
* Required BRD sections are complete and traceable to objectives.
* All must-have business requirements have acceptance criteria.
* Open questions are resolved or assigned to named owners.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
