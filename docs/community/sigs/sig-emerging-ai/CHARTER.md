---
title: SIG Emerging AI
description: Charter for the emerging-AI Special Interest Group in microsoft/hve-core
ms.topic: reference
ms.date: 2026-04-25
author: HVE Core Maintainers
---

**Status:** Proposed
**Created:** 2026-04-25
**Last Reviewed:** 2026-04-25
**Next Review:** 2027-04-25

## Mission

SIG Emerging AI runs the incubation surface for microsoft/hve-core. The SIG hosts experimental agents, prompts, skills, and the experimental collection, manages a defined incubation lifecycle, and promotes proven artifacts to the receiving SIG that owns the relevant durable surface.

## Vision

A transparent, time-boxed incubator where new agentic patterns are explored without polluting durable surfaces, where promotion criteria are explicit and consistently applied, and where graduating artifacts arrive at receiving SIGs with the metadata, tests, and review evidence required for production adoption.

## Goals (Current Cycle)

1. Document the incubation lifecycle stages, entry criteria, and exit criteria for experimental artifacts.
2. Publish promotion criteria covering reproducibility, RAI principle alignment, security review, and standards conformance.
3. Curate the experimental collection (`collections/experimental.collection.*`) and ensure each entry has an owner and a review window.
4. Define a deprecation policy for experimental artifacts that fail to graduate within the review window.
5. Establish a handoff matrix mapping graduating artifact types to receiving SIGs.

## Incubation Lifecycle

Experimental artifacts move through four stages:

1. **Proposal:** authored as a discussion or draft PR; captured in the experimental collection with an owner and a 6-month default review window.
2. **Incubating:** merged under `.github/{agents,prompts,skills}/experimental/` or in `collections/experimental.collection.*`; iterated openly; eligible for breaking changes without notice.
3. **Graduating:** entry criteria for the receiving SIG are met; SIG Emerging AI files a promotion proposal that the receiving SIG reviews against its own conventions.
4. **Promoted or Archived:** on acceptance, the receiving SIG takes ownership and the artifact moves out of `experimental/`; on rejection or review-window lapse, the artifact is archived per the deprecation policy.

## Promotion Criteria

A graduating artifact provides:

* **Reproducibility:** documented dependencies, deterministic behavior where applicable, and a working invocation example.
* **RAI alignment:** documented evaluation against the SIG RAI rubric for the principles relevant to the artifact (consult SIG RAI).
* **Security review:** dependency, secret-handling, and supply-chain review acknowledgment from SIG Security.
* **Standards conformance:** frontmatter, instructions, and authoring conventions per SIG Standards (`prompt-builder`, `markdown`, `writing-style`).
* **Receiving-SIG acceptance:** explicit acknowledgment from the receiving SIG that the artifact meets that SIG's conventions and is ready for ownership transfer.

## Time-Boxed Experiments

Each incubating artifact has a default 6-month review window recorded in the experimental collection manifest. At the window boundary, SIG Emerging AI:

* Promotes the artifact (graduating path), or
* Renews the window with documented rationale, or
* Archives the artifact per the deprecation policy.

## Deprecation Policy

Artifacts that lapse without renewal or promotion are removed from the experimental collection, moved to a documented archived state, and listed in the SIG's annual review. Archived artifacts may be revived through a fresh proposal.

## Handoff Matrix

| Graduating Artifact Type             | Receiving SIG    |
|--------------------------------------|------------------|
| Notebook, Python data, dataset guide | SIG Data Science |
| RAI rubric or evaluation instruction | SIG RAI          |
| Security skill or instruction        | SIG Security     |
| Authoring convention or template     | SIG Standards    |
| CI, packaging, release tooling       | SIG Engineering  |

A receiving SIG may decline a handoff with documented rationale; the declined artifact returns to incubation or proceeds to archive.

## Deliverables

Owned surfaces (durable artifacts under stewardship):

* Documented incubation lifecycle, promotion criteria, and deprecation policy.
* Curated experimental collection manifests with per-entry owners and review windows.
* Handoff matrix and promotion proposal template.

Recurring artifact types produced by the SIG:

* Feature requests and incubation RFCs for new experimental patterns, agents, prompts, or skills.
* Per-entry stage-gate review reports issued at proposal, mid-window, and review-window boundaries.
* Technology-radar and trend reports surveying emerging agentic patterns the SIG is tracking.
* Feasibility spike write-ups documenting scope, learnings, and graduate-or-archive recommendation.
* Promotion proposals delivered to receiving SIGs with the full promotion-criteria evidence package.
* Deprecation and sunset notices for artifacts that lapse without renewal or promotion.
* Quarterly experimental collection audit summarizing stage distribution and ownership freshness.
* Semi-annual incubation portfolio review covering throughput, acceptance rate, and policy adjustments.
* Annual archive and graduation report.

## In Scope

* Experimental agents under `.github/agents/experimental/`.
* Experimental skills under `.github/skills/experimental/`.
* Experimental prompts under `.github/prompts/experimental/` (where present).
* Experimental collection (`collections/experimental.collection.*`) curation.
* Promotion pathway: graduating proven experimental artifacts to the receiving SIG (Engineering, Standards, Security, RAI, Data Science).

## Out of Scope

* Durable, production-tier agents, prompts, and skills (owned by the receiving SIG after promotion).
* Build and CI for experimental artifacts beyond what is needed for incubation (handed off to SIG Engineering on promotion).
* Security review of experimental artifacts at promotion time (coordinated with SIG Security).
* Standards conformance enforcement on the durable surface (owned by SIG Standards).

## Stakeholders

* Authors of experimental agents, prompts, and skills.
* Receiving SIGs that accept graduating artifacts.
* Consumers of the experimental collection who use incubating artifacts with explicit awareness of breaking-change risk.

## Cross-SIG Dependencies

* **SIG Engineering** owns CI; SIG Emerging AI requests minimal validation for incubating artifacts and full validation gating on promotion.
* **SIG Standards** owns authoring conventions; SIG Emerging AI defers to Standards for the conformance review portion of promotion.
* **SIG Security** owns security review; SIG Emerging AI requests review at promotion and on demand for incubating artifacts that handle sensitive surfaces.
* **SIG RAI** consults on principle alignment for artifacts with RAI surface area.
* **SIG Data Science** receives notebook, Python data, and dataset-related graduating artifacts.

## Roles and Responsibilities

* **Chairs (1-3):** TBD (external recruit; per the Chair Recruitment Plan, no microsoft/hve-core maintainer may chair). Chairs run the incubation backlog, schedule review-window decisions, and represent the SIG in cross-SIG promotion negotiations.
* **Tech Leads (1-3):** TBD. Tech leads own the lifecycle documentation, the promotion criteria, and the handoff matrix; they mentor reviewers.
* **Reviewers:** TBD. Reviewers triage incoming proposals, validate incubating artifacts against minimal hygiene rules, and prepare promotion packages for receiving SIGs.
* **Members:** TBD. Members propose experiments, contribute PRs, and participate in discussions.

## Subprojects and Owned Directories

* `.github/agents/experimental/`
* `.github/skills/experimental/`
* `.github/prompts/experimental/` (where present)
* `collections/experimental.collection.*`

<!--
Initial Membership Suggestions:
* chaosdinosaur
* katriendg
-->

## Membership and Onboarding

Joining is open to any contributor in good standing under the [Code of Conduct](../../../../CODE_OF_CONDUCT.md). Prospective members introduce themselves in the SIG: Emerging AI discussion category and indicate the area of focus (incubation triage, lifecycle docs, promotion review, or experimental authoring). Reviewer and approver privileges accrue through demonstrated contribution as described in [GOVERNANCE.md](../../../../GOVERNANCE.md).

New-contributor starting points:

* Audit one entry in the experimental collection against the lifecycle definition and file an owner-and-window issue.
* Draft a promotion proposal for an artifact you believe is graduating-ready.
* Pair with a tech lead to review an incoming experimental proposal.

## Cadence

* **Async:** GitHub Discussions category SIG: Emerging AI for proposals, lifecycle decisions, and promotion negotiations.
* **Reviews:** PRs touching owned directories receive review acknowledgment within five business days.
* **Optional sync:** Frequency, time zone, and meeting link TBD by the inaugural chair on ratification; meetings are recorded or summarized publicly per the Public Activity rule.

## Decision-Making

* **Lazy consensus** on routine incubation and collection updates: 72-hour open window without objection.
* **Chair tie-break** when reviewers disagree within seven days.
* **Escalation** to the maintainer set for charter-affecting changes, lifecycle policy changes, or cross-SIG promotion conflicts.
* All deliberation occurs in public channels per the Public Activity rule in [GOVERNANCE.md](../../../../GOVERNANCE.md).

## Escalation Path

1. Open a discussion in SIG: Emerging AI and tag chairs.
2. Chairs triage within five business days.
3. If unresolved, chairs file a decision request to the maintainer set per [GOVERNANCE.md](../../../../GOVERNANCE.md).

## Health and Success Metrics

* Number of artifacts in each lifecycle stage (proposal, incubating, graduating, promoted, archived).
* Median time from proposal to promotion or archive.
* Promotion acceptance rate by receiving SIG.
* Quarterly review cadence completion.
* Annual archive and graduation report published.

## Lifecycle and Review

The SIG conducts an annual self-review on or before **Next Review** above. The review reaffirms scope, refreshes goals, updates membership, audits the experimental collection against the lifecycle definition, and either renews or proposes retirement. Retirement requires a maintainer vote per [GOVERNANCE.md](../../../../GOVERNANCE.md) and reassignment of all owned directories.

## Amendment Process

Charter amendments are proposed via pull request. Material changes (scope, lifecycle stages, promotion criteria, handoff matrix, role definitions, owned directories) require a 7-day comment window and chair approval; non-material changes follow lazy consensus.

## Code of Conduct

All participants follow the Microsoft Open Source [Code of Conduct](../../../../CODE_OF_CONDUCT.md).

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
