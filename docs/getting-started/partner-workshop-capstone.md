---
title: Partner Workshop Capstone
description: Integrate role outputs into a requirements pack, backlog, Azure diagram, and publication readiness plan
sidebar_position: 10
author: Microsoft
ms.date: 2026-08-11
ms.topic: tutorial
keywords:
  - workshop capstone
  - backlog
  - requirements traceability
  - Azure diagram
  - publication readiness
estimated_reading_time: 8
---

The capstone uses 40 minutes of the two-hour session: 25 minutes to integrate
role outputs and 15 minutes to assess publication readiness.

## Integrate The Artifacts

1. Ask each role to summarize its artifact in two minutes.
2. Open all six files in `workshop-output`.
3. Compare terminology across the files.
4. Use the SME glossary as the source for domain terms.
5. Resolve contradictory assumptions or mark them as open decisions.
6. Confirm every user story identifies a user, need, and outcome.
7. Confirm every acceptance criterion is observable and testable.
8. Confirm every architecture component maps to at least one requirement.
9. Confirm every high-risk requirement maps to a backlog item.
10. Confirm the experience includes citations, uncertainty, feedback, access
    failures, and human escalation.

## Run A Traceability Review

Select **RPI Agent** and enter this prompt:

```text
Review workshop-output/01-context-pack.md through
workshop-output/06-publication-readiness.md as one solution pack. Build a
traceability matrix from context facts and decisions to requirements, user
experience needs, Azure components, backlog items, tests, and publication
gates. Report missing links, contradictions, unsupported claims, and unowned
risks. Do not implement or publish anything.
```

Then complete these steps:

1. Assign an owner to each gap.
2. Fix gaps that can be resolved from workshop evidence.
3. Record remaining gaps in `06-publication-readiness.md`.
4. Mark generated content as draft until a responsible human reviews it.

## Prepare The Backlog Target

Choose one target. Creating external items is optional during the workshop.

### GitHub Issues

1. Select **GitHub Backlog Manager**.
2. Ask it to inspect `05-backlog.md` for readiness and duplicates.
3. Confirm repository, labels, milestone, owners, and issue hierarchy.
4. Ask for a dry-run summary before any mutation.
5. Review the proposed issue titles and acceptance criteria.
6. Create issues only with facilitator approval and repository permission.

### Azure DevOps Boards

1. Select **AzDO PRD to WIT**.
2. Ask it to inspect `02-requirements.md` and `05-backlog.md`.
3. Confirm organization, project, area path, iteration, work item types, and
   parent-child hierarchy.
4. Ask for a planning handoff without creating work items.
5. Review the handoff with the PM and technical role.
6. Create work items only after authentication, field validation, and
   facilitator approval.

### Markdown-Only Fallback

1. Keep `05-backlog.md` as the system-neutral backlog.
2. Add columns for target system, owner, state, and external ID.
3. Assign a post-workshop owner to import or create each approved item.

## Review The Azure Architecture

1. Render `04-azure-architecture.md` in Markdown Preview.
2. Follow the primary user request from Microsoft 365 Copilot to the Azure API,
   retrieval layer, model, and response.
3. Follow the content ingestion and update path separately.
4. Identify where authorization is enforced.
5. Identify where secrets and keys are stored.
6. Identify where prompts, retrieved content, responses, and feedback could be
   logged.
7. Confirm telemetry does not collect secrets or unnecessary personal data.
8. Add failure paths for model, search, identity, and dependency outages.
9. Add a cost owner and operational owner.
10. Mark the diagram as conceptual until infrastructure source and deployment
    validation exist.

## Create The Follow-Up Plan

1. Open `06-publication-readiness.md`.
2. Add separate sections for Azure Managed Application and Microsoft 365 agent.
3. Record required accounts, subscriptions, tenants, roles, and approvers.
4. Record security, privacy, accessibility, legal, support, and Responsible AI
   reviews.
5. Record test environments and preview audiences.
6. Record listing content, icons, screenshots, privacy links, support links, and
   terms that still need owners.
7. Assign target dates outside the workshop.
8. Continue with the
   [publication instructions](partner-workshop-publishing).

## Ten-Minute Playback

1. PM presents the outcome, requirements, and first release slice.
2. SME presents key constraints and unresolved domain questions.
3. Designer presents the primary journey and human review points.
4. Technical lead presents the Azure diagram and publication routes.
5. The team names its three highest risks.
6. The facilitator confirms owners and the next review date.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
