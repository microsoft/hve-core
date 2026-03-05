---
title: UX Designer
description: Design Thinking coaching, user research, and prototyping workflows for UX Designers
author: Microsoft
ms.date: 2026-02-25
ms.topic: tutorial
keywords:
  - ux designer
  - design thinking
  - prototyping
  - user research
estimated_reading_time: 10
---

HVE Core provides addressable assets tailored to UX design workflows, with Design Thinking coaching, structured user research, and prototyping support powered by AI-assisted agents. Whether you are running scope conversations with stakeholders, synthesizing research data, or testing lo-fi prototypes, the tooling guides you through a proven nine-method sequence.

## Recommended Collections

> [!TIP]
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace to get all stable artifacts with zero configuration.
>
> Your primary collection is `design-thinking` (full Design Thinking coaching, method guides, learning tutor, and space transition support). For clone-based setups, use the **hve-core-installer** agent with `install design-thinking`.

## What HVE Core Does for You

1. Coaches you through all nine Design Thinking methods from scope conversations to iteration at scale
2. Structures user research with interview techniques, environmental observation, and evidence triangulation
3. Synthesizes research inputs into validated themes, problem definitions, and How Might We questions
4. Facilitates divergent brainstorming and convergent concept selection with stakeholder alignment
5. Guides lo-fi and hi-fi prototyping with scrappy enforcement and fidelity-appropriate feedback planning
6. Supports user testing with evidence-based evaluation protocols and severity-ranked findings
7. Manages non-linear iteration across methods and spaces when discoveries require revisiting earlier work

## Your Lifecycle Stages

> [!NOTE]
> UX Designers primarily operate in these lifecycle stages:
>
> Discovery: Scope conversations, design research, and input synthesis (Methods 1-3)
> Design: Brainstorming and user concepts (Methods 4-5)
> Prototype: Lo-fi prototyping and constraint discovery (Method 6)
> Test: Hi-fi prototypes and user testing (Methods 7-8)
> Iterate: Iteration at scale with telemetry-driven optimization (Method 9)

## Stage Walkthrough

1. Discovery. Start with the **dt-coach** agent to run scope conversations (Method 1), identifying stakeholders and validating the problem statement. Continue into design research (Method 2) for interview-based evidence gathering, then synthesize inputs (Method 3) into themes and How Might We questions.
2. Design. Use **dt-coach** for brainstorming (Method 4) to generate divergent solution ideas grounded in validated themes, then develop user concepts (Method 5) with visual representations and Desirability/Feasibility/Viability analysis.
3. Prototype. Build lo-fi prototypes (Method 6) with **dt-coach** enforcing scrappy, low-cost experiments. Test prototypes with real users and document constraint discoveries.
4. Test. Transition to hi-fi prototypes (Method 7) with functional systems and real data, then run user testing (Method 8) with evidence-based evaluation protocols and severity-ranked findings.
5. Iterate. Deploy at scale (Method 9) with telemetry-driven optimization, connecting metrics to iteration priorities and managing organizational change.

## Starter Prompts

Select **dt-coach** agent:

```text
Start a new Design Thinking project for improving the developer
onboarding experience. Begin with scope conversations to identify
stakeholders and validate the problem statement.
```

Select **dt-coach** agent:

```text
I have completed scope conversations and have a validated problem
statement. Move to design research and help me plan interviews
with 5 developer personas across junior, mid-level, and senior
experience bands.
```

Select **dt-coach** agent:

```text
Synthesize the research findings from my 8 interviews. Identify
themes, create an affinity diagram, and generate How Might We
questions that bridge the problem space to solution space.
```

Select **dt-coach** agent:

```text
Run a brainstorming session for the onboarding friction theme.
Generate divergent ideas first, then help me cluster and evaluate
them against desirability, feasibility, and viability criteria.
```

## Key Agents and Workflows

| Agent                 | Purpose                                             | Docs                                                   |
|-----------------------|-----------------------------------------------------|--------------------------------------------------------|
| **dt-coach**          | Full nine-method Design Thinking coaching           | [DT Coach](../../design-thinking/dt-coach.md)          |
| **dt-learning-tutor** | Self-paced Design Thinking curriculum and exercises | [DT Tutor](../../design-thinking/dt-learning-tutor.md) |
| **ux-ui-designer**    | UX/UI design guidance and interface review          | Agent file                                             |
| **task-researcher**   | Deep technical and market research                  | [Task Researcher](../../rpi/task-researcher.md)        |
| **memory**            | Session context and preference persistence          | Agent file                                             |

## Tips

| Do                                                         | Don't                                                          |
|------------------------------------------------------------|----------------------------------------------------------------|
| Complete each DT method before progressing to the next     | Skip methods without validating readiness signals              |
| Test prototypes with real users, not just team members     | Treat internal reviews as user validation                      |
| Use the **dt-learning-tutor** to learn methods before use  | Start coaching a real project without understanding methods    |
| Let **dt-coach** manage space transitions                  | Manually jump between Problem, Solution, and Validation spaces |
| Document constraint discoveries from every prototype round | Discard prototype feedback that contradicts your hypothesis    |

## Related Roles

* UX Designer + Engineer: Design Thinking outputs feed directly into RPI implementation workflows. Validated concepts from Method 5 become requirements for engineering sprints. See the [Engineer Guide](engineer.md).
* UX Designer + TPM: Scope conversations (Method 1) align with TPM stakeholder management. BRD creation benefits from DT-validated problem statements. See the [TPM Guide](tpm.md).
* UX Designer + BPM: User-centered design insights inform business program decisions. DT research findings strengthen BRD business justifications. See the [Business Program Manager Guide](business-program-manager.md).

## Next Steps

> [!TIP]
> Learn Design Thinking methods: [Design Thinking Overview](../../design-thinking/README.md)
> Try the DT learning tutor: [DT Learning Tutor](../../design-thinking/dt-learning-tutor.md)
> See how your stages connect: [AI-Assisted Project Lifecycle](../lifecycle/)

Brought to you by microsoft/hve-core

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
