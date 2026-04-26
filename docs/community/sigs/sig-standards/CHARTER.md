---
title: SIG Standards
description: Charter for the standards Special Interest Group in microsoft/hve-core
ms.topic: reference
ms.date: 2026-04-25
author: HVE Core Maintainers
---

**Status:** Proposed
**Created:** 2026-04-25
**Last Reviewed:** 2026-04-25
**Next Review:** 2027-04-25

## Mission

SIG Standards is the guardian of authoring conventions for microsoft/hve-core. The SIG owns coding standards, prompt-builder standards, the agent/prompt/instruction information architecture, frontmatter schemas, and documentation style so that every artifact across the repository is coherent, discoverable, reviewable, and high quality.

## Vision

A repository where any contributor can author a new agent, prompt, instruction, or skill by following a single linked standard, where naming and information architecture are predictable across collections, and where reviewers can resolve style debates by pointing at a documented rule rather than personal preference.

## Goals (Current Cycle)

1. Complete coverage of `applyTo` patterns for every coding-standards instruction file so language-specific guidance is auto-applied during authoring.
2. Publish a prompt-builder reference that defines the canonical structure for `.agent.md`, `.prompt.md`, `.instructions.md`, and `SKILL.md` files.
3. Stabilize frontmatter schemas in `scripts/linting/schemas/` and document the schema-to-file mapping so contributors know which schema applies.
4. Land a writing-style guide that resolves the most common review comments (voice, tone, hedging, em-dash policy).
5. Refresh `docs/contributing/` and `docs/templates/` so a new contributor can start a custom agent or prompt from a working template.

## Deliverables

Owned surfaces (durable artifacts under stewardship):

* Per-language coding standards under `.github/instructions/coding-standards/`.
* Core authoring instructions under `.github/instructions/hve-core/` (markdown, writing-style, prompt-builder, commit-message, pull-request).
* Frontmatter schemas under `scripts/linting/schemas/` and the `schema-mapping.json` registry.
* Contributor guides and templates under `docs/contributing/` and `docs/templates/`.
* Information architecture decisions for naming, categorization, collection layout, and skill structure.

Recurring artifact types produced by the SIG:

* Feature requests and writing-style RFCs covering voice, tone, hedging, and structural conventions.
* Information-architecture proposals for new artifact types, naming patterns, and directory layouts.
* Naming-convention and frontmatter-schema gap analyses across collections.
* Quarterly cross-plugin consistency audits flagging style, structural, and IA drift.
* Deprecation notices and migration guides for retired conventions, schemas, or templates.
* Glossary updates and template additions or revisions in `docs/templates/` and `docs/contributing/`.
* Style-debate decision logs published in the SIG: Standards discussion category.
* Annual standards drift report comparing on-disk content against the documented standard.

## In Scope

* Per-language coding standards (`.github/instructions/coding-standards/`).
* Core authoring instructions (`.github/instructions/hve-core/`).
* Contributor guides (`docs/contributing/`) and templates (`docs/templates/`).
* Frontmatter schemas and schema-to-file mapping.
* Information architecture for agents, prompts, instructions, skills, and collections (naming, categorization, directory layout).
* Style review of cross-cutting documentation (READMEs, announcements, role guides) for consistency with the writing-style instruction.

## Out of Scope

* Build and CI tooling that enforces standards (owned by SIG Engineering).
* Security-specific guidance and standards content (owned by SIG Security).
* Domain-specific content for RAI, Data Science, or Emerging AI surfaces.
* Per-collection curation (owned by the SIG that owns the collection).

## Stakeholders

* Authors of new agents, prompts, instructions, and skills.
* Reviewers who need a documented rule to cite during PR review.
* Other SIGs whose content must comply with repository-wide style and structural standards.
* Downstream consumers reading published documentation and plugin marketplace listings.

## Cross-SIG Dependencies

* **SIG Engineering** enforces standards via linting and validation; SIG Standards authors the rules and supplies schemas.
* **SIG Security** depends on Standards for cross-cutting style; Standards defers to Security on security-specific guidance.
* **SIG Emerging AI** uses Standards templates when promoting experimental artifacts to durable surfaces.
* **SIG RAI** and **SIG Data Science** consume Standards' authoring conventions and contribute domain-specific extensions.

## Roles and Responsibilities

* **Chairs (1-3):** TBD (external recruit; per the Chair Recruitment Plan, no microsoft/hve-core maintainer may chair). Chairs prioritize standards work, mediate style disputes, run cadence, and represent the SIG to maintainers.
* **Tech Leads (1-3):** TBD. Tech leads own architectural direction for the instruction surface, frontmatter schemas, and template library; perform PR review on standards changes; and mentor authors.
* **Members:** TBD. Members propose and review standards updates, draft templates, and triage style-related issues.

## Subprojects and Owned Directories

* `.github/instructions/coding-standards/`
* `.github/instructions/hve-core/`
* `docs/contributing/`
* `docs/templates/`
* `scripts/linting/schemas/` (schema definitions; SIG Engineering owns the validators that consume them)

<!--
Initial Membership Suggestions:
* ChrisRisner
* WilliamBerryiii
* katriendg
-->

## Membership and Onboarding

Joining is open to any contributor in good standing under the [Code of Conduct](../../../../CODE_OF_CONDUCT.md). Prospective members introduce themselves in the SIG: Standards discussion category and indicate the standards area they want to work on (a language, the prompt-builder surface, IA, or templates). Reviewer and approver privileges accrue through demonstrated contribution as described in [GOVERNANCE.md](../../../../GOVERNANCE.md).

New-contributor starting points:

* Pick an instruction file lacking an `applyTo` pattern and propose one.
* Review a recent PR adding a new agent or skill and confirm it follows the prompt-builder standard; file an issue if not.
* Convert a frequent review comment into a documented rule in the writing-style instruction.

## Cadence

* **Async:** GitHub Discussions category SIG: Standards for proposals, decision logs, and IA debates.
* **Style review:** Rolling review of PRs touching docs, instructions, prompts, agents, and skills for cross-cutting style adherence.
* **Optional sync:** Frequency, time zone, and meeting link TBD by the inaugural chair on ratification; meeting notes are posted publicly.

## Decision-Making

* **Lazy consensus** on routine clarifications and template additions: 72-hour open window without objection.
* **Chair tie-break** when reviewers disagree on a style or IA call within seven days.
* **Escalation** to the maintainer set for repository-wide breaking changes (e.g., directory restructures, schema migrations affecting every collection).
* All deliberation occurs in public channels per the Public Activity rule in [GOVERNANCE.md](../../../../GOVERNANCE.md).

## Escalation Path

1. Open a discussion in SIG: Standards and tag chairs.
2. Chairs attempt resolution within seven days, consulting affected SIGs as needed.
3. If unresolved, chairs file a decision request to the maintainer set per [GOVERNANCE.md](../../../../GOVERNANCE.md).

## Health and Success Metrics

* Coverage of `applyTo` patterns across instruction files (target: 100%).
* Frontmatter validation pass rate (target: 100% with `-WarningsAsErrors`).
* Time-to-decision on style debates raised in SIG: Standards discussions.
* Number of templates available in `docs/templates/` versus number of distinct artifact categories.
* Style consistency audit results across collections.

## Lifecycle and Review

The SIG conducts an annual self-review on or before **Next Review** above. The review reaffirms scope, refreshes goals, updates membership, and either renews or proposes retirement. Retirement requires a maintainer vote per [GOVERNANCE.md](../../../../GOVERNANCE.md) and reassignment of all owned directories.

## Amendment Process

Charter amendments are proposed via pull request. Material changes (scope, role definitions, owned directories) require a 7-day comment window and chair approval; non-material changes follow lazy consensus.

## Code of Conduct

All participants follow the Microsoft Open Source [Code of Conduct](../../../../CODE_OF_CONDUCT.md). Concerns are reported per [SECURITY.md](../../../../SECURITY.md) for security issues and to maintainers for conduct issues.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
