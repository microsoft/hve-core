---
title: Governance
description: Project governance model, roles, decision-making processes, and contribution authority for HVE Core
author: HVE Core Team
ms.date: 2026-04-25
ms.topic: reference
keywords:
  - governance
  - decision-making
  - roles
  - maintainers
  - contributors
estimated_reading_time: 8
---

HVE Core uses a liberal contribution model where active contributors are recognized for current work. Microsoft maintains stewardship of the project while welcoming community contributions and leadership.

## Governance Model

This project operates under a corporate-sponsored maintainer model:

* Microsoft provides stewardship, infrastructure, and core maintainer resources
* Community contributors participate through standard open source workflows
* Decision authority flows from active participation rather than historical contribution
* Consensus-seeking is preferred over voting for routine decisions

## Roles and Responsibilities

The following matrix summarizes capabilities by role:

| Capability             | Maintainer | SIG Chair | Triage | Contributor |
|:-----------------------|:----------:|:---------:|:------:|:-----------:|
| Code review            |     ✅      |  Advise   |   ✅    |      ✅      |
| Merge pull requests    |     ✅      |  Advise   |   ❌    |      ❌      |
| Release management     |     ✅      |     ❌     |   ❌    |      ❌      |
| Architecture decisions |     ✅      |  Advise   | Advise |   Propose   |
| Issue triage           |     ✅      |  Advise   |   ✅    |      ❌      |
| Label management       |     ✅      |     ❌     |   ✅    |      ❌      |

### Maintainers

Maintainers guide project direction, manage releases, and resolve conflicts.

| Responsibility      | Description                                                 |
|:--------------------|:------------------------------------------------------------|
| Technical direction | Set architectural standards and approve significant changes |
| Release management  | Coordinate versioning, changelogs, and publication          |
| Community health    | Enforce code of conduct and foster inclusive participation  |
| Access management   | Grant and revoke repository permissions                     |

The current maintainer roster is published in [.github/MAINTAINERS.md](.github/MAINTAINERS.md). Membership in the [@microsoft/edge-ai-core-dev](https://github.com/orgs/microsoft/teams/edge-ai-core-dev) team backs repository permissions.

#### Maintainer Continuity and Quorum

The active maintainer roster maintains a minimum of three members. Maintainer status is
earned through sustained contribution and is added as the bar described in Role
Progression is met; there is no upper cap on the number of maintainers.

If a maintainer takes a Leave of Absence (LOA), is otherwise unable to serve, or the
active roster would drop below three, the remaining maintainers vote under the
Governance-tier decision rules (consensus + one-week comment window) to promote a
contributor to **Maintainer Pro Tem**.

A Maintainer Pro Tem holds full maintainer authority and serves until the earlier of:

1. Three months elapsed since promotion, or
2. The LOA maintainer returning to active service.

At the end of the pro tem term, the pro tem either steps down, is reaffirmed as a
permanent maintainer under the standard Role Progression rules if their contribution
record qualifies, or, by re-vote of the remaining maintainers, has the pro tem term
extended for one additional three-month period if the original LOA continues.

Reaffirmation requires an explicit vote of the remaining maintainers under
Governance-tier rules. The vote process and discussion are conducted privately; the
**outcome** (promotion confirmed, pro tem ended, or term extended) is announced
publicly in the `Maintainers` GitHub Discussions category and reflected in
`MAINTAINERS.md`.

### Triage Contributors

Triage contributors assist maintainers by managing issue flow and initial assessments.

| Responsibility     | Description                                                           |
|:-------------------|:----------------------------------------------------------------------|
| Issue labeling     | Apply appropriate labels to new issues                                |
| Initial assessment | Identify duplicates, request clarification, verify reproduction steps |
| Community support  | Answer questions and direct contributors to resources                 |

### Contributors

Contributors improve the project through code, documentation, and community engagement.

| Responsibility          | Description                                                  |
|:------------------------|:-------------------------------------------------------------|
| Code contributions      | Submit pull requests following contribution guidelines       |
| Documentation           | Improve guides, fix errors, add examples                     |
| Issue reporting         | Report bugs with reproduction steps and suggest enhancements |
| Community participation | Engage in discussions and help other users                   |

## Special Interest Groups

A Special Interest Group (SIG) is an artifact-owning team that takes responsibility for a defined surface of the repository (directories, collections, and instructional content). Each SIG operates under a charter and is attached to [.github/CODEOWNERS](.github/CODEOWNERS) once its GitHub Team is provisioned.

| SIG                                                                 | Owned Surface                                                                                                              |
|:--------------------------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------|
| [SIG Engineering](docs/community/sigs/sig-engineering/CHARTER.md)   | Build, scripts, packaging, plugin generation, CI workflows, and backlog/intake/triage instruction surface.                 |
| [SIG Standards](docs/community/sigs/sig-standards/CHARTER.md)       | Coding standards, prompt-builder standards, agent/prompt/instruction information architecture, and documentation style.    |
| [SIG Security](docs/community/sigs/sig-security/CHARTER.md)         | Security review, threat modeling, OWASP skills, supply-chain security, CI hardening, dependency pinning, and scorecards.   |
| [SIG RAI](docs/community/sigs/sig-rai/CHARTER.md)                   | Responsible AI planning artifacts and review rubric.                                                                       |
| [SIG Data Science](docs/community/sigs/sig-data-science/CHARTER.md) | Data Science collection, notebook and Python skill conventions, and data-handling guidance.                                |
| [SIG Emerging AI](docs/community/sigs/sig-emerging-ai/CHARTER.md)   | Experimental agents, prompts, skills, and collections (incubation surface that promotes proven patterns to receiving SIG). |

Full charters live under [docs/community/sigs/](docs/community/sigs/README.md).

### Chair Recruitment

SIG chairs are recruited in two phases. Phase 0 seeds chairs internally from the active maintainer pool to bootstrap each SIG. Phase 1 opens a public call inviting non-maintainer contributors who have demonstrated sustained contribution to the owned surface.

Eligibility:

* Candidate is not a current maintainer.
* Candidate has demonstrated prior contribution to the SIG's owned surface (code, review, documentation, or triage).
* Candidate declares any conflicts of interest in the charter pull request.

Terms and onboarding:

* Chair term: 12 months, renewable once for a maximum of 24 consecutive months.
* 6-month cooldown before a former chair may be re-nominated for the same SIG.
* Onboarding: (1) charter PR opened, (2) COI declaration recorded, (3) chair listed in `MAINTAINERS.md` and the SIG charter, (4) repository team membership granted, (5) public announcement in the `Maintainers` GitHub Discussions category.

Removal:

* Voluntary step-down at any time.
* Inactivity removal after 90 days of no SIG activity.
* For-cause removal by Governance-tier vote of the remaining maintainers.

### Working Groups (Deferred)

Working Groups (WGs) may be added through a future amendment to this document. The structural charter template, sponsoring-SIG mechanic, and chair-eligibility rules will mirror those defined for SIGs above.

## Decision-Making Process

Decisions follow a tiered model based on impact and reversibility.

### Routine Changes

Standard pull requests for bug fixes, documentation updates, and minor enhancements:

* Require one maintainer approval
* Merged after CI checks pass
* No waiting period unless review comments are pending

### Significant Changes

New features, API additions, or changes affecting multiple components:

* Require two maintainer approvals
* Allow 48-hour review window for maintainer input
* May require design discussion in an issue before implementation

### Breaking Changes

Changes that alter existing behavior or remove functionality:

* Require two maintainer approvals with explicit breaking-change acknowledgment
* Document migration path in changelog and relevant documentation
* Follow semantic versioning for major version increments

### Governance Changes

Modifications to this governance document or project policies:

* Require consensus among active maintainers
* Allow one-week comment period for community input

### Public Activity

All SIG activity (design proposals, decision logs, scope debates, and routine
deliberation) SHALL occur in public channels (GitHub Discussions, public issues,
public PRs) wherever possible. Private deliberation is permitted only for:

1. Security disclosures handled under `SECURITY.md`,
2. Personnel matters (e.g., maintainer pro tem and reaffirmation votes), and
3. Pre-publication coordination with Microsoft stewardship.

For private deliberations, the resulting **decision** is published in the appropriate
public channel (Discussions category, `MAINTAINERS.md`, or `GOVERNANCE.md` amendment)
even when the deliberation itself remains private.

## Role Progression

Contributors advance through demonstrated commitment and quality work.

### Becoming a Triage Contributor

Contributors may be nominated for triage status after:

* Sustained positive contributions over three or more months
* Demonstrated understanding of project scope and standards
* Consistent, helpful engagement with other contributors

Nomination process:

1. Existing maintainer nominates candidate in a private discussion
2. Maintainers reach consensus on the nomination
3. Candidate is invited and onboarded to triage responsibilities

### Becoming a Maintainer

Triage contributors and significant contributors may be nominated for maintainer status after:

* Consistent high-quality contributions over six or more months
* Technical judgment aligned with project direction
* Demonstrated ability to mentor other contributors

Nomination process:

1. Existing maintainer nominates candidate
2. Maintainers reach consensus
3. Candidate is onboarded to maintainer responsibilities

### Inactivity and Role Changes

* Contributors inactive for six months may have elevated permissions reviewed
* Role removal is not punitive and contributors may return when availability permits
* Departing maintainers should assist with knowledge transfer when possible

## Dispute Resolution

When contributors disagree on technical or process matters:

1. Discussion: Parties discuss the issue in the relevant pull request or issue
2. Maintainer input: If unresolved, a maintainer provides guidance
3. Maintainer decision: If consensus remains elusive, maintainers make a binding decision

Code of conduct violations follow the process defined in [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).

## Inactivity Closure Policy

Open issues and discussions that remain inactive create noise for contributors and maintainers. This section defines the lifecycle policy for closing inactive items. Automation that enforces this policy (stale bot, scheduled workflows) is a separate effort that references these thresholds.

For pull request inactivity policy, see [Pull Request Inactivity Policy](./CONTRIBUTING.md#pull-request-inactivity-policy) in CONTRIBUTING.md.

### Issues

Issue inactivity follows a three-stage lifecycle:

| Stage        | Trigger                                      | Label          | Action                        |
|:-------------|:---------------------------------------------|:---------------|:------------------------------|
| Active       | Any activity within the past 60 days         | (none)         | Normal lifecycle              |
| Stale        | 60 days without activity                     | `stale`        | Warning comment posted        |
| Closed-stale | 14 days after `stale` label without activity | `closed-stale` | Issue closed as `not_planned` |

Exemptions that prevent automatic closure:

* Issues labeled `pinned`, `security`, or `do-not-close`
* Issues assigned to any milestone

Reopening rules:

* Any participant can reopen a stale-closed issue with additional context
* Reopening removes the `stale` label and resets the inactivity clock

### Discussions

The same 60-day warning and 14-day closure thresholds apply to GitHub Discussions in principle. The same exemptions that prevent automatic closure for issues (pinned, security, do-not-close, or assigned to a milestone) and the same reopening behavior (reopening clears any stale status and resets the inactivity clock) apply to Discussions. Because current automation tooling (actions/stale) does not support Discussions, enforcement is manual through periodic triage until dedicated tooling is implemented.

## Access Continuity

Project continuity is ensured through Microsoft stewardship:

* Multiple Microsoft employees maintain administrative access
* Critical credentials (VS Code Marketplace publish, GitHub admin, CI/CD) are managed through Microsoft infrastructure
* Succession planning ensures no single point of failure for project operations
* Repository, domain, and service access survive individual personnel changes

## Contribution Authorization

All contributions require agreement to the project license terms:

* External contributors sign the [Microsoft Contributor License Agreement](https://cla.opensource.microsoft.com/) on their first pull request
* The CLA bot automatically verifies agreement status
* Signed agreements authorize contribution under the [MIT License](./LICENSE)

## Amending This Document

Changes to this governance document follow the governance changes process:

1. Propose changes via pull request with clear rationale
2. Allow one-week comment period for community input
3. Obtain maintainer consensus
4. Merge and communicate changes to the community

📜 This governance document was created to meet [OSSF Best Practices Badge](https://www.bestpractices.dev/) Silver-level requirements.

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
