---
title: "Method 8: Test and Validate"
description: "Conduct structured user testing of hi-fi prototypes to gather evidence for go, iterate, or revisit decisions across the nine-method sequence."
author: Microsoft
ms.date: 2026-02-25
ms.topic: tutorial
keywords: [design thinking, method-08, test-validate]
estimated_reading_time: 5
---

## What This Method Does

Method 8 puts functional prototypes in front of real or representative users and gathers evidence for go, iterate, or revisit decisions. You conduct structured testing sessions that capture user behavior under realistic conditions, then analyze the results to determine whether to proceed, refine, or return to an earlier method.

Unlike earlier feedback sessions, Method 8 produces actionable evidence rather than opinions. Test results drive decisions about whether the solution works, what needs to change, and how deep those changes run.

## When to Use

* After completing Hi-Fi Prototypes (Method 7) with functional implementations validated for technical feasibility
* When you need evidence-based evaluation of whether solutions work for real users
* When the team needs data to decide between competing technical approaches
* When you suspect core assumptions may need revisiting through earlier methods

## Space Context

Method 8 sits in the **middle of the Validation Space**, between technical proof (Method 7) and scaled deployment (Method 9). Method 8 is the primary trigger for non-linear iteration across the nine-method sequence. Test results may reveal gaps requiring return to Method 2 (research), Method 4 (brainstorming), or Method 6/7 (prototyping).

> [!IMPORTANT]
> Honest evidence interpretation is the defining challenge of Method 8. Confirmation bias tempts teams to focus on positive results and dismiss negative findings. The data determines the next step, not the team's preference.

## Key Activities

* Test protocol design: Design testing protocols that use specific tasks, not opinion questions. Select from task-based testing (workflow validation), A/B comparison (prototype variants), think-aloud (mental model discovery), Wizard of Oz (concept viability before full build), or longitudinal testing (adoption over time).
* Participant selection: Recruit participants representing all relevant user types identified in Method 2 research. Include primary, secondary, and edge-case users to avoid designing only for the most common scenario.
* Leap-enabling questioning: Ask questions that reveal how users actually behave, not how they feel. Replace "Do you like this?" with "Walk me through what happened when you used this during your last task." Follow experience questions with progressive "why?" questioning to uncover underlying needs.
* Environmental testing: Conduct tests under realistic conditions. Factory noise, clinical workflow interruptions, time pressure, and integration with existing tools all affect results. Ideal-condition testing produces misleadingly positive data.
* Non-linear loop decisions: Analyze findings to determine the appropriate response. Missing user data points to Method 2. Invalidated concepts point to Method 4. Wrong fidelity or constraint issues point to Method 6 or 7. Minor usability issues and validated assumptions both point to Method 9.

## How to Start

Review the technical specifications and trade-off documentation from Method 7. Design test protocols that put prototypes in front of real users doing real tasks.

Use this prompt to plan a testing session:

```text
We have [number] functional prototypes validated in Method 7 for [use case].
The key technical trade-offs are [trade-offs]. Help me design a test protocol
that evaluates these prototypes with [user types] under realistic conditions,
including task definitions, success criteria, and leap-enabling question progressions.
```

During testing:

* Observe behavior first, then ask questions
* Document what users do, not just what they say
* Test under realistic environmental conditions, not ideal settings
* Prepare for findings that challenge core assumptions

## Expected Outputs

* Test protocols documenting methodology, participant profiles, success criteria, and question progressions
* Per-session observation notes capturing user behavior, environmental factors, and raw data
* Results analysis synthesizing findings across sessions with pattern identification and evidence strength ratings
* Decision log recording go, iterate, or revisit decisions with supporting evidence and target method for each decision
* Loop documentation preserving context when findings trigger return to an earlier method

## Quality Checks

* Test protocols use specific tasks rather than opinion questions
* Participants represent all relevant user types, not just primary users
* Testing occurred under realistic environmental conditions
* Analysis addresses all findings, including negative results, not just positive outcomes
* Loop decisions are supported by evidence and correctly mapped to target methods

## Next Method

When testing produces sufficient evidence for a clear decision:

* For minor usability issues or validated assumptions, proceed to [Method 9: Iteration at Scale](method-09-iteration-at-scale.md) to optimize and deploy.
* For deeper findings, return to the appropriate earlier method as indicated by the non-linear loop decision framework.

## Related Resources

* [Method 7: Hi-Fi Prototypes](method-07-hifi-prototypes.md)
* [Method 9: Iteration at Scale](method-09-iteration-at-scale.md)
* [Design Thinking Overview](README.md)

> Brought to you by microsoft/hve-core

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
