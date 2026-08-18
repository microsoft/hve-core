---
title: "Traceability Matrix"
description: "Traceability review for the FSI relationship manager"
sidebar_position: 7
author: Microsoft
ms.date: 2026-08-17
ms.topic: reference
keywords:
  - traceability
  - workshop
  - relationship manager
  - publication readiness
estimated_reading_time: 5
---

## Traceability matrix draft

This draft links the workshop scenario context and decisions to requirements, experience needs, architecture components, backlog items, test ideas, and publication gates.

| Source fact or decision                                                                         | Requirement or need                | Experience need                                                        | Architecture component                               | Backlog item                        | Test or review check                                                                       | Publication gate                              |
|-------------------------------------------------------------------------------------------------|------------------------------------|------------------------------------------------------------------------|------------------------------------------------------|-------------------------------------|--------------------------------------------------------------------------------------------|-----------------------------------------------|
| Relationship managers work from fragmented CRM, email, call, transaction, and knowledge sources | FR-01, FR-02, FR-05                | Show a unified account view and prioritized next actions               | Retrieval and grounding layer, orchestration service | FEAT-01, STORY-01                   | Verify that the first screen presents consolidated context and a clear next action         | Technical readiness, data access, packaging   |
| The experience must support explainable recommendations                                         | FR-03, FR-05, DAI-02               | Show visible evidence, reasoning, and confidence labels                | Insight and recommendation service, governance layer | FEAT-02, STORY-03                   | Validate that each recommendation includes evidence and rationale                          | Responsible AI, trust, and reviewability      |
| Human review is required before operational action                                              | DAI-03, NFR-01                     | Provide approve, defer, and escalate choices                           | Action tracking service, governance layer            | FEAT-03, STORY-03                   | Verify that the workflow supports human decision points before action                      | Security, privacy, review controls            |
| The solution must avoid production credentials, personal data, and sensitive content            | C-01, C-02, NFR-03                 | Keep the sample experience safe and workshop-friendly                  | Identity and permissions service, governance layer   | FEAT-01, TASK-01                    | Confirm that no secrets or production data appear in the sample environment                | Privacy, compliance, and data handling        |
| The primary user is the relationship manager preparing for a customer conversation              | PR-01, BR-01, BR-03                | Support rapid preparation and follow-up during live customer workflows | Experience layer, account workspace UI               | FEAT-01, STORY-01                   | Validate that the account view supports fast preparation and action capture                | User value and marketplace fit                |
| Secondary users include team leads, account owners, and reviewers                               | PR-02, PR-03                       | Support prioritization, review, and oversight                          | Experience layer, governance layer                   | FEAT-02, STORY-02                   | Verify that reviewers can understand the evidence and the chosen next action               | Governance and support readiness              |
| The first MVP should remain scenario-specific and human-reviewable                              | C-03, NFR-04                       | Keep the experience clear, concise, and reviewable                     | Experience layer, orchestration service              | FEAT-01, FEAT-02                    | Review the first-slice scope for clarity and workshop fit                                  | Packaging and launch scope                    |
| The solution should be publishable later through Marketplace and Copilot Agent Store            | Publication readiness requirements | Provide clear value, evidence, and packaging assets                    | Publish Readiness and support layers                 | Publication readiness backlog items | Review whether the solution has the required metadata, screenshots, support, and approvals | Marketplace and Agent Store publication gates |

## Missing links and gaps

* The sample backlog should explicitly link each story to the related requirement IDs and the publication gate that depends on it.
* The architecture draft should reference the exact evidence and review controls that support each recommendation.
* The publication readiness draft should capture owner names for each remaining gate, especially privacy, support, tax, and offer packaging.
* The workshop output should identify which test or validation activity will prove each requirement before implementation begins.

## Suggested review questions

* Which facts or decisions are still unsupported by evidence?
* Which requirements have no clear owner or no mapped backlog item?
* Which publication gates remain unowned or uncertain?
* Which risks need a human decision before the team can proceed to implementation?

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
