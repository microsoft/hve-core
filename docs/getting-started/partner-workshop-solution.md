---
title: Partner Workshop solution
description: Integrate role outputs into a shared solution pack, backlog, architecture view, and publication-readiness plan
sidebar_position: 10
author: Microsoft
ms.date: 2026-08-17
ms.topic: tutorial
keywords:
  - workshop solution
  - backlog
  - requirements traceability
  - Azure diagram
  - publication readiness
estimated_reading_time: 8
---

## Workshop Agenda

| Item | Activity | Mode | Output |
|------|----------|------|--------|
| 1 | HVE and RPI overview | Shared | Common vocabulary and scenario |
| 2 | Environment setup and verification | Shared | Working HVE Core All installation |
| 3 | Scenario framing | Shared | Initial problem statement |
| 4 | Role exercises | Breakout | Context, requirements, experience, architecture inputs |
| 5 | **Artifact integration** | Shared | Requirements, backlog, and Azure diagram |
| 6 | Publication readiness | Shared | Managed App and Agent Store checklists |
| 7 | Playback and next actions | Shared | Owners, gaps, and follow-up plan |

Use this guide during the solution portion of the workshop. Participants should bring their role outputs together, check for gaps and traceability, and leave with a reviewed handoff that can be refined after the session.

## Objective

Create one shared solution draft that connects business context, requirements, experience, backlog, architecture, and publication readiness into a coherent story.

## Suggested solution flow

1. Ask each role to summarize its artifact in two minutes.
2. Open the workshop output files in the shared folder.
3. Compare terminology across the files and resolve contradictions.
4. Use the SME context pack as the source of truth for domain terms and business rules.
5. Confirm that each user story identifies a user, need, and outcome.
6. Confirm that each acceptance criterion is observable and testable.
7. Confirm that each architecture component maps to at least one requirement.
8. Confirm that high-risk requirements and important decisions map to backlog items.
9. Confirm that the experience captures uncertainty, feedback, access failures, and human escalation.
10. Record unresolved items as follow-up work in 06-publication-readiness.md.

## Traceability review

Select **RPI Planner** and enter this prompt:

```text
"Review the workshop output set from 01-context-pack.md through 06-publication-readiness as one solution pack. Build a traceability matrix from context facts and decisions to requirements, experience needs, architecture components, backlog items, tests, and publication gates. Report missing links, contradictions, unsupported claims, and unowned risks. Do not implement or publish anything."
```

Then complete these steps:

1. Capture the matrix draft in 07-traceability-matrix.md
2. Assign an owner to each gap.
3. Fix gaps that can be resolved from workshop evidence.
4. Record remaining gaps in 06-publication-readiness.md
5. Mark generated content as draft until a responsible human reviews it.

## Prepare the backlog target

Choose one target. Creating external items is optional during the workshop.

### GitHub Issues

1. Select **Backlog Manager**.
2. Ask it to inspect 05-backlog.md for readiness and duplicates.
3. Confirm repository, labels, milestone, owners, and issue hierarchy.
4. Ask for a dry-run summary before any mutation.
5. Review the proposed issue titles and acceptance criteria.
6. Create issues only with facilitator approval and repository permission.

### Markdown-only fallback

1. Keep 05-backlog.md as the system-neutral backlog.
2. Add columns for target system, owner, state, and external ID.
3. Assign a post-workshop owner to import or create each approved item.

## Review the architecture

1. Open 04-architecture.md in Markdown Preview.
2. Follow the primary user request from Microsoft 365 Copilot to the Azure API, retrieval layer, model, and response path.
3. Follow the content ingestion and update path separately.
4. Identify where authorization is enforced.
5. Identify where secrets and keys are stored.
6. Identify where prompts, retrieved content, responses, and feedback could be logged.
7. Confirm telemetry does not collect secrets or unnecessary personal data.
8. Add failure paths for model, search, identity, and dependency outages.
9. Add a cost owner and an operational owner.
10. Mark the diagram as conceptual until infrastructure source and deployment validation exist.

## Create the follow-up plan

1. Open 06-publication-readiness.md
2. Add separate sections for Azure Managed Application and Microsoft 365 agent.
3. Record required accounts, subscriptions, tenants, roles, and approvers.
4. Record security, privacy, accessibility, legal, support, and Responsible AI reviews.
5. Record test environments and preview audiences.
6. Record listing content, icons, screenshots, privacy links, support links, and terms that still need owners.
7. Assign target dates outside the workshop.
8. Continue with the [publication guide](partner-workshop-publishing.md).

## Ten-minute team discussion

1. The PM presents the outcome, requirements, and first release slice.
2. The SME presents key constraints and unresolved domain questions.
3. The designer presents the primary journey and human review points.
4. The technical lead presents the architecture view and publication routes.
5. The team names its three highest risks.
6. The facilitator confirms owners and the next review date.

## Deliverable

A reviewed workshop handoff that connects context, requirements, experience, backlog, architecture, and publication readiness into one shared draft.

## Working session reminder

Keep the output concise and action-oriented. Do not wait for perfect information. The goal is to produce a reviewed draft that the team can refine after the workshop.

Proceed to the [publishing guide](partner-workshop-publishing.md).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
