---
title: Governance
description: Project governance model, roles, decision-making processes, and contribution authority for HVE Core
author: HVE Core Team
ms.date: 2026-01-21
ms.topic: reference
keywords:
  - governance
  - decision-making
  - roles
  - maintainers
  - contributors
estimated_reading_time: 5
---

HVE Core uses a liberal contribution model where active contributors are recognized for current work. Microsoft maintains stewardship of the project while welcoming community contributions and leadership.

## Governance Model

This project operates under a **corporate-sponsored maintainer model**:

* Microsoft provides stewardship, infrastructure, and core maintainer resources
* Community contributors participate through standard open source workflows
* Decision authority flows from active participation rather than historical contribution
* Consensus-seeking is preferred over voting for routine decisions

## Roles and Responsibilities

The following matrix summarizes capabilities by role:

| Capability             | Maintainer | Triage | Contributor |
|:-----------------------|:----------:|:------:|:-----------:|
| Code review            |     ✅      |   ✅    |      ✅      |
| Merge pull requests    |     ✅      |   ❌    |      ❌      |
| Release management     |     ✅      |   ❌    |      ❌      |
| Architecture decisions |     ✅      | Advise |   Propose   |
| Issue triage           |     ✅      |   ✅    |      ❌      |
| Label management       |     ✅      |   ✅    |      ❌      |

### Maintainers

Maintainers guide project direction, manage releases, and resolve conflicts.

| Responsibility      | Description                                                 |
|:--------------------|:------------------------------------------------------------|
| Technical direction | Set architectural standards and approve significant changes |
| Release management  | Coordinate versioning, changelogs, and publication          |
| Community health    | Enforce code of conduct and foster inclusive participation  |
| Access management   | Grant and revoke repository permissions                     |

Current maintainers are members of the [@microsoft/edge-ai-core-dev](https://github.com/orgs/microsoft/teams/edge-ai-core-dev) team.

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

1. **Discussion**: Parties discuss the issue in the relevant pull request or issue
2. **Maintainer input**: If unresolved, a maintainer provides guidance
3. **Maintainer decision**: If consensus remains elusive, maintainers make a binding decision

Code of conduct violations follow the process defined in [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).

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

---

📜 This governance document was created to meet [OSSF Best Practices Badge](https://www.bestpractices.dev/) Silver-level requirements.
