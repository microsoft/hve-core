---
title: Partner Workshop Role Exercises
description: Structured role-based exercises for the HVE partner workshop
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
| 3 | **Scenario framing** | Shared | Initial problem statement |
| 4 | **Role exercises** | Breakout | Context, requirements, experience, architecture inputs |
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
4. After the role tracks, proceed first to the [Partner Workshop solution](partner-workshop-solution.md) guide to integrate the outputs, then continue to the [Partner Workshop Publishing Follow-Up](partner-workshop-publishing) guide for publication readiness.

## Track overview

| Track | Primary objective | Suggested output |
|-------|-------------------|------------------|
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
4. Save the work in the workshop output folder with clear filenames such as 01-context-pack.md, 02-Requirements.md, and 03-experience.md.
5. Share the draft with the next role so the handoff stays clear.
6. If you get stuck, choose the simplest next action: clarify the problem, add one user story, or outline one backlog item.

Across all roles, design for publication of your solution to Microsoft Marketplace and Microsoft 365 Copilot Agent Store. Publishing solutions to the Microsoft Marketplace is one of the fastest ways to scale reach, simplify customer procurement, earn rewards, incentives and GTM benefits, and create recurring revenue opportunities.

Keep your outputs clear enough to support packaging, discovery, and review in both destinations.

## Subject Matter Expert track

### Objective

Capture the business truth before anyone designs or builds anything.

### Steps

1. Create a workshop-output folder and a 01-context-pack.md file. Refer to samples\FSI\01-context-pack.md or samples\Retail\01-context-pack.md.
2. Review the shared scenario and workshop context so your notes stay grounded in the brief.
3. Gather available evidence such as policy documents, SOPs, process diagrams, notes, document references, PDFs, screenshots, and images.
4. Record the problem statement, affected users, and business impact.
5. Separate facts from assumptions, decisions, and open questions.
6. Capture business rules, known failure cases, and AI guardrails.
7. If you need structure, ask **BRD Builder** or **PRD Builder** to turn your notes into a simple outline that the Project Management role can refine. Start by pasting your notes into the agent and ask it to draft a problem statement, business goals, scope, assumptions, and acceptance criteria.
8. Select the context draft and use this prompt in GitHub Copilot Chat: 
```text
"Use the following notes to draft a concise product requirements document for the solution. Create a clear problem statement, business goals, target users, scope, assumptions, constraints, success metrics, and acceptance criteria. Organize the output so it can be used by design, product, and engineering. Include any relevant business rules, known failure cases, and AI guardrails. Update 02-requirements.md."
```
9. When evidence is available, reference supporting documents, PDFs, screenshots, and images as supporting context. Keep the language practical. The result is a simple outline that can be refined into a full PRD.
9. Save the results in a concise context pack for the next roles, including links or references to supporting documents, PDFs, and images when available.

### Deliverable

workshop-output\01-context-pack.md: A context pack that the design and product teams can use to refine the experience and requirements.
workshop-output\02-requirements.md: A requirements draft that can be reviewed by engineering and design.

## Design Track

### Objective

Translate the business context into a clear user experience and shared
understanding of the problem.

### Steps

1. Read the context pack workshop-output\01-context-pack.md created by the SME.
2. Plan for a design thinking [**Microsoft AI Discovery Cards** workshop](https://aka.ms/AIDiscoveryCards) to brainstorm agentic AI capabilities with end users and stakeholders.
3. Select one primary user and one core job to be done.
4. Map the current journey and identify pain points.
5. Describe the future journey with the intended solution.
6. Add accessibility and responsible AI requirements.
7. If you need a first draft, ask **UX UI Designer** to turn the problem into a simple user journey and experience outline. 
Select the 01-context-pack file and use this prompt in GitHub Copilot Chat: 
```text
"Turn these notes into a simple user journey, experience outline, and key pain points for this scenario in 03-experience.md."
```
8. If the team needs a guided conversation, ask **Design Thinking Coach** to help frame the opportunity and challenge assumptions. 
```text
Prompt: "Coach me through a short design thinking session for this scenario. Help me frame the problem, identify user needs, and define a focused opportunity area for the solution."
```
9. If the team needs learning support or a clearer next step, ask **Design Thinking Learning Tutor** to explain the method and help transform notes into a simple design artifact. 
```text
Prompt: "Act as a Design Thinking Learning Tutor. Explain the next design thinking step for this scenario and help me turn my notes into an insight, opportunity statement, or user journey outline."
```
10. Use **Accessibility Planner** and **Accessibility Reviewer** to surface accessibility requirements and review the draft for gaps. 
Select the 03-experience.md and prompt **Accessibility Planner**: 
```text
"Review this experience draft and identify accessibility requirements, user needs, follow-up questions for implementation and update the draft."
```
11. Use **RAI Planner** and **RAI Reviewer** to capture responsible AI requirements, guardrails, and review findings. 
Select the 03-experience.md and **RAI Planner** prompt: 
```text
"Review this experience draft and identify responsible AI requirements, potential harms, mitigation ideas and update the draft."
```
12. If your team uses Figma, include links or references to Figma files, wireframes, and design artifacts in the experience draft. Use Figma outputs as evidence for user flows, screens, and design decisions, and note how those artifacts support the workshop handoff.
13. Identify and validate the use case for publishing to Microsoft 365 Copilot Agent Store. 
Select the 03-experience.md and prompt **UX UI Designer**: 
```text
"How would end users benefit from Microsoft 365 Copilot integrated to this scenario? What research would I need to run to validate it? Update the 03-experience.md."
```
13. Note how the experience should be packaged, discoverable, and reviewable for Microsoft Marketplace and Microsoft 365 Copilot Agent Store.
14. Define success criteria and unresolved questions.
15. Save the results as the 03-experience.md draft.

### Deliverable

workshop-output\03-experience.md: A user experience draft that captures the user path, pain points, and design constraints.

## Project Management track

### Objective

Turn business context and user experience into requirements, priorities, and a backlog draft.

### Steps

1. Review the context pack in workshop-output/01-context-pack.md, workshop-output/02-requirements.md and workshop-output/03-experience.md. Align them to business outcomes, measurable success metrics, functional and non-functional requirements, user stories, acceptance criteria, out-of-scope items, and open assumptions.
2. Create a backlog outline only if it helps the team move from requirements to implementation. If needed, use a lightweight hierarchy such as epic, feature, story, and task for the first MVP. 
3. Prioritize the first MVP with simple labels such as P0, P1, and P2 only if the team needs a sequencing signal. Keep this lightweight and outcome-focused rather than turning it into a rigid Agile process.
4. Prepare the requirements and backlog artifacts for publication readiness in Microsoft Marketplace and Microsoft 365 Copilot Agent Store.
Select the context, requirements, experience and prompt **Functional Planner**: 
```text
"Review the workshop requirements, context pack, and experience draft for the relationship manager scenario. Refine the backlog draft in 05-backlog.md into a more implementation-ready first-slice plan with clear epics, features, stories, and tasks. Then prioritize the first slice with simple labels such as P0, P1, and P2 only if they help the team sequence the work. Also assess whether the backlog and scope are aligned to publication readiness for Microsoft Marketplace and Microsoft 365 Copilot Agent Store, including any requirements that should be captured early for packaging, discoverability, and review readiness. Keep the output concise, outcome-focused, and useful for backlog refinement and implementation."
```
5. If you are targeting GitHub Issues, ask **Backlog Manager** to coordinate the workflow and have GitHub Backlog Executor create the first parent issue and child issues for the initial MVP. The **Backlog Manager** should also ensure the resulting issue links and summary are logged in the workshop output folder for traceability.

Enable writing of GitHub issues:
- Authenticate GitHub CLI
  - Run: gh auth login --web
  - Or, if needed: gh auth refresh -h github.com -s repo
- Verify authentication
  - Run: gh auth status
- Confirm the target repository
  - Run: gh repo set-default [your git clone url]/hve-partner-workshop
- Create GitHub Issues  the backlog creation from a session that exposes GitHub write tools
  - If you are using Copilot or an agent workflow, make sure the session has access to the GitHub MCP write tools.
  - Refer to using [Using the GitHub MCP server from Copilot Chat](https://docs.github.com/en/copilot/how-tos/copilot-on-github/copilot-for-github-tasks/using-the-github-mcp-server-from-copilot-chat)
  - Refer to [Using the GitHub MCP server in your IDE](https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp-in-your-ide/use-the-github-mcp-server)
- Prompt: 
```text
"Review the approved requirements and backlog outline, confirm the target GitHub repository, create the first parent issue and child issues for this initial MVP, and log the issue links and summary in the workshop output folder for traceability. Use labels such as P0, P1, P2, epic, feature, story, and task only if they help the team’s workflow. Update the 05-backlog.md and create the backlog in GitHub Issues."
```
6. Review the issue list for traceability from business outcome to requirement to backlog item, then save the final backlog summary and issue links in your workshop output folder.

### Deliverable

workshop-output\05-backlog.md: A backlog of features, stories or tasks for translating business outcome to trackable work items.

## Technical track

### Objective

Frame the solution approach, architecture, and publication considerations.

### Steps

1. Review the requirements, and experience draft.
2. Identify the core services, data sources, and integration points.
3. Select **System Architecture Reviewer** to help frame a simple solution approach, major tradeoffs, and architecture notes. 
- Note deployment, security, and operational considerations. 
- Review the draft for well-architected design and Cloud Adoption Framework guidance. 
- Capture the publication requirements for Microsoft Marketplace and Microsoft 365 Copilot Agent Store readiness, including packaging, discoverability, supportability, and integration expectations. 
- Create a simple Mermaid architecture diagram for the proposed solution. 
```text
Prompt: "Review the 02-requirements.md and 03-experience.md and help frame a simple solution approach, major tradeoffs, and cloud architecture notes for the first MVP. Update 04-architecture.md. Consider where Microsoft Foundry, Microsoft 365 Copilot, Microsoft Agent 365 Control Plane, Microsoft Entra ID, Microsoft Fabric, Microsoft IQ and Azure Databases fit the solution where appropriate. Review this solution for well-architected design concerns, align the approach to Microsoft Cloud Adoption Framework guidance, and identify any gaps in reliability, security, operational excellence, performance efficiency, and cost optimization for the first MVP. Identify the integration and publication requirements needed to make this solution ready for Microsoft Marketplace and Microsoft 365 Copilot Agent Store, including packaging details, metadata, support expectations, and any required user experience or technical integrations. Create a Mermaid architecture diagram for this solution that shows the main user flow, core services, data sources, and key integrations for the first MVP."
```
4. Use **Security Planner** to review readiness and surface follow-up work. 
```text
Suggested prompt: "Review this solution draft for security risks, deployment considerations, and follow-up actions needed before implementation."
```
5. Review the mermaid diagram and use natural language to refine it.
6. (Optional) Instead of GitHub Copilot, use Microsft 365 Copilot to create an image. In M365 Copilot, attach 04-architecture.md, and create an architecture image from the mermaid diagram for this solution using Azure and Copilot-style icons to represent core services, data sources, user experience layers, and integrations for the first MVP.
```text
Suggested prompt: "Create an architecture image from the mermaid diagram for this solution using Azure and Copilot-style icons to represent core services, data sources, user experience layers, and integrations for the first MVP."
```
7. Create the publication-readiness artifact using the same workshop output folder.
   - Create a new file named `06-publication-readiness.md`.
   - Start with a short summary of the solution, the target user, and the intended publication path.
   - Add a section for solution summary and value proposition.
   - Add a section for product branding, marketing, and positioning, including the customer story and differentiators.
   - Add a section for geographic coverage and launch scope, including target regions, language needs, and any compliance or data residency constraints.
   - Add a section for commercial readiness, including pricing, monetization, billing, taxation, and any Marketplace or agent-store commercial terms.
   - Add a section for a simple Lean Business Canvas summary to capture customer segments, problem, solution, channels, revenue, cost, partners, and differentiators.
   - Add a section for a Partner Center Admin publication checklist for Azure IP Cosell on Marketplace, including publisher setup, offer metadata, legal terms, support contacts, and tax or billing readiness.
   - Add a section for Copilot Agent Store add-on considerations, including any known limits, required tenant approvals, packaging constraints, and whether the agent should be published as a standalone offer or an add-on to an Azure offer.
   - Add a section for user experience and packaging notes, including screenshots, diagrams, and any Microsoft 365 Copilot integration value.
   - Add a section for technical readiness, including core services, integrations, deployment model, and prerequisites.
   - Add a section for security, privacy, and governance, including access controls, data handling, and Responsible AI guardrails.
   - Add a section for support and operations, including ownership, known limitations, and rollout expectations.
   - Add a closing checklist for publication readiness, including the owners and follow-up items that still need attention.
   ```text
   Review the requirements, experience draft, architecture notes, and backlog outline for the relationship manager scenario. Create a concise publication-readiness document in 06-publication-readiness.md that captures the solution summary, target user, value proposition, product branding and marketing notes, geographic coverage and market scope, monetization and taxation considerations, a Lean Business Canvas summary, Partner Center Admin publication checklist for Azure IP Cosell on Marketplace, Copilot Agent Store add-on readiness, user experience and packaging notes, technical readiness, security and privacy considerations, support and operations expectations, and a simple checklist of remaining publication work. Focus on what is needed for Microsoft Marketplace and Microsoft 365 Copilot Agent Store readiness, keep the output practical and workshop-friendly, and identify any owners or follow-up items that still need attention.
   ```
8. Share the output with the rest of the team.

### Deliverable

1. workshop-output\04-architecture.md: A technical draft with architecture notes, risks, and next steps, including a reference to the architecture diagram.

2. workshop-output\06-publication-readiness.md: A concise publication-readiness draft that captures the target route, technical readiness, governance needs, and follow-up work.

## Working session reminder

Keep the output concise and action-oriented. Do not wait for perfect
information. The goal is to produce a reviewed draft that the team can refine after the workshop.

Proceed to the [solution guide](partner-workshop-solution.md).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
