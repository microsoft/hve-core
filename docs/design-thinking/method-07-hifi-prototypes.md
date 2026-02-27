---
title: "Method 7: Hi-Fi Prototypes"
description: "Translate lo-fi constraint discoveries into technically feasible implementations that validate whether user-validated solutions can be built and deployed."
author: Microsoft
ms.date: 2026-02-25
ms.topic: tutorial
keywords: [design thinking, method-07, hifi-prototypes]
estimated_reading_time: 5
---

## What This Method Does

Method 7 translates the constraint discoveries from Method 6 into technically feasible prototypes that prove solutions can work under real-world conditions. You build functional implementations with real data, test multiple technical approaches for systematic comparison, and document the trade-offs that inform user testing in Method 8.

Hi-fi prototypes answer the question: can this actually be built and deployed? The focus is on technical proof and functional validation, not visual polish or production-ready interfaces.

## When to Use

* After completing Lo-Fi Prototypes (Method 6) with documented constraint discoveries from real-environment testing
* When concept assumptions have been validated at the lo-fi level and need technical feasibility confirmation
* When you need to compare multiple implementation approaches under realistic conditions
* Before committing to formal user testing in Method 8

## Space Context

Method 7 is the **entry point to the Validation Space**. The Validation Space spans Methods 7 through 9 and focuses on proving that solutions work technically, validating them with users, and scaling them for deployment. Method 7 establishes technical feasibility, Method 8 gathers user evidence, and Method 9 handles iteration and rollout.

> [!WARNING]
> Focus on functional proof, not visual design. Over-engineering at this stage wastes resources on polish that user testing in Method 8 may invalidate. Build working systems, not finished products.

## Key Activities

* Constraint-to-architecture translation: Convert environmental, workflow, and interaction constraints discovered in Method 6 into technical requirements. Map each constraint to specific implementation decisions.
* Multiple approach generation: Build at least 2 to 3 distinct technical approaches for systematic comparison. Different approaches reveal trade-offs that a single implementation path cannot surface.
* Real-condition validation: Test functional prototypes under actual environmental conditions: real data, real noise levels, real workflow integration, real system connections. Avoid ideal-condition-only testing that masks deployment failures.
* Integration testing: Validate connections with existing systems, data sources, and workflows. Confirm that the prototype coordinates with the tools and processes users already rely on.
* Trade-off documentation: Capture performance data, failure modes, and constraint compliance for each approach. Document why alternatives were rejected so Method 8 testers understand the full technical landscape.

## How to Start

Review the constraint discovery log from Method 6. Identify the technical requirements each constraint implies and plan at least two implementation approaches.

Use this prompt to begin technical prototyping:

```text
Our lo-fi testing revealed these constraints: [key constraints from Method 6].
The concept requires [core functionality]. Help me identify 2-3 technical approaches
that address these constraints, including trade-offs between performance, cost,
and integration complexity.
```

When building hi-fi prototypes:

* Use real data, not simulated inputs
* Test under actual environmental conditions (noise, lighting, workflow interruption)
* Compare approaches systematically with consistent metrics
* Document what fails and why, not just what succeeds

## Expected Outputs

* Functional prototypes tested under real-world conditions with real data
* Performance data across 2 to 3 technical approaches measuring response time, user effectiveness, integration compatibility, and resource usage
* Integration test results documenting system connections and coordination
* Trade-off documentation comparing approaches with data-backed rationale
* Technical specifications preparing scope and focus areas for Method 8 user testing

## Quality Checks

* Prototypes use real data and operate under actual environmental conditions
* At least 2 to 3 distinct technical approaches were tested for comparison
* Integration with existing systems is validated, not assumed
* Documentation captures rejected approaches and their failure modes, not just the winning approach
* Focus remained on functional proof rather than visual polish or production readiness

## Next Method

When you have functional prototypes validated under real conditions with documented trade-offs across multiple approaches, proceed to [Method 8: Test and Validate](method-08-test-validate.md) to conduct structured user testing with evidence-based evaluation.

## Related Resources

* [Method 6: Lo-Fi Prototypes](method-06-lofi-prototypes.md)
* [Method 8: Test and Validate](method-08-test-validate.md)
* [Design Thinking Overview](README.md)

> Brought to you by microsoft/hve-core

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
