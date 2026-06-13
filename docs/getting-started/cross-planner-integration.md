---
title: Cross-Planner Integration
description: How the Accessibility, Security, RAI, and SSSC planners share evidence records and deterministic signals through reference fields and a shared evidence-register schema
sidebar_position: 11
sidebar_label: Cross-Planner Integration
keywords:
  - cross-planner integration
  - accessibility planner
  - security planner
  - RAI planner
  - SSSC planner
  - evidence register
author: Microsoft
ms.date: 2026-05-28
ms.topic: concept
estimated_reading_time: 4
---

The Accessibility, Security, RAI, and SSSC planners are designed to share work rather than duplicate it. When two or more planners run against the same project, they exchange evidence records and deterministic signals through reference fields and a shared evidence-register schema.

> [!NOTE]
> Integration is opportunistic. Each planner runs standalone; the flows below activate only when the partner artifact is present in the same session or tracking directory.

## How Sharing Works

| Mechanism             | How it works                                                                                                                                       |
|-----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| Evidence register     | Accessibility evidence records conform to a shared `evidence-register.schema.json` and carry stable URIs, so other planners cite them by reference |
| Reference fields      | Entry modes set fields such as `securityPlanRef` and `raiPlanRef` in `state.json`, linking the accessibility plan to its upstream source           |
| Deterministic signals | The Security Reviewer's Codebase Profiler and the Accessibility Reviewer's profiler emit overlapping signals that each can consume as hints        |

## Integration Matrix

| Direction                | Mechanism                                                                                                                                              | Trigger                                                                                        |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| Accessibility → Security | Shared `evidence-register.schema.json` (`$ref`); accessibility evidence records carry stable URIs that security reports cite under "External evidence" | Security reviewer encounters auth or content-rendering paths flagged as accessibility-relevant |
| Accessibility → RAI      | Planner Phase 4 inserts `humanReviewControl` entries when the project profile declares AI-generated UI, generated alt text, or generated captions      | Discovery phase tags `aiGeneratedSurfaces: true`                                               |
| Accessibility → SSSC     | Section 508 and EN 301 549 evidence records feed SSSC procurement gates (VPAT, EAA conformance)                                                        | SSSC Phase 4 (Gap Analysis) requests accessibility statements                                  |
| RAI → Accessibility      | RAI risk classification escalates to `coga` blocking controls when impacted populations include cognitive disability users                             | RAI Phase 2 prohibited-uses screen flagged "vulnerable populations"                            |
| Security → Accessibility | Security Codebase Profiler shares deterministic signals; the accessibility profiler may consume the same signals output as a hint                      | Both planners run in the same session                                                          |

## Recommended Order

When several planners apply to one project, run them so that upstream evidence is available to downstream gates:

1. **Security Planner** establishes the surface inventory and AI/ML flags.
2. **RAI Planner** classifies risk and flags AI-generated UI for synthetic-content review.
3. **Accessibility Planner** reuses both, then maps success criteria and produces evidence.
4. **SSSC Planner** consumes accessibility evidence for procurement gates.

This order is a recommendation, not a requirement. Each planner detects available upstream artifacts and adapts.

## Next Steps

* [Accessibility Planner](../agents/accessibility/accessibility-planner.md) for the agent reference.
* [Accessibility Planner Quickstart](accessibility-planner.md) for a five-minute walkthrough.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
