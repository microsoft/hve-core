---
title: RAI Planning
description: Structured Responsible AI assessment through a 6-phase conversational workflow aligned with Microsoft RAI Standard v2 and NIST AI RMF 1.0
sidebar_position: 1
sidebar_label: Overview
keywords:
  - responsible AI
  - RAI planner
  - NIST AI RMF
  - Microsoft RAI Standard
  - AI risk assessment
  - sensitive uses
tags:
  - agents
  - rai-planning
author: Microsoft
ms.date: 2026-03-11
ms.topic: concept
estimated_reading_time: 8
---

> Responsible AI assessment should be as structured and repeatable as security planning.
> When every AI system goes through the same principled evaluation, risk coverage improves,
> stakeholder trust increases, and compliance gaps surface before they become costly.

## Why Use RAI Planning?

The RAI Planner agent transforms informal AI ethics reviews into a repeatable, evidence-backed assessment:

* 🔍 **Systematic coverage** evaluates each AI component against six RAI principles and seven threat categories, eliminating the guesswork of ad-hoc reviews
* 📊 **Quantified outcomes** produce a scored RAI scorecard across five dimensions so stakeholders can compare assessment quality across projects
* 🔗 **Security plan integration** picks up where the Security Planner leaves off, inheriting AI component data and continuing threat ID sequences without duplication

> [!TIP]
> If you have already completed a security plan, the `from-security-plan` entry mode is recommended. It pre-populates AI system scope from the security plan's `state.json` and starts RAI threat IDs at the next sequence after the security plan's threat count.

## How It Works

The RAI Planner follows six sequential phases, each mapped to NIST AI RMF functions. Every phase produces artifacts, and the agent never advances without your confirmation.

```mermaid
flowchart LR
    subgraph govern ["Govern + Map"]
        P1["Phase 1\nAI System Scoping"]
    end

    subgraph map ["Map"]
        P2["Phase 2\nSensitive Uses"]
    end

    subgraph measure ["Govern + Measure"]
        P3["Phase 3\nRAI Standards\nMapping"]
        P4["Phase 4\nRAI Security Model"]
    end

    subgraph manage ["Manage"]
        P5["Phase 5\nImpact Assessment"]
        P6["Phase 6\nReview & Handoff"]
    end

    P1 --> P2 --> P3 --> P4 --> P5 --> P6
```

### Phase 1: AI System Scoping

Discover the AI system's purpose, technology stack, deployment model, and stakeholder roles. Classify AI components and establish assessment boundaries. Maps to NIST Govern and Map functions.

### Phase 2: Sensitive Uses Assessment

Screen the AI system against Microsoft's sensitive uses categories. Identify restricted uses requiring escalation. Map vulnerable populations and downstream effects with harm severity ratings.

### Phase 3: RAI Standards Mapping

Map AI system components and behaviors to the six RAI principles: fairness, reliability and safety, privacy and security, inclusiveness, transparency, and accountability. Cross-reference with NIST AI RMF subcategories and applicable regulations.

### Phase 4: RAI Security Model Analysis

Apply AI-specific threat analysis per component using seven threat categories: data poisoning, model evasion, prompt injection, output manipulation, bias amplification, privacy leakage, and misuse escalation. Threats follow the `RAI-T-{CATEGORY}-{NNN}` format.

### Phase 5: RAI Impact Assessment

Evaluate control surface completeness for each identified threat. Document existing mitigations, identify gaps, analyze tradeoffs between competing RAI principles, and generate the control surface catalog and evidence register.

### Phase 6: Review and Handoff

Present the RAI scorecard summarizing all findings. Generate backlog items for identified gaps and hand off to the ADO or GitHub backlog system. Optionally dispatch findings back to the Security Planner for integrated tracking.

## Entry Modes

Three entry modes determine how Phase 1 begins. All converge at Phase 2 once AI system scoping completes.

| Mode                 | Source              | Best for                                                      |
|----------------------|---------------------|---------------------------------------------------------------|
| `capture`            | Fresh interview     | New AI projects without prior artifacts                       |
| `from-prd`           | PRD/BRD documents   | Projects with product definition artifacts                    |
| `from-security-plan` | Security plan state | Projects that completed security planning first (recommended) |

See [entry modes](entry-modes.md) for detailed guidance on when to choose each mode and what each mode pre-populates.

## Related Pages

| Page                                       | Description                                                            |
|--------------------------------------------|------------------------------------------------------------------------|
| [Why RAI planning?](why-rai-planning.md)   | The case for structured RAI assessment over ad-hoc reviews             |
| [Agent overview](agent-overview.md)        | Architecture, state management, and interaction model                  |
| [Entry modes](entry-modes.md)              | Choosing between capture, from-prd, and from-security-plan             |
| [Phase reference](phase-reference.md)      | Detailed inputs, outputs, and state transitions for all six phases     |
| [Handoff pipeline](handoff-pipeline.md)    | Scorecard generation, backlog output, and the Security-to-RAI pipeline |
| [Security planning overview](../security/) | The Security Planner agent that feeds into RAI assessment              |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
