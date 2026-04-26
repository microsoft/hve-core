---
title: SIG Security
description: Charter for the security Special Interest Group in microsoft/hve-core
ms.topic: reference
ms.date: 2026-04-25
author: HVE Core Maintainers
---

**Status:** Proposed
**Created:** 2026-04-25
**Last Reviewed:** 2026-04-25
**Next Review:** 2027-04-25

## Mission

SIG Security owns end-to-end security posture for microsoft/hve-core: threat modeling, security review, OWASP and secure-by-design skill content, supply-chain hardening, dependency pinning, CI hardening, and scorecard projections. The SIG absorbs the prior sssc-ci scope and acts as the security review partner for every other SIG when their work touches sensitive surfaces.

## Vision

A repository whose every workflow is pinned, signed, and scanned; whose security guidance is current and discoverable; whose supply-chain posture is measurable against an adopted standard; and whose contributors can request and receive a clear security review on any artifact they ship.

## Goals (Current Cycle)

1. Bring all GitHub Actions workflows into compliance with dependency pinning and action version consistency policies.
2. Publish and maintain projected OpenSSF Scorecard ratings as a tracked health metric.
3. Refresh the OWASP skill set (Top 10, LLM, MCP, Agentic, CI/CD, Docker, Infrastructure) against the latest published versions.
4. Stand up a public security-review intake that other SIGs can call against on a known SLA.
5. Document the supply-chain story end-to-end: what is signed, by whom, with what tooling, and how a consumer verifies.

## Deliverables

Owned surfaces (durable artifacts under stewardship):

* Security planning, threat modeling, and review instructions under `.github/instructions/security/`.
* Security skills (OWASP variants, secure-by-design, security reviewer formats) under `.github/skills/security/`.
* Security collection (`collections/security.collection.*`) curation and maintenance.
* Security-focused scripts under `scripts/security/` and security-relevant linters under `scripts/linting/` (dependency pinning, action version consistency, SHA staleness, copyright validation).
* Repository security policy (`SECURITY.md`) and disclosure process documentation.
* Supply-chain artifacts: SBOMs, signed releases, scorecard projections, signed plugin manifests.

Recurring artifact types produced by the SIG:

* Feature requests and security RFCs for hardening workflows, scripts, and review tooling.
* Threat models for new and changed agent, prompt, skill, and workflow surfaces.
* Security advisories coordinated through `SECURITY.md` and published post-embargo.
* Gap analyses against the Microsoft SDL, OpenSSF Scorecard, SLSA, and Best Practices Badge.
* SBOM coverage and signature-verification reports per release.
* Vulnerability triage notes and remediation plans for issues filed against owned surfaces.
* Secure-by-design checklists tailored to common artifact categories.
* Quarterly supply-chain trend reports covering pinning compliance, SHA staleness, and Scorecard score deltas.
* Annual repository security posture report summarizing audits, advisories, and outstanding risks.

## In Scope

* Threat modeling, security review, and security planning instruction surfaces.
* OWASP and secure-by-design skill content.
* Supply-chain hardening: dependency pinning, signed artifacts (cosign), Sigstore integration, SBOM generation, Best Practices Badge, OpenSSF Scorecard, SLSA alignment.
* CI hardening: workflow permissions, action version consistency, SHA pinning, secrets scanning configuration.
* Security-relevant linters: `Test-DependencyPinning`, `Test-ActionVersionConsistency`, `Test-ShaStaleness`, copyright header validation.
* Security policy and vulnerability disclosure process.

## Out of Scope

* General build and packaging scripts (owned by SIG Engineering).
* Coding standards and authoring conventions outside the security domain (owned by SIG Standards).
* Responsible AI planning content (owned by SIG RAI).
* Data-science-specific data handling guidance (owned by SIG Data Science) except where it intersects with security skills.

## Stakeholders

* Repository maintainers responsible for shipping signed, hardened releases.
* Authors of security-adjacent agents, prompts, and skills who need review.
* Downstream consumers verifying provenance and integrity of published artifacts.
* Other SIGs requesting security review on their work product.
* External security researchers reporting vulnerabilities through `SECURITY.md`.

## Cross-SIG Dependencies

* **SIG Engineering** integrates security linters and validators into CI; SIG Security supplies the rules and tooling.
* **SIG Standards** owns general authoring style; SIG Security defers to Standards on writing conventions and asserts authority on security technical content.
* **SIG RAI** coordinates with SIG Security on threats specific to AI systems; the two SIGs jointly own threat modeling for agentic surfaces.
* **SIG Emerging AI** requests security review at promotion time before experimental artifacts graduate to durable surfaces.
* **SIG Data Science** consults SIG Security on data-handling and dataset provenance concerns.

## Roles and Responsibilities

* **Chairs (1-3):** TBD (external recruit; per the Chair Recruitment Plan, no microsoft/hve-core maintainer may chair). Chairs prioritize the security backlog, run cadence, lead incident coordination, and represent the SIG in cross-SIG escalations.
* **Tech Leads (1-3):** TBD. Tech leads own architectural direction for threat models, the OWASP skill surface, supply-chain tooling, and security CI; they perform PR review on owned subprojects and mentor reviewers.
* **Security Reviewers:** TBD. Reviewers conduct security reviews requested by other SIGs against the documented rubric; they accrue privileges through demonstrated review quality.
* **Members:** TBD. Members contribute PRs, draft skill updates, triage issues, and participate in discussions.

## Subprojects and Owned Directories

* `.github/instructions/security/`
* `.github/skills/security/`
* `collections/security.collection.*`
* `scripts/security/`
* `scripts/linting/` (security-relevant linters only)
* `SECURITY.md`
* `audit-ci.json` (in coordination with SIG Engineering)

<!--
Initial Membership Suggestions:
* rezatnoMsirhC
* WilliamBerryiii
* agreaves-ms (on return)
-->

## Membership and Onboarding

Joining is open to any contributor in good standing under the [Code of Conduct](../../../../CODE_OF_CONDUCT.md). Prospective members introduce themselves in the SIG: Security discussion category and indicate the security area they want to work on (threat modeling, OWASP skills, supply-chain, CI hardening, or review). Reviewer and approver privileges accrue through demonstrated contribution as described in [GOVERNANCE.md](../../../../GOVERNANCE.md).

New-contributor starting points:

* Run `npm run lint:dependency-pinning` and address any flagged workflows.
* Review the most recent OWASP skill against the current published edition and file an update issue.
* Pair with a tech lead on a security review of a recent PR to learn the rubric.

## Cadence

* **Async:** GitHub Discussions category SIG: Security for design proposals, security advisories coordination, and review requests.
* **Review intake:** Security-review requests are filed as issues with the `security-review` label and routed to a reviewer within five business days.
* **Optional sync:** Frequency, time zone, and meeting link TBD by the inaugural chair on ratification; sensitive content is handled in private channels per disclosure policy and summarized publicly when safe.

## Decision-Making

* **Lazy consensus** on routine skill updates and non-sensitive guidance: 72-hour open window without objection.
* **Chair tie-break** when reviewers disagree within seven days.
* **Escalation** to the maintainer set for cross-SIG security policy changes or release-blocking findings.
* **Embargoed work:** Vulnerability response follows the disclosure policy in [SECURITY.md](../../../../SECURITY.md); decisions on embargo timing are made by chairs in coordination with maintainers and surfaced publicly post-embargo.
* All non-embargoed deliberation occurs in public channels per the Public Activity rule in [GOVERNANCE.md](../../../../GOVERNANCE.md).

## Escalation Path

1. Open a discussion in SIG: Security and tag chairs (use `SECURITY.md` channel for embargoed issues).
2. Chairs triage within five business days.
3. If unresolved or release-blocking, chairs file a decision request to the maintainer set per [GOVERNANCE.md](../../../../GOVERNANCE.md).

## Health and Success Metrics

* OpenSSF Scorecard projected and actual ratings.
* Percentage of `.github/workflows/` files passing dependency pinning, action version consistency, and SHA staleness checks.
* Median age of open security-review requests.
* Currency of OWASP skill content versus latest published versions.
* Number of vulnerabilities resolved within disclosure SLA.

## Lifecycle and Review

The SIG conducts an annual self-review on or before **Next Review** above. The review reaffirms scope, refreshes goals, updates membership, and either renews or proposes retirement. Retirement requires a maintainer vote per [GOVERNANCE.md](../../../../GOVERNANCE.md) and reassignment of all owned directories.

## Amendment Process

Charter amendments are proposed via pull request. Material changes (scope, role definitions, owned directories) require a 7-day comment window and chair approval; non-material changes follow lazy consensus.

## Code of Conduct

All participants follow the Microsoft Open Source [Code of Conduct](../../../../CODE_OF_CONDUCT.md). Vulnerability reports are handled per [SECURITY.md](../../../../SECURITY.md); conduct concerns are reported to maintainers.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
