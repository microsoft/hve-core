---
title: SIG RAI
description: Charter for the Responsible AI Special Interest Group in microsoft/hve-core
ms.topic: reference
ms.date: 2026-04-25
author: HVE Core Maintainers
---

**Status:** Proposed
**Created:** 2026-04-25
**Last Reviewed:** 2026-04-25
**Next Review:** 2027-04-25

## Mission

SIG RAI owns Responsible AI planning, review rubrics, and authoring guidance for microsoft/hve-core. The SIG ensures every AI-assisted artifact shipped from this repository (agents, prompts, skills, instructions, planning workflows) is evaluated against the project's RAI planning rubric and that the planning surfaces other SIGs depend on remain current, actionable, and auditable.

## Vision

A repository where Responsible AI is a first-class concern of every authoring workflow rather than an afterthought; where contributors have rubrics, examples, and review partners that make RAI evaluation straightforward; and where the planning content the wider HVE ecosystem consumes reflects the SIG's current rubric and review practice.

## Goals (Current Cycle)

1. Maintain the RAI planning instruction set under `.github/instructions/rai-planning/` and keep it current with the SIG's evolving rubric.
2. Publish a documented RAI review rubric and intake process that other SIGs can call against.
3. Coordinate with SIG Security on threat modeling for agentic and LLM surfaces (joint ownership of AI-specific threat content).
4. Maintain disclaimer language and shared planning content under `.github/instructions/shared/disclaimer-language.instructions.md`.
5. Establish a quarterly content audit cadence to surface stale rubrics and out-of-date principle mappings.

## Principles Alignment

Rubrics, templates, and reviews align to the principle set defined in the SIG's RAI planning rubric. Each rubric in the RAI planning instruction set traces explicitly back to one or more of those principles, and the principle set itself is maintained as a versioned artifact owned by this SIG.

## Deliverables

Owned surfaces (durable artifacts under stewardship):

* RAI planning instructions under `.github/instructions/rai-planning/` (identity, capture coaching, risk classification, standards, security model, impact assessment, backlog handoff).
* Disclaimer language under `.github/instructions/shared/disclaimer-language.instructions.md`.
* RAI review rubric and intake documentation.
* Examples and templates illustrating principle-by-principle evaluation.

Recurring artifact types produced by the SIG:

* Feature requests and RAI RFCs for new rubric items, principle mappings, and disclaimer patterns.
* Impact assessments produced through the RAI planning workflow for in-scope artifacts.
* Gap analyses against the SIG's RAI planning rubric for owned and consulted surfaces.
* Evaluation-harness reports for AI-assisted artifacts undergoing RAI review.
* Dataset and persona audits commissioned in coordination with SIG Data Science.
* Harm-pattern advisories distilling recurring failure modes observed during reviews.
* Quarterly RAI content audit reports covering rubric currency, principle coverage, and contributor adoption.
* Quarterly RAI compliance digest summarizing reviews completed, principle coverage, and outstanding risks.
* Annual roll-up of RAI review trends and recommended rubric evolutions.

## In Scope

* Responsible AI planning instruction surfaces and prompts.
* Review rubrics, intake, and SLA for RAI review of new or changed artifacts.
* Coordination with SIG Security on AI-specific threat content.
* Coordination with SIG Standards on writing conventions for RAI content.
* Disclaimer language and consistent disclosure patterns across planning agents.

## Out of Scope

* General security review and supply-chain content (owned by SIG Security except where it intersects with AI-specific threats).
* Authoring style and Markdown conventions (owned by SIG Standards).
* Engineering tooling and CI (owned by SIG Engineering).
* Data-science-specific dataset and evaluation content (owned by SIG Data Science) except where principles cross over.

## Stakeholders

* Authors of agents, prompts, skills, and instructions that touch user-facing AI behavior.
* RAI reviewers within the SIG who execute reviews against the rubric.
* Other SIG chairs who request RAI reviews on their content.
* External consumers of the RAI planning surfaces who need confidence that the content reflects current practice.

## Cross-SIG Dependencies

* **SIG Security** jointly owns threat modeling for agentic and LLM systems; SIG RAI owns the principle-mapping, SIG Security owns the threat enumeration tooling.
* **SIG Standards** owns Markdown and writing conventions; SIG RAI defers to Standards on style and asserts authority on RAI technical content.
* **SIG Engineering** integrates RAI linters or validators into CI when SIG RAI publishes them.
* **SIG Emerging AI** consults SIG RAI on principle alignment before promoting experimental artifacts to durable surfaces.
* **SIG Data Science** consults SIG RAI on fairness and evaluation methodology for data-driven artifacts.

## Roles and Responsibilities

* **Chairs (1-3):** TBD (external recruit; per the Chair Recruitment Plan, no microsoft/hve-core maintainer may chair). Chairs prioritize the RAI backlog, run cadence, lead reviews of contentious cases, and represent the SIG in cross-SIG escalations.
* **Tech Leads (1-3):** TBD. Tech leads own architectural direction for the RAI planning instruction set, the review rubric, and disclaimer language; they perform PR review and mentor reviewers.
* **RAI Reviewers:** TBD. Reviewers conduct RAI reviews requested by other SIGs against the documented rubric and accrue privileges through demonstrated review quality.
* **Members:** TBD. Members contribute PRs, draft rubric updates, triage issues, and participate in discussions.

## Subprojects and Owned Directories

* `.github/instructions/rai-planning/`
* `.github/instructions/shared/disclaimer-language.instructions.md`
* RAI-relevant prompts and agents (paths cataloged on ratification)

<!--
Initial Membership Suggestions: TBD
-->

## Membership and Onboarding

Joining is open to any contributor in good standing under the [Code of Conduct](https://github.com/microsoft/hve-core/blob/main/CODE_OF_CONDUCT.md). Prospective members introduce themselves in the SIG: RAI discussion category and indicate the area of focus (rubric authoring, review, principle mapping, or coordination). Reviewer and approver privileges accrue through demonstrated contribution as described in [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md).

New-contributor starting points:

* Read the RAI planning identity and risk classification instructions and file a single observation as an issue.
* Pair with a tech lead on a review of a recent PR to learn the rubric.
* Audit one rubric in the RAI planning instruction set against current SIG practice and propose updates.

## Cadence

* **Async:** GitHub Discussions category SIG: RAI for proposals, rubric updates, and review requests.
* **Review intake:** RAI-review requests are filed as issues with the `rai-review` label and routed to a reviewer within five business days.
* **Optional sync:** Frequency, time zone, and meeting link TBD by the inaugural chair on ratification; meetings are recorded or summarized publicly per the Public Activity rule.

## Decision-Making

* **Lazy consensus** on routine rubric and content updates: 72-hour open window without objection.
* **Chair tie-break** when reviewers disagree within seven days.
* **Escalation** to the maintainer set for charter-affecting changes or contested principle interpretations.
* All deliberation occurs in public channels per the Public Activity rule in [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md).

## Escalation Path

1. Open a discussion in SIG: RAI and tag chairs.
2. Chairs triage within five business days.
3. If unresolved, chairs file a decision request to the maintainer set per [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md).

## Health and Success Metrics

* Currency of RAI planning instructions versus the SIG's published rubric.
* Median age of open RAI-review requests.
* Number of artifacts reviewed per quarter and the principle-by-principle distribution.
* Quarterly content-audit completion rate.
* Number of contributors qualified as reviewers.

## Lifecycle and Review

The SIG conducts an annual self-review on or before **Next Review** above. The review reaffirms scope, refreshes goals, updates membership, and either renews or proposes retirement. Retirement requires a maintainer vote per [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md) and reassignment of all owned directories.

## Amendment Process

Charter amendments are proposed via pull request. Material changes (scope, role definitions, owned directories) require a 7-day comment window and chair approval; non-material changes follow lazy consensus.

## Code of Conduct

All participants follow the Microsoft Open Source [Code of Conduct](https://github.com/microsoft/hve-core/blob/main/CODE_OF_CONDUCT.md).

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
