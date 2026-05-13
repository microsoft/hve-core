---
title: SIG Engineering
description: Charter for the engineering Special Interest Group in microsoft/hve-core
ms.topic: reference
ms.date: 2026-04-25
author: HVE Core Maintainers
---

**Status:** Proposed
**Created:** 2026-04-25
**Last Reviewed:** 2026-04-25
**Next Review:** 2027-04-25

## Mission

SIG Engineering owns the build, packaging, plugin generation, CI, and backlog/intake/triage tooling that turns microsoft/hve-core content into shippable artifacts. The SIG keeps day-to-day developer ergonomics healthy, ensures release pipelines are reproducible and auditable, and provides the integration surface every other SIG depends on for shipping their content.

## Vision

A repository where any contributor can validate, package, and release any artifact locally with a single `npm run` or `just` target, where CI gives a clear pass/fail signal in under fifteen minutes, and where the path from instruction file authored to plugin published is fully scripted and signed.

## Goals (Current Cycle)

1. Standardize the `npm run lint:*` and `validate:*` surface so every artifact category has a one-line validation command.
2. Reduce average green-CI time on pull requests through caching, matrix pruning, and selective regeneration.
3. Stabilize plugin generation outputs so collection edits produce deterministic diffs in `plugins/`.
4. Document the release pipeline end-to-end so a new maintainer can cut a release without tribal knowledge.
5. Land a backlog/intake/triage instruction surface that ADO, GitHub Issues, and Jira workflows share without duplication.

## Deliverables

Owned surfaces (durable artifacts under stewardship):

* Build and packaging scripts under `scripts/` (non-security) and the extension packaging pipeline under `extension/`.
* GitHub Actions workflows under `.github/workflows/` and the installer collection (`collections/installer.collection.*`).
* Plugin generation pipeline (`npm run plugin:generate`, `plugin:validate`) and the resulting outputs under `plugins/`.
* Backlog, intake, and triage instructions under `.github/instructions/ado/`, `.github/instructions/github/`, and `.github/instructions/jira/`.
* Release engineering automation: `release-please` configuration, changelog generation, version consistency checks.
* Developer ergonomics: `package.json` script catalog, `justfile` targets, local validation tooling, devcontainer parity with the Copilot Coding Agent environment.

Recurring artifact types produced by the SIG:

* Feature requests and developer-experience RFCs for the build, CI, and release surfaces.
* CI and tooling gap analyses (e.g., missing validators, cache misses, flaky steps) filed as issues with remediation plans.
* Quarterly CI health and trend reports covering median PR duration, cache hit rate, runner cost, and flake rate.
* Refactor proposals for `scripts/`, `npm run` catalog consolidation, and `justfile` target reorganization.
* Performance benchmarks for plugin generation idempotency and end-to-end release pipeline runs.
* Per-release retrospectives summarizing scope, regressions, and follow-on work.
* Devcontainer and Copilot Coding Agent parity audits whenever either environment changes.
* Annual roadmap update aligned with maintainer planning.

## In Scope

* Build, packaging, and plugin generation pipelines under `scripts/` (excluding `scripts/security/` and security-relevant linters).
* CI workflows under `.github/workflows/`.
* Installer collection (`collections/installer.collection.*`).
* Backlog/intake/triage instruction surfaces (ADO, GitHub, Jira).
* `npm run` script catalog, `justfile` targets, local validation tooling.
* Release engineering, semantic versioning, and changelog automation.
* Devcontainer and Copilot Coding Agent setup steps (`copilot-setup-steps.yml`, `.devcontainer/`).

## Out of Scope

* Security-specific scripts and linters (owned by SIG Security).
* Coding standards content and prompt-builder authoring conventions (owned by SIG Standards).
* Experimental agents, skills, and prompts (owned by SIG Emerging AI).
* Responsible AI rubrics and review criteria (owned by SIG RAI).
* Data-science notebook and skill conventions (owned by SIG Data Science).

## Stakeholders

* Repository maintainers shipping releases.
* Contributors authoring agents, prompts, instructions, and skills who depend on validation tooling.
* Downstream consumers of the VS Code extension and plugin marketplace artifacts.
* Other SIGs that depend on Engineering for CI, packaging, and release plumbing.

## Cross-SIG Dependencies

* **SIG Standards** authors the rules; SIG Engineering enforces them in CI.
* **SIG Security** owns `scripts/security/` and security-relevant linters; SIG Engineering integrates their results into CI gates.
* **SIG Emerging AI** hands off promoted artifacts; SIG Engineering ensures the artifact is wired into the appropriate collection and release flow.
* **SIG RAI** and **SIG Data Science** consume Engineering's collection and release tooling and contribute requirements for new validation surfaces.

## Roles and Responsibilities

* **Chairs (1-3):** TBD (external recruit; per the Chair Recruitment Plan, no microsoft/hve-core maintainer may chair). Chairs set the agenda, run cadence, drive prioritization, represent the SIG to maintainers, and are accountable for charter health.
* **Tech Leads (1-3):** TBD. Tech leads own architectural direction for the build, CI, and release pipelines, perform PR review on subproject changes, and mentor contributors.
* **Members:** TBD. Members contribute PRs, review changes, triage issues, and participate in SIG discussions.

## Subprojects and Owned Directories

* `scripts/` (excluding `scripts/security/` and security-relevant linters under `scripts/linting/`)
* `extension/`
* `collections/installer.collection.*`
* `.github/workflows/`
* `.github/instructions/ado/`
* `.github/instructions/github/`
* `.github/instructions/jira/`
* `package.json`, `justfile`, `release-please-config.json`, `audit-ci.json`, `codecov.yml`

<!--
Initial Membership Suggestions:
* WilliamBerryiii
* katriendg
* agreaves-ms (on return)
* bindsi
-->

## Membership and Onboarding

Joining is open to any contributor in good standing under the [Code of Conduct](https://github.com/microsoft/hve-core/blob/main/CODE_OF_CONDUCT.md). Prospective members open a discussion in the SIG: Engineering category introducing themselves and the area they want to work on. Reviewer and approver privileges accrue through demonstrated contribution as described in [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md).

New-contributor starting points:

* Pick an issue labeled `good-first-issue` in a SIG Engineering subproject.
* Run the full `npm run lint:all` chain locally and report any environment friction.
* Review a recent PR touching `scripts/` or `.github/workflows/` and leave constructive feedback.

## Cadence

* **Async:** GitHub Discussions category SIG: Engineering for design proposals, decision logs, and open questions.
* **Issue triage:** Weekly review of open issues against the SIG's owned directories.
* **Optional sync:** Frequency, time zone, and meeting link TBD by the inaugural chair on ratification; meeting notes are posted publicly.

## Decision-Making

* **Lazy consensus** on routine work: a proposal stands if no objections are raised within 72 hours on an open PR or discussion thread.
* **Chair tie-break** when reviewers disagree and consensus is not reachable within seven days.
* **Escalation** to the maintainer set if a decision is contested across SIGs or affects governance.
* All deliberation occurs in public channels per the Public Activity rule in [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md).

## Escalation Path

1. Open a discussion in SIG: Engineering and tag chairs.
2. Chairs attempt resolution within seven days.
3. If unresolved, chairs file a decision request to the maintainer set per [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md).

## Health and Success Metrics

* Median CI duration on `main` branch PRs.
* Number of `npm run` scripts producing structured logs under `logs/`.
* Plugin generation idempotency rate (regeneration produces no diff).
* Open issue age distribution in owned directories.
* Backlog/intake instruction file freshness (no stale references in linked workflows).

## Lifecycle and Review

The SIG conducts an annual self-review on or before **Next Review** above. The review confirms scope, refreshes goals, updates membership, and either renews or proposes retirement. Retirement requires a maintainer vote per [GOVERNANCE.md](https://github.com/microsoft/hve-core/blob/main/GOVERNANCE.md) and reassignment of all owned directories.

## Amendment Process

Charter amendments are proposed via pull request. Material changes (scope, role definitions, owned directories) require a 7-day comment window and chair approval; non-material changes (typos, link fixes) follow lazy consensus.

## Code of Conduct

All participants follow the Microsoft Open Source [Code of Conduct](https://github.com/microsoft/hve-core/blob/main/CODE_OF_CONDUCT.md). Concerns are reported per [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/SECURITY.md) for security issues and to maintainers for conduct issues.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
