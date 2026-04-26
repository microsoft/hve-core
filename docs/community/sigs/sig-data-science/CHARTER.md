---
title: SIG Data Science
description: Charter for the data-science Special Interest Group in microsoft/hve-core
ms.topic: reference
ms.date: 2026-04-25
author: HVE Core Maintainers
---

**Status:** Proposed
**Created:** 2026-04-25
**Last Reviewed:** 2026-04-25
**Next Review:** 2027-04-25

## Mission

SIG Data Science owns the Data Science collection, notebook conventions, Python data-work standards, and dataset-handling guidance for microsoft/hve-core. The SIG ensures notebook-bearing and data-bearing artifacts shipped from this repository are reproducible, evaluable, and maintainable across releases.

## Vision

A repository where notebook and Python data artifacts are authored to a consistent, reproducible standard; where dataset handling, evaluation, and MLOps lifecycle expectations are documented and easy to follow; and where downstream consumers of the Data Science collection can rerun, audit, and extend the work without bespoke onboarding.

## Goals (Current Cycle)

1. Curate the Data Science collection (`collections/data-science.collection.*`) and ensure its membership remains accurate, scoped, and validated.
2. Publish notebook reproducibility conventions covering environment pinning, deterministic seeds, kernel selection, and output stripping.
3. Publish Python data-work conventions consistent with `python-foundational` and `uv-projects` instructions.
4. Document dataset-handling guidance: provenance, licensing, sensitivity classification, and storage location norms.
5. Define evaluation-harness expectations for data-driven artifacts, including reporting structure and reproducibility floor.

## Reproducibility Floor

Notebook and Python artifacts owned by the SIG meet a documented reproducibility floor: pinned environments, deterministic seeds where applicable, declared input data shape and location, declared kernel and runtime, and stripped or redacted outputs in committed notebooks unless preserved deliberately.

## Deliverables

Owned surfaces (durable artifacts under stewardship):

* Curated Data Science collection manifests.
* Notebook authoring and review conventions.
* Python data-work conventions and lint configuration tied to `lint:py`.
* Dataset-handling guidance document.
* Evaluation-harness expectations and example artifacts.
* MLOps lifecycle guidance covering training, evaluation, packaging, and handoff.

Recurring artifact types produced by the SIG:

* Feature requests and data-science RFCs covering notebook, Python, dataset, and evaluation surfaces.
* Dataset specifications documenting provenance, licensing, sensitivity classification, and storage location.
* Reproducibility audits scoring notebook and Python artifacts against the reproducibility floor.
* MLOps lifecycle gap analyses identifying missing training, evaluation, packaging, or handoff coverage.
* Evaluation-set drift reports comparing current eval results against the prior baseline.
* Notebook quality reviews summarizing convention conformance and reproducibility findings.
* Synthetic-data and data-handling risk briefs prepared in coordination with SIG Security and SIG RAI.
* Quarterly model card and dataset card roll-up across the Data Science collection.
* Annual collection health report covering currency, reproducibility, and accepted graduations from SIG Emerging AI.

## In Scope

* Data Science collection (`collections/data-science.collection.*`) curation and lifecycle.
* Data-Science-scoped agents, instructions, and skills.
* Notebook authoring conventions (Jupyter, Quarto) and reproducibility expectations.
* Python skill conventions for data work, including environment management and dataset handling guidance.
* Evaluation harness conventions and reporting structure for data-driven artifacts.
* MLOps lifecycle guidance for data-driven artifacts owned by the SIG.

## Out of Scope

* General Python coding standards (owned by SIG Standards).
* Responsible AI rubrics applied to data work (owned by SIG RAI; SIG Data Science consults).
* Experimental data-science prototypes (owned by SIG Emerging AI until promoted).
* Build and CI tooling (owned by SIG Engineering; SIG Data Science consults on data-specific validators).

## Stakeholders

* Authors of notebooks, Python data artifacts, and data-related skills.
* Reviewers within the SIG who validate reproducibility and conventions.
* Consumers of the Data Science collection who rerun or extend the work.
* SIG Emerging AI as the upstream source of incubating data-science work.
* SIG RAI as a consultant on fairness and evaluation methodology.

## Cross-SIG Dependencies

* **SIG Standards** owns the `python-foundational` and `uv-projects` instructions; SIG Data Science extends these with data-specific conventions and defers to Standards on style.
* **SIG Engineering** owns CI; SIG Data Science requests notebook and Python validators be wired into `lint:py`, `validate:skills`, and related scripts.
* **SIG RAI** consults on fairness, evaluation methodology, and principle alignment for data-driven artifacts.
* **SIG Emerging AI** hands off graduating data-science artifacts; SIG Data Science accepts handoffs that meet the reproducibility floor.
* **SIG Security** consults on data-sensitivity classification and handling.

## Roles and Responsibilities

* **Chairs (1-3):** TBD (external recruit; per the Chair Recruitment Plan, no microsoft/hve-core maintainer may chair). Chairs prioritize the Data Science backlog, run cadence, and represent the SIG in cross-SIG escalations.
* **Tech Leads (1-3):** TBD. Tech leads own architectural direction for notebook and Python conventions, evaluation-harness expectations, and dataset-handling guidance; they mentor reviewers.
* **Reviewers:** TBD. Reviewers validate notebook and Python artifacts against conventions and the reproducibility floor.
* **Members:** TBD. Members contribute PRs, propose convention updates, triage issues, and participate in discussions.

## Subprojects and Owned Directories

* `collections/data-science.collection.*`
* Data-Science-scoped artifacts as introduced under `.github/agents/data-science/`, `.github/instructions/data-science/`, and `.github/skills/data-science/`.

<!--
Initial Membership Suggestions: TBD
-->

## Membership and Onboarding

Joining is open to any contributor in good standing under the [Code of Conduct](../../../../CODE_OF_CONDUCT.md). Prospective members introduce themselves in the SIG: Data Science discussion category and indicate the area of focus (collection curation, notebook conventions, Python conventions, datasets, or evaluation). Reviewer and approver privileges accrue through demonstrated contribution as described in [GOVERNANCE.md](../../../../GOVERNANCE.md).

New-contributor starting points:

* Run `npm run lint:py` and `npm run validate:skills` and propose a small fix or convention extension.
* Audit one notebook in the Data Science collection against the reproducibility floor and file an issue.
* Pair with a tech lead on a review of a recent PR to learn the conventions.

## Cadence

* **Async:** GitHub Discussions category SIG: Data Science for proposals, convention updates, and reviews.
* **Reviews:** PRs touching owned directories receive review acknowledgment within five business days.
* **Optional sync:** Frequency, time zone, and meeting link TBD by the inaugural chair on ratification; meetings are recorded or summarized publicly per the Public Activity rule.

## Decision-Making

* **Lazy consensus** on routine convention and collection updates: 72-hour open window without objection.
* **Chair tie-break** when reviewers disagree within seven days.
* **Escalation** to the maintainer set for charter-affecting changes or cross-SIG conflicts.
* All deliberation occurs in public channels per the Public Activity rule in [GOVERNANCE.md](../../../../GOVERNANCE.md).

## Escalation Path

1. Open a discussion in SIG: Data Science and tag chairs.
2. Chairs triage within five business days.
3. If unresolved, chairs file a decision request to the maintainer set per [GOVERNANCE.md](../../../../GOVERNANCE.md).

## Health and Success Metrics

* Currency of the Data Science collection manifests against the artifacts they reference.
* Notebook and Python artifacts meeting the reproducibility floor on first review.
* Median age of open SIG Data Science PRs.
* Quarterly review cadence completion.
* Number of artifacts graduated from SIG Emerging AI and accepted into the collection.

## Lifecycle and Review

The SIG conducts an annual self-review on or before **Next Review** above. The review reaffirms scope, refreshes goals, updates membership, and either renews or proposes retirement. Retirement requires a maintainer vote per [GOVERNANCE.md](../../../../GOVERNANCE.md) and reassignment of all owned directories.

## Amendment Process

Charter amendments are proposed via pull request. Material changes (scope, role definitions, owned directories) require a 7-day comment window and chair approval; non-material changes follow lazy consensus.

## Code of Conduct

All participants follow the Microsoft Open Source [Code of Conduct](../../../../CODE_OF_CONDUCT.md).

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
