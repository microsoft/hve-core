---
title: User Journey Map
description: Structured template for Jobs-to-be-Done analysis and user journey mapping
sidebar_position: 5
author: Microsoft
ms.date: 2026-02-16
ms.topic: reference
keywords:
  - ux
  - user journey
  - jobs-to-be-done
  - jtbd
  - user research
  - design
estimated_reading_time: 3
---

This template provides a structured format for documenting user journey maps grounded in Jobs-to-be-Done (JTBD) analysis. The JTBD section establishes the foundational user need, and the journey map traces how users move through stages of awareness, action, and outcome.

## Template

````markdown
# User Journey: {{journeyTitle}}

## Jobs-to-be-Done Analysis

### Job Statement

When {{situation}}, I want to {{motivation}}, so I can {{desiredOutcome}}.

### Current Solution

| Aspect              | Details                 |
|---------------------|-------------------------|
| Current approach    | {{currentApproach}}     |
| Primary pain points | {{painPoints}}          |
| Time or cost impact | {{costImpact}}          |
| Workarounds in use  | {{existingWorkarounds}} |

### Success Criteria

| Metric      | Baseline      | Target      | Measurement Method |
|-------------|---------------|-------------|--------------------|
| {{metric1}} | {{baseline1}} | {{target1}} | {{method1}}        |
| {{metric2}} | {{baseline2}} | {{target2}} | {{method2}}        |

## User Persona

| Attribute      | Details                |
|----------------|------------------------|
| Role           | {{userRole}}           |
| Goal           | {{userGoal}}           |
| Context        | {{usageContext}}       |
| Skill level    | {{skillLevel}}         |
| Primary device | {{primaryDevice}}      |
| Accessibility  | {{accessibilityNeeds}} |

## Journey Stages

### Stage 1: {{stageName}}

| Dimension   | Details                   |
|-------------|---------------------------|
| Doing       | {{whatUserIsDoing}}       |
| Thinking    | {{whatUserIsThinking}}    |
| Feeling     | {{emotionalState}}        |
| Pain points | {{painPointsAtThisStage}} |
| Opportunity | {{designOpportunity}}     |

### Stage 2: {{stageName}}

| Dimension   | Details                   |
|-------------|---------------------------|
| Doing       | {{whatUserIsDoing}}       |
| Thinking    | {{whatUserIsThinking}}    |
| Feeling     | {{emotionalState}}        |
| Pain points | {{painPointsAtThisStage}} |
| Opportunity | {{designOpportunity}}     |

### Stage 3: {{stageName}}

| Dimension   | Details                   |
|-------------|---------------------------|
| Doing       | {{whatUserIsDoing}}       |
| Thinking    | {{whatUserIsThinking}}    |
| Feeling     | {{emotionalState}}        |
| Pain points | {{painPointsAtThisStage}} |
| Opportunity | {{designOpportunity}}     |

### Stage 4: Outcome

| Dimension          | Details                       |
|--------------------|-------------------------------|
| Doing              | {{whatUserIsDoing}}           |
| Thinking           | {{whatUserIsThinking}}        |
| Feeling            | {{emotionalState}}            |
| Success signals    | {{howUserKnowsTheySucceeded}} |
| Remaining friction | {{anyRemainingFriction}}      |

## Accessibility Requirements

| Category              | Requirement                         |
|-----------------------|-------------------------------------|
| Keyboard navigation   | {{keyboardRequirements}}            |
| Screen reader support | {{screenReaderRequirements}}        |
| Visual accessibility  | {{visualAccessibilityRequirements}} |
| Motor accessibility   | {{motorAccessibilityRequirements}}  |

## Design Handoff

### Flow Summary

{{highLevelFlowDescription}}

### Design Principles

* {{designPrinciple1}}
* {{designPrinciple2}}
* {{designPrinciple3}}

### Key Interactions

| Screen or Step | Primary Action | Expected Outcome |
|----------------|----------------|------------------|
| {{screen1}}    | {{action1}}    | {{outcome1}}     |
| {{screen2}}    | {{action2}}    | {{outcome2}}     |

### Exit Points

| Exit Type | Condition            | Recovery Path       |
|-----------|----------------------|---------------------|
| Success   | {{successCondition}} | {{successNextStep}} |
| Partial   | {{partialCondition}} | {{partialRecovery}} |
| Blocked   | {{blockedCondition}} | {{blockedRecovery}} |

## Open Questions

| ID | Question      | Owner      | Status      |
|----|---------------|------------|-------------|
| Q1 | {{question1}} | {{owner1}} | {{status1}} |
| Q2 | {{question2}} | {{owner2}} | {{status2}} |
````

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
