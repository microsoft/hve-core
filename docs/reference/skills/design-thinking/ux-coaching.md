---
title: ux-coaching
description: "Coach a UX practitioner through problem framing, running a design critique, or making an evidence-backed case to a skeptical stakeholder. Use when the practitioner has a live UX task and wants to think it through rather than receive an answer."
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - design-thinking
  - ux-coaching
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                         |
|-------------|-------------------------------------------------------------------------------|
| Kind        | skill                                                                         |
| Source      | `.github/skills/design-thinking/ux-coaching`                                  |
| Invocation  | Invoked directly as `/ux-coaching`, or loaded on demand by referencing agents |
| Interactive | No                                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coach a UX practitioner through problem framing, running a design critique, or making an evidence-backed case to a skeptical stakeholder. Use when the practitioner has a live UX task and wants to think it through rather than receive an answer.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a UX practitioner is at one of three practice moments and wants coaching rather than an answer:

| Moment                 | Situation                                                                                                                                          |
|------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| `problem-framing`      | The stated problem may not be the real problem, and the framing needs to be tested against current experience, user needs, and stated assumptions. |
| `critique`             | A design needs a structured critique, and the practitioner wants the review to surface issues rather than approval.                                |
| `stakeholder-advocacy` | Evidence exists, but a skeptical stakeholder is not persuaded, and the case needs to rest on evidence quality rather than rhetoric.                |

The skill assumes no Design Thinking experience and makes no runtime call into the Design Thinking coaching skills. Its guidance is grounded in GOV.UK Service Manual, the DDaT capability framework, and the ISE Engineering Playbook.

Reach for a different asset when:

* A full Design Thinking engagement is wanted rather than a single moment. Use the [DT Coach](../../agents/design-thinking/dt-coach.md) agent.
* The task is producing a canonical problem statement artifact rather than reasoning toward one. This skill coaches the thinking and hands off; it does not render artifacts.
* Broader UX discovery, journey mapping, or accessibility requirements are needed. Use the [UX UI Designer](../../agents/project-planning/ux-ui-designer.md) agent, which routes its problem-framing work here.

## Example usage

Invoke the skill directly with a moment, a project slug, and the subject under discussion:

```text
/ux-coaching moment=problem-framing project=checkout-redesign subject="users abandon at the payment step"
```

The skill opens the problem-framing moment, then coaches through the three components rather than answering:

```text
Before we accept "users abandon at the payment step" as the problem, let's separate
what you have observed from what you have inferred.

Current experience: what does the abandonment data actually show - at which point,
for which users, and over what period?

User needs: has anyone spoken to a user who abandoned, or is the need inferred from
the funnel shape?

Assumptions and boundaries: you have framed this as a payment-step problem. What
would have to be true elsewhere in the journey for that framing to be wrong?
```

Session state persists to `.copilot-tracking/ux-coaching/checkout-redesign/state.yaml`, so the same moment can be resumed later:

```text
/ux-coaching project=checkout-redesign
```

The skill reopens the moment with its recorded evidence, assumptions, and unresolved questions, and continues from the resume summary rather than restarting the conversation.
