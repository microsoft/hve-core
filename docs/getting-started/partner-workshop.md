---
title: HVE Partner Workshop
description: Workshop for partners to create requirements, context, a backlog, Azure architecture, and publication plans with HVE Core
sidebar_position: 7
author: Microsoft
ms.date: 2026-08-17
ms.topic: tutorial
keywords:
  - partner workshop
  - HVE Core
  - role-based learning
  - Azure architecture
  - Microsoft Marketplace
  - Copilot Agent Store
estimated_reading_time: 8
---

Use this workshop to move a product idea to a connected set of delivery artifacts. Participants work in one shared project, split into role tracks, and then combine their outputs into a requirements pack, prioritized backlog, Azure architecture, and publication readiness plan.

The workshop teaches a repeatable workflow. It does not compress production security review, Azure deployment, or Microsoft Marketplace certification into a day.

## Outcomes

By the end of the facilitated session, the team can:

* give HVE Core grounded business, user, domain, design, and technical context
* create business and user requirements with testable acceptance criteria
* convert requirements into a prioritized GitHub or Azure DevOps backlog draft
* generate and review a Mermaid architecture diagram for an Azure solution
* explain the steps and approval gates for an Azure Managed Application offer on Microsoft Marketplace
* explain the supported routes to the Microsoft 365 Copilot Agent Store

The team should leave with these draft artifacts:

```text
workshop-output/
|-- 01-context-pack.md
|-- 02-requirements.md
|-- 03-experience.md
|-- 04-architecture.md
|-- 05-backlog.md
`-- 06-publication-readiness.md
```

| Outcome                       | Complete In Workshop                  | Continue After Workshop                                |
|-------------------------------|---------------------------------------|--------------------------------------------------------|
| Context and user requirements | Reviewed draft                        | Customer validation and approval                       |
| Backlog                       | Prioritized draft or planning handoff | Create approved external work items                    |
| Architecture Design           | Reviewed conceptual Mermaid diagram   | Implement and validate infrastructure                  |
| Azure Managed Application     | Package and offer readiness plan      | Build, test, certify, and publish offer on Marketplace |
| Microsoft 365 Copilot Agent   | Experience and distribution plan      | Build, test, approve, and publish agent                |

> [!IMPORTANT]
> HVE Core custom agents run in GitHub Copilot and VS Code. They are not
> Microsoft 365 Copilot agents and cannot be uploaded directly to the Agent
> Store. The team should build the customer-facing agent with a supported
> Microsoft 365 agent tool, package it, validate it, and follow the applicable
> organizational catalog or Partner Center publishing route.

## Audience And Roles

Form multidisciplinary teams of four to six people.

| Track                 | Suggested Participants                                                 | Primary Workshop Output                                                 |
|-----------------------|------------------------------------------------------------------------|-------------------------------------------------------------------------|
| Project Management    | PM, Program manager, Product owner                                     | Outcomes, requirements, priorities, backlog structure                   |
| Subject Matter Expert | Industry SME, Compliance Lead, Operations Lead                         | Domain context, terminology, constraints, evidence                      |
| Design                | UX Designer, Service Designer, Design Thinking Facilitator, Researcher | Personas, User Journey, Accessibility, Responsible AI, Agent experience |
| Technical             | Architect, Forward Deployed Engineer, Security, Platform Lead          | Azure design, diagram, deployment and publication plan                  |

Review the broader [HVE role guides](../hve-guide/roles/) after the workshop for ongoing role-specific workflows.

## Workshop Agenda

| Item | Activity                           | Mode     | Output                                                 |
|------|------------------------------------|----------|--------------------------------------------------------|
| 1    | HVE and RPI overview               | Shared   | Common vocabulary and scenario                         |
| 2    | Environment setup and verification | Shared   | Working HVE Core All installation                      |
| 3    | Scenario framing                   | Shared   | Initial problem statement                              |
| 4    | Role exercises                     | Breakout | Context, requirements, experience, architecture inputs |
| 5    | Artifact integration               | Shared   | Requirements, backlog, and Azure diagram               |
| 6    | Publication readiness              | Shared   | Managed App and Agent Store checklists                 |
| 7    | Playback and next actions          | Shared   | Owners, gaps, and follow-up plan                       |

## Facilitator Preparation

Complete these steps before participants arrive:

1. Ensure the workshop repository can be accessed by every participant.
2. Enable GitHub Codespaces for the repository or confirm participants can clone it locally.
3. Confirm participants have GitHub Copilot access.
4. Ask participants to install **HVE Core All**, not HVE Core and HVE Installer together.
5. Create a new branch for each team or a disposable workshop repository.
6. Choose whether the backlog target is GitHub Issues or Azure DevOps Boards.
7. Confirm access to the target backlog before the session. If access is not available, use a Markdown backlog draft.
8. Prepare a scenario or use the sample below.
9. If access and approvals to Microsoft Marketplace or Azure subscriptions do not exist, keep them as demonstrations.

### Sample Scenario

Use this scenario when participants do not bring a project:

> A partner wants to offer a Service Knowledge Assistant to enterprise
> customers. Support specialists ask questions in Microsoft 365 Copilot and
> receive grounded answers from approved product and service documents. Each
> customer deploys the Azure data, search, model, API, identity, and monitoring
> resources into its own subscription through an Azure Managed Application.
> The solution must preserve source citations, respect user access, avoid using
> customer content for model training, and provide operational audit evidence.

Do not use production customer data during the workshop. Use synthetic or public sample content.

## Participant Flow

1. Complete [shared setup](partner-workshop-setup.md).
2. Choose a section in the [role guide](partner-workshop-role-tracks.md).
3. Complete the [cross-role solution guide](partner-workshop-solution.md).
4. Complete the [publication guide](partner-workshop-publishing.md) during the workshop and finish it after the session.

## Completion Standard

The workshop is complete when the team has reviewed the six draft artifacts, identified unresolved assumptions, and assigned owners for publication follow-up. Actual Azure deployment, commercial Microsoft Marketplace validation, and Copilot Agent Store availability are post-workshop milestones unless the facilitator explicitly provides extra time and project managers have authorized environments.

## Related Guidance

* [Installing HVE Core](install.md)
* [Your First Full Workflow](first-workflow.md)
* [Architecture Diagrams Skill](../agents/project-planning/arch-diagram-builder.md)
* [MCP Configuration](mcp-configuration.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
