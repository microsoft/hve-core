---
title: Using the DT Learning Tutor
description: Guide to using the dt-learning-tutor agent for self-paced Design Thinking education
author: Microsoft
ms.date: 2026-02-25
ms.topic: tutorial
keywords:
  - dt-learning-tutor
  - design thinking
  - learning
  - curriculum
estimated_reading_time: 6
---

The DT Learning Tutor is an adaptive instructor that teaches Design Thinking through a structured, nine-module curriculum. It provides comprehension checks, practice exercises, and pacing tailored to your experience level so you can build DT fluency before coaching a real project.

## When to Use DT Learning Tutor

Start with the learning tutor when you want to:

* Learn Design Thinking methodology before applying it to a live project
* Build foundational vocabulary (frozen vs fluid requests, affinity clustering, lo-fi prototyping)
* Practice techniques in a low-stakes reference scenario
* Assess your readiness to coach or participate in a real DT session

## What It Does

1. Assesses your experience level (beginner, intermediate, advanced)
2. Teaches core concepts, principles, and techniques for each DT method
3. Checks comprehension with targeted questions before progressing
4. Exercises skills using a manufacturing reference scenario
5. Adapts depth and rigor based on your responses

> [!NOTE]
> The tutor is syllabus-driven, not project-driven. It teaches DT methodology so you understand the framework. When you are ready to apply DT to a real challenge, hand off to [DT Coach](dt-coach.md).

## Output

The tutor tracks curriculum progress at:

```text
.copilot-tracking/dt/{project-slug}/
```

Progress artifacts include comprehension assessment results and exercise outputs for each completed module.

## How to Use DT Learning Tutor

### Step 1: Select the Agent

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown at the top
3. Select **DT Learning Tutor**

### Step 2: Introduce Yourself

The tutor begins by assessing your experience level and learning goals. Answer its opening questions honestly so it can calibrate content depth:

* Beginner: foundational concepts, simple examples, frequent comprehension checks
* Intermediate: method connections, technique comparisons, scenario-based assessment
* Advanced: methodology critiques, cross-method integration challenges, industry-specific depth

### Step 3: Choose Your Path

You have two options:

* **Full curriculum**: Work through all nine modules sequentially from Method 1 to Method 9
* **Targeted modules**: Jump to specific methods you want to learn or review

### Step 4: Learn and Practice

Each module delivers five components:

1. Module overview covering what the method does and why it matters
2. Core principles and vocabulary
3. Specific techniques used in the method
4. Comprehension questions that verify understanding
5. A practice exercise using the manufacturing reference scenario

## Example

Select the **dt-learning-tutor** agent, then start a learning session:

```text
I'm new to Design Thinking and want to learn the full
curriculum from the beginning. I've done some user research before but
never used a structured DT framework.
```

The tutor responds by classifying you as beginner-to-intermediate, then launches Module 1: Scope Conversations. It introduces the frozen vs fluid request distinction, walks through progressive questioning techniques, and asks you to classify a sample request before moving forward.

## Curriculum Overview

| Module | Method                   | Space      | Topics                                                                   |
|--------|--------------------------|------------|--------------------------------------------------------------------------|
| 1      | Scope Conversations      | Problem    | Frozen vs fluid requests, stakeholder mapping, constraint discovery      |
| 2      | Design Research          | Problem    | Contextual inquiry, environmental observation, discovery questions       |
| 3      | Input Synthesis          | Problem    | Affinity clustering, theme development, HMW questions                    |
| 4      | Brainstorming            | Solution   | Divergent ideation, convergent clustering, constraint-bounded creativity |
| 5      | User Concepts            | Solution   | Concept articulation, D/F/V analysis, stakeholder alignment              |
| 6      | Low-Fidelity Prototypes  | Solution   | Paper prototyping, scrappy enforcement, feedback planning                |
| 7      | High-Fidelity Prototypes | Validation | Technical translation, functional prototypes, specifications             |
| 8      | User Testing             | Validation | Test protocols, evidence-based evaluation, severity classification       |
| 9      | Iteration at Scale       | Validation | Change management, scaling patterns, telemetry-driven optimization       |

The three spaces represent the natural progression of Design Thinking:

* Problem Space (Methods 1-3): Understand the problem deeply before generating solutions
* Solution Space (Methods 4-6): Generate and shape ideas into testable concepts
* Validation Space (Methods 7-9): Build, test, and refine solutions with real users

## Tips for Effective Learning

✅ **Do:**

* Practice each module's exercises using the manufacturing reference scenario (Meridian Components plant with night-shift quality problems)
* Answer comprehension questions in your own words before checking the tutor's feedback
* Connect methods forward and backward (Method 2 research validates Method 1 assumptions; Method 3 synthesis feeds Method 4 brainstorming)
* Take notes on vocabulary and techniques you find unfamiliar

❌ **Don't:**

* Rush through comprehension checks; they surface gaps in understanding
* Skip earlier modules assuming you know the basics (the tutor calibrates depth, so even experienced practitioners gain value)

## Common Pitfalls

| Pitfall                                             | Solution                                                                            |
|-----------------------------------------------------|-------------------------------------------------------------------------------------|
| Treating learning as a substitute for real coaching | The tutor builds knowledge; apply it with [DT Coach](dt-coach.md) on a real project |
| Skipping the manufacturing scenario exercises       | Exercises build muscle memory for techniques you will use in coaching               |
| Studying modules out of order without context       | Methods build on each other; complete Problem Space before Solution Space           |

## Next Steps

After completing the curriculum (or the modules relevant to your goals):

1. Start a real project with [DT Coach](dt-coach.md) to apply what you learned
2. Review the method guides for quick reference during coaching sessions:
   * [Method 1: Scope Conversations](method-01-scope-conversations.md)
   * [Method 2: Design Research](method-02-design-research.md)
   * [Method 3: Input Synthesis](method-03-input-synthesis.md)
3. Explore the end-to-end walkthrough in [Using DT Methods Together](using-together.md)

> [!TIP]
> Use the **🎯 Start a DT project** handoff button when available to transition directly from learning to coaching with DT Coach.

Brought to you by microsoft/hve-core

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
