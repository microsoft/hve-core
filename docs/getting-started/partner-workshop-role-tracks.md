---
title: Partner Workshop Role Guide
description: Structured role-based guide for the HVE partner workshop
sidebar_position: 9
author: Microsoft
ms.date: 2026-08-17
ms.topic: tutorial
keywords:
  - Project Manager
  - Subject Matter Expert
  - UX Designer
  - Engineer
  - HVE roles
estimated_reading_time: 10
---

## Workshop Agenda

| Item | Activity | Mode | Output |
|------|----------|------|--------|
| 1 | HVE and RPI overview | Shared | Common vocabulary and scenario |
| 2 | Environment setup and verification | Shared | Working HVE Core All installation |
| 3 | Scenario framing | Shared | Initial problem statement |
| 4 | Role exercises | Breakout | Context, requirements, experience, architecture inputs |
| 5 | Artifact integration | Shared | Requirements, backlog, and Azure diagram |
| 6 | Publication readiness | Shared | Managed App and Agent Store checklists |
| 7 | Playback and next actions | Shared | Owners, gaps, and follow-up plan |

Use this guide during the role-exercise portion of the workshop. Participants should work from the same scenario, capture assumptions, and leave with a handoff that the next role can use.

## Suggested role order

A practical sequence for the workshop is:

1. Subject Matter Expert creates the shared context pack.
2. Project Management turns the draft into requirements, priorities, and backlog structure.
3. Design translates that context into an experience draft and captures accessibility and responsible AI needs.
4. Technical frames the solution approach, architecture, and publication considerations.
5. The team reviews the handoff together during the solution integration step.

This sequence helps each role build on the previous one without waiting for perfect information.

## HVE vs Agile

| Agile | HVE |
|-------|-----|
| Sprint-first and feature-first | Outcome-first and value-first |
| Backlog refinement often drives delivery | Shared context and AI-assisted planning drive delivery |
| Teams often interpret requirements separately | Humans and agents work from the same context and evidence |
| Large feature sets can be explored too early | Small outcome slices help teams learn quickly |

## Workshop flow

1. Review the shared scenario and workshop context.
2. Choose a role track and complete its guided steps.
3. Share your artifact with the rest of the team.
4. After the role tracks, proceed first to the [Partner Workshop solution](partner-workshop-solution.md) guide to integrate the outputs, then continue to the [Partner Workshop Publishing Follow-Up](partner-workshop-publishing.md) guide for publication readiness.

## Track overview

| Track | Primary objective | Suggested output |
|-------|------------------|------------------|
| Project Management | Turn context into requirements, priorities, and backlog structure | Requirements draft and backlog outline |
| Subject Matter Expert | Capture business facts, rules, constraints, and evidence | Context pack |
| Design | Express the user experience, pain points, and success criteria | Experience draft |
| Technical | Frame the solution, architecture, and deployment considerations | Architecture and publication notes |

## HVE Agent Guide

Use the HVE agents as lightweight helpers for your role. Start with your own draft, then ask an agent to refine or structure it.

* **BRD Builder** or **PRD Builder** for first-draft requirements and a simple structure for business outcomes, scope, and acceptance criteria. In this workshop, the Project Management role should typically own the BRD/PRD draft, while the Subject Matter Expert provides the business context, evidence, and constraints that inform it.
* **Functional Planner** for turning a draft requirement into a lightweight epic, feature, story, and task hierarchy when the team needs a delivery handoff.
* **UX UI Designer** for user journeys, pain points, wireframe outline, and experience artifacts.
* **Design Thinking Coach** for facilitation and discovery.
* **Design Thinking Learning Tutor** for guided learning and method support.
* **Accessibility Planner** for accessibility requirements and inclusive design considerations.
* **Accessibility Reviewer** for a review pass on accessibility readiness.
* **RAI Planner** for responsible AI requirements, risks, and guardrails.
* **RAI Reviewer** for a responsible AI review pass.
* **System Architecture Reviewer** for framing a simple solution approach, tradeoffs, and architecture notes.
* **GitHub Backlog Executor** for creating or updating GitHub Issues after the backlog is reviewed.
* **Security Planner** for additional review, risk checks, and readiness considerations.

### Getting Started Guide

1. Start with a plain-language draft for your role instead of trying to make it perfect.
2. Pick one HVE agent that matches your role and ask for a simple first draft.
3. Review the draft, adjust it with your own notes, and keep the language concrete.
4. Save the work in the workshop output folder with clear filenames such as `01-context-pack.md`, `02-requirements.md`, and `03-experience.md`.
5. Share the draft with the next role so the handoff stays clear.
6. If you get stuck, choose the simplest next action: clarify the problem, add one user story, or outline one backlog item.

Across all roles, design for publication of your solution to Microsoft Marketplace and Microsoft 365 Copilot Agent Store. Publishing solutions to the Microsoft Marketplace is one of the fastest ways to scale reach, simplify customer procurement, and create recurring revenue opportunities.

Keep your outputs clear enough to support packaging, discovery, and review in both destinations.

## Subject Matter Expert track

### Objective

Capture the business truth before anyone designs or builds anything.

### Steps

1. Create a `workshop-output` folder and a `01-context-pack.md` file. Refer to sample files such as `samples/FSI/01-context-pack.md` or `samples/Retail/01-context-pack.md`.
2. Review the shared scenario and workshop context so your notes stay grounded in the brief.
3. Gather available evidence such as policy documents, SOPs, process diagrams, notes, document references, PDFs, screenshots, and images.
4. Record the problem statement, affected users, and business impact.
5. Separate facts from assumptions, decisions, and open questions.
6. Capture business rules, known failure cases, and AI guardrails.
7. Ask **BRD Builder** or **PRD Builder** to turn your notes into a simple outline that the Project Management role can refine.
8. Select the context draft and use this prompt in GitHub Copilot Chat:

```text
"Use the following notes to draft a concise product requirements document for the solution. Create a clear problem statement, business goals, target users, scope, assumptions, constraints, success metrics, and acceptance criteria. Organize the output so it can be used by design, product, and engineering. Include any relevant business rules, known failure cases, and AI guardrails. Update 02-requirements.md."
```

### Deliverable

1. `workshop-output/01-context-pack.md`: A context pack that the design and product teams can use to refine the experience and requirements.
2. `workshop-output/02-requirements.md`: A requirements draft that can be reviewed by engineering and design.

## Design Track

### Objective

Translate the business context into a clear user experience and shared understanding of the problem.

### Steps

1. Read the context pack in `workshop-output/01-context-pack.md` created by the SME.
2. Plan for a design thinking workshop to brainstorm AI capabilities with end users and stakeholders.
3. Select one primary user and one core job to be done.
4. Map the current journey and identify pain points.
5. Describe the future journey with the intended solution.
6. Add accessibility and responsible AI requirements.
7. Use **UX UI Designer** to turn the problem into a simple user journey and experience outline.
8. Use **Design Thinking Coach** or **Design Thinking Learning Tutor** to guide the flow when needed.
9. Use **Accessibility Planner** and **Accessibility Reviewer** to surface accessibility requirements and review the draft for gaps.
10. Use **RAI Planner** and **RAI Reviewer** to capture responsible AI requirements, guardrails, and review findings.
11. Save the results as `workshop-output/03-experience.md`.

### Deliverable

`workshop-output/03-experience.md`: A user experience draft that captures the user path, pain points, and design constraints.

## Project Management track

### Objective

Turn business context and user experience into requirements, priorities, and a backlog draft.

### Steps

1. Review the context pack and the requirements and experience drafts.
2. Create a backlog outline only if it helps the team move from requirements to implementation.
3. Prioritize the first MVP with simple labels such as P0, P1, and P2 only if the team needs a sequencing signal.
4. Prepare the requirements and backlog artifacts for publication readiness in Microsoft Marketplace and Microsoft 365 Copilot Agent Store.
5. If you are targeting GitHub Issues, ask **Backlog Manager** to coordinate the workflow and have **GitHub Backlog Executor** create the first parent issue and child issues for the initial MVP.

### Deliverable

`workshop-output/05-backlog.md`: A backlog of features, stories, and tasks for translating business outcome to trackable work items.

## Technical track

### Objective

Frame the solution approach, architecture, and publication considerations.

### Steps

1. Review the requirements and experience draft.
2. Identify the core services, data sources, and integration points.
3. Select **System Architecture Reviewer** to help frame a simple solution approach, major tradeoffs, and architecture notes.
4. Use **Security Planner** to review readiness and surface follow-up work.
5. Create the publication-readiness artifact in `workshop-output/06-publication-readiness.md`.

### Deliverable

1. `workshop-output/04-architecture.md`: A technical draft with architecture notes, risks, and next steps.
2. `workshop-output/06-publication-readiness.md`: A concise publication-readiness draft that captures the target route, technical readiness, governance needs, and follow-up work.

## Working session reminder

Keep the output concise and action-oriented. Do not wait for perfect information. The goal is to produce a reviewed draft that the team can refine after the workshop.

Proceed to the [solution guide](partner-workshop-solution.md).

---
