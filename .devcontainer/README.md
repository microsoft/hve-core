---
title: Partner Workshop Role Exercises
description: Step-by-step PM, SME, designer, and technical exercises for the HVE partner workshop
sidebar_position: 9
author: Microsoft
ms.date: 2026-08-11
ms.topic: tutorial
keywords:
  - product manager
  - subject matter expert
  - UX designer
  - architect
  - HVE roles
estimated_reading_time: 15
---

Each role has 35 minutes. Work from the shared scenario, record unknowns, and
produce a concise handoff. Do not wait for perfect information.

## Product Management Track

The PM owns business outcomes, user requirements, prioritization, and backlog
traceability.

1. Open `01-context-pack.md` and read the scenario and SME notes.
2. Select the **Product Manager Advisor** agent.
3. Enter this prompt:

   ```text
   Help me frame the attached scenario for a partner solution. Identify target
   users, jobs to be done, business outcomes, measurable success metrics,
   stakeholders, assumptions, and exclusions. Do not invent market evidence.
   Mark missing information as an open question.
   ```

4. Review the output with the SME.
5. Replace unsupported claims with assumptions or open questions.
6. Select the **BRD Builder** or **PRD Builder** agent.
7. Enter this prompt:

   ```text
   Create a concise workshop requirements draft from the reviewed context.
   Include business outcomes, personas, functional requirements,
   non-functional requirements, data and AI requirements, constraints,
   dependencies, user stories, testable acceptance criteria, and explicit
   out-of-scope items. Assign stable IDs such as BR-01, UR-01, NFR-01, and
   AC-01. Write the reviewed draft to workshop-output/02-requirements.md.
   ```

8. Ask the designer to review user needs and the technical participant to
   review feasibility.
9. Select the **Agile Coach** agent.
10. Enter this prompt:

    ```text
    Convert the requirements in workshop-output/02-requirements.md into a
    backlog draft. Use an Epic > Feature > User Story > Task hierarchy. Include
    requirement IDs, value, acceptance criteria, dependencies, risk, suggested
    priority, and a definition of done. Do not create external work items yet.
    Write the result to workshop-output/05-backlog.md.
    ```

11. Mark the smallest end-to-end customer outcome as the first release slice.
12. Hand `02-requirements.md` and `05-backlog.md` to the team.

## Subject Matter Expert Track

The SME owns domain accuracy. The SME does not need to write code.

1. Open the scenario and list authoritative sources available to the team.
2. Separate facts, assumptions, decisions, and open questions.
3. Select **RPI Agent** and request research-only behavior, or invoke
   `/rpi-research`.
4. Enter this prompt:

   ```text
   Build a domain context pack for this scenario. Use only the supplied sources
   and repository evidence. Capture terminology, actors, current workflow,
   business rules, exceptions, regulatory or policy constraints, data
   sensitivity, source authority, freshness expectations, and unresolved
   questions. Label every statement as fact, assumption, decision, or question.
   Do not implement anything and do not treat model knowledge as customer fact.
   ```

5. Inspect each claimed fact and ask, "What source supports this?"
6. Remove or relabel claims that lack evidence.
7. Add a glossary for terms that engineers or designers could misunderstand.
8. Add at least three exceptional or failure cases.
9. Add content boundaries for the future agent, including what it must refuse,
   escalate, or attribute to a source.
10. Save the reviewed result to `workshop-output/01-context-pack.md`.
11. Ask the PM to link each requirement to a context fact or decision.
12. Ask the technical participant to reflect data classifications and domain
    boundaries in the architecture.

## Design Track

The designer owns the user journey, interaction intent, accessibility, and
human review points.

1. Read `01-context-pack.md` and the PM's draft requirements.
2. Select the **UX UI Designer** agent.
3. Enter this prompt:

   ```text
   Create a Jobs-to-be-Done statement and current-state user journey for the
   primary user in this scenario. Include trigger, steps, pain points, evidence,
   decisions, failure states, escalation paths, and success signals. Distinguish
   known research from assumptions.
   ```

4. Review the journey with the SME.
5. Select the **DT Coach** agent.
6. Enter this prompt:

   ```text
   Using the reviewed journey, define a future experience for an assistant in
   Microsoft 365 Copilot. Include conversation entry points, suggested prompts,
   citations, uncertainty behavior, correction and feedback, authorization
   failures, handoff to a human, and recovery from missing knowledge. Keep this
   as a concept, not a validated user test result.
   ```

7. Add accessibility requirements for keyboard operation, screen reader labels,
   focus order, clear error recovery, non-color status cues, and plain language.
8. Add responsible AI experience requirements for disclosure, citations,
   uncertainty, feedback, and human escalation.
9. Define three prototype tasks and observable success criteria.
10. Save the reviewed result to `workshop-output/03-experience.md`.
11. Ask the PM to convert experience needs into requirement IDs.
12. Ask the technical participant to map each interaction to an API, identity,
    data, or monitoring capability.

## Technical Track

The technical role owns feasibility, Azure boundaries, security assumptions,
and publication prerequisites. Architecture generation is a draft, not an Azure
deployment.

1. Read the context, requirements, and experience drafts.
2. Select **System Architecture Reviewer**.
3. Enter this prompt:

   ```text
   Propose an Azure architecture for this scenario. Map every component to a
   requirement. Cover user and workload identity, Microsoft 365 agent entry,
   API or orchestration, approved content ingestion, grounded retrieval, model
   access, secrets, private networking where required, telemetry, audit, data
   lifecycle, regional availability, cost drivers, and failure handling.
   Identify alternatives and unresolved decisions. Do not deploy resources.
   ```

4. Review service names, data flows, trust boundaries, and tenant boundaries.
5. Remove components that do not satisfy a requirement.
6. Invoke the **architecture-diagrams** skill.
7. Enter this prompt:

   ```text
   Generate a Mermaid Azure architecture diagram from the reviewed design.
   Show the Microsoft 365 user and agent, customer tenant boundary, customer
   Azure subscription, application resource group, managed resource group,
   identity, ingress, application or orchestration, model, search, storage,
   Key Vault, and monitoring. Label data flows and trust boundaries. Include a
   legend, key relationships, assumptions, and requirement IDs. Write the
   reviewed result to workshop-output/04-azure-architecture.md.
   ```

8. Confirm the Mermaid preview renders.
9. Choose and record a Managed Application permission scenario: publisher
   managed, publisher and customer access, locked mode, or customer managed.
10. Record why that permission model is appropriate and who approves it.
11. List the expected Managed Application package files:
    `mainTemplate.json` and `createUiDefinition.json` at the root of `app.zip`.
12. List validation, security, cost, support, and operational readiness gates.
13. Add the proposed Microsoft 365 agent implementation route: Agents Toolkit,
    Copilot Studio, or Microsoft 365 Copilot Agent Builder.
14. Save unresolved decisions and prerequisites in
    `workshop-output/06-publication-readiness.md`.

Proceed to the [cross-role capstone](partner-workshop-capstone).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
