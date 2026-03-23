---
title: Why Security Planning?
description: The reasoning behind structured, phase-based security analysis and how it compares to ad-hoc approaches
sidebar_position: 2
sidebar_label: Why Security Planning?
keywords:
  - security planning
  - threat modeling
  - why
tags:
  - agents
  - security
author: Microsoft
ms.date: 2026-03-11
ms.topic: concept
estimated_reading_time: 6
---

Security analysis tends to go one of two ways. Teams either run through a checklist that misses project-specific risks, or they rely on senior engineers who carry the threat model in their heads. Both approaches break down as projects grow, team members rotate, and compliance requirements shift.

The Security Planner exists to close that gap. It provides a repeatable structure that captures institutional knowledge, maps it to industry standards, and produces work items that are specific enough to act on.

## The Core Insight

Most security gaps do not come from missing expertise. They come from missing process. A senior engineer knows to check for injection attacks, but without a structured workflow, the check happens inconsistently. The Security Planner makes the process explicit: every project gets the same seven-bucket analysis, the same standards mapping, and the same threat-severity framework.

## How Each Phase Helps

### Phase 1: Project Scoping

Scoping forces the team to articulate what the system does, what data it handles, and where it runs before any threat analysis begins. This prevents the common failure mode of jumping straight to threat lists without understanding the attack surface.

### Phase 2: Bucket Analysis

Classifying components into operational buckets (infrastructure, DevOps, build, messaging, data, web/UI, identity/auth) ensures that no layer is overlooked. Cross-cutting concerns get their own overlay rather than being silently dropped.

### Phase 3: Standards Mapping

Mapping each bucket to OWASP, NIST, and CIS controls anchors the analysis in established frameworks. This gives reviewers and auditors a shared vocabulary and reduces the risk of reinventing guidance that already exists.

### Phase 4: Security Model Analysis

STRIDE-based threat modeling per bucket produces threats with consistent identifiers (`T-{BUCKET}-{NNN}`), severity ratings, and data flow context. This makes threats traceable from discovery through remediation.

### Phase 5: Backlog Generation

Converting threats into backlog items with acceptance criteria closes the loop between analysis and action. Autonomy tiers control how much human oversight each item receives, so low-risk fixes move quickly while high-risk changes get the review they need.

### Phase 6: Review and Handoff

The review phase validates completeness and catches gaps before the analysis leaves the agent. When AI/ML components are in scope, the handoff to the RAI Planner carries the security context forward rather than starting from scratch.

## Quality Comparison

| Dimension              | Ad-hoc review                   | Security Planner                           |
|------------------------|---------------------------------|--------------------------------------------|
| Coverage consistency   | Varies by reviewer              | Same seven-bucket structure every time     |
| Standards traceability | Informal or missing             | OWASP, NIST, CIS mapped per bucket         |
| Threat identification  | Depends on individual expertise | STRIDE-based with severity ratings         |
| Backlog quality        | Generic "fix security" items    | Specific items with acceptance criteria    |
| Knowledge transfer     | Lost when engineers leave       | Captured in plan artifacts and state files |
| AI/ML risk coverage    | Often skipped                   | Auto-detected with RAI Planner handoff     |

## Learning Curve

Adoption does not need to be all-or-nothing. Teams can scale up incrementally:

1. **Start with Capture mode** on a single project to see the full six-phase flow.
2. **Switch to From-PRD mode** once PRD/BRD artifacts are routinely available.
3. **Adjust autonomy tiers** to match your team's comfort level with agent-generated work items.
4. **Enable RAI handoff** for projects that include AI/ML components.

## Choosing Your Approach

The right entry mode depends on what artifacts already exist and how much context the agent needs to gather.

| Starting point                  | Recommended mode | Reason                                       |
|---------------------------------|------------------|----------------------------------------------|
| PRD or BRD available            | From-PRD         | Seeds Phase 1 from existing requirements     |
| No formal requirements          | Capture          | Gathers scope through structured interview   |
| Prior security plan exists      | Either           | New plan, but prior analysis informs scoping |
| AI/ML components known up front | Either           | Both modes auto-detect AI/ML during Phase 1  |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
