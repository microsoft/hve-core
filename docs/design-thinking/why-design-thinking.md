---
title: Why Design Thinking?
description: Understanding when and why to use Design Thinking in your projects
author: Microsoft
ms.date: 2026-02-25
ms.topic: concept
keywords:
  - design thinking
  - user-centered design
  - methodology
estimated_reading_time: 4
---

Teams build features that users never asked for. Requirements documents capture what stakeholders say they want, not what they actually need. The gap between stated requirements and real needs is where projects fail, not in the code, but in the understanding.

Design Thinking closes that gap by placing human needs at the center of every decision.

## When to Use Design Thinking

Not every task needs Design Thinking. Use it when:

* Requirements are unclear, where stakeholders describe solutions ("build me a dashboard") rather than problems ("I can't tell which machines need maintenance").
* Multiple stakeholders disagree, and different groups have conflicting needs that require synthesis.
* The problem is complex, with solutions that span organizational boundaries, user roles, or technical systems.
* User adoption matters, since the deliverable only succeeds if people actually use it.

For well-understood tasks with clear specifications, jump straight to [RPI](../rpi/README.md).

## The Three-Space Model

Design Thinking organizes work into three spaces, each with distinct goals and quality expectations.

Problem Space (Methods 1-3) focuses on understanding who you are solving for and what they need. Explore broadly. Outputs are rough, not polished.

Solution Space (Methods 4-6) generates and tests ideas at low fidelity. The goal is learning, not building. Scrappy prototypes beat polished mockups because they invite honest feedback.

Validation Space (Methods 7-9) builds functional prototypes, tests with real users, and refines based on evidence. Quality becomes functionally rigorous, though visual polish remains secondary to correctness.

> [!IMPORTANT]
> Each space has a deliberate quality standard. Producing polished output in the Problem Space or Solution Space wastes effort and discourages honest criticism. Rough artifacts invite better feedback.

## DT vs Traditional Requirements Gathering

| Aspect                  | Traditional Requirements     | Design Thinking                           |
|-------------------------|------------------------------|-------------------------------------------|
| Starting point          | Stakeholder wish list        | Observed user behavior and needs          |
| Evidence basis          | Stated preferences           | Multi-source research and observation     |
| Validation timing       | After implementation         | Continuously, at every space transition   |
| Prototype fidelity      | High-fidelity from the start | Lowest fidelity that tests the hypothesis |
| Stakeholder involvement | Beginning and end            | Throughout the process                    |
| Handling disagreement   | Escalation or compromise     | Synthesis through shared observation      |
| Output                  | Requirements document        | Validated problem statement + prototypes  |

## Relationship with RPI

Design Thinking and RPI are complementary, not competing.

Design Thinking answers **what to build and why**. RPI answers **how to build it correctly**.

When a Design Thinking session reaches a natural exit point, the DT Coach prepares a structured handoff artifact containing validated findings, confidence markers, and stakeholder maps. This artifact feeds directly into the RPI pipeline:

* Problem Statement Complete (after Methods 1-3): Task Researcher uses validated problem framing to scope technical research.
* Concept Validated (after Methods 4-6): Task Planner uses stakeholder-validated concepts to create implementation plans.
* Implementation Spec Ready (after Methods 7-9): Task Researcher uses functionally rigorous specifications for focused technical investigation.

See [DT to RPI Integration](dt-rpi-integration.md) for the full handoff protocol.

## Industry Applicability

Design Thinking applies across domains. The DT Coach supports industry-specific context templates that adjust vocabulary, constraints, and stakeholder archetypes:

* Manufacturing covers factory floor improvement, production optimization, and safety workflows.
* Healthcare covers clinical workflows, patient experience, and regulatory compliance.
* Energy covers grid operations, safety protocols, and field worker tools.

Industry context shapes the coaching conversation without changing the underlying method structure.

## Getting Started

Start with the [DT Coach](dt-coach.md) to run your first guided session. The coach adapts to your experience level and guides you through each method at a pace that works for your team.

> Brought to you by microsoft/hve-core

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
