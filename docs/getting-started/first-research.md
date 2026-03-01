---
title: Your First Research
description: Use the task-researcher agent to investigate your own codebase
sidebar_position: 4
author: Microsoft
ms.date: 2026-02-18
ms.topic: tutorial
keywords:
  - getting started
  - first research
  - task researcher
  - rpi workflow
  - github copilot
estimated_reading_time: 5
---

> [!NOTE]
> Step 2 of 4 in the [Getting Started Journey](./).

The RPI framework separates research from implementation. Before writing code,
you find verified facts about the codebase. This exercise introduces the
Research phase by itself, without the planning or implementation phases.

## Pick a Research Question

Choose something you genuinely want to know about your codebase. Examples:

* "How are tests structured in this project?"
* "What patterns does this codebase use for error handling?"
* "What dependencies does the authentication module have?"

Use a question where the answer would actually help you. Contrived exercises
teach methodology; real questions teach methodology and produce useful output.

## Run the Research

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`).
2. Select the **task-researcher** agent.
3. Type your question as a prompt.

The agent creates a research document in `.copilot-tracking/research/` with
findings, file references, and evidence. This takes 2-5 minutes depending on
the scope of the question.

## Read the Output

Open the research document. You'll find:

* The agent cites file references with line numbers for each fact.
* Conclusions trace back to actual code through evidence-linked findings.
* Areas where research was incomplete appear as remaining questions.

This is what "verified truth" looks like in RPI. The agent did not guess or
generate plausible answers. It searched, read, and cited.

> [!NOTE]
> Your first research document may feel verbose. That's intentional. Research
> outputs are reference material for the planning phase, not finished prose.
> Over time, you'll learn to scope questions tightly to get focused results.

## What You Learned

* Researching before implementation reduces guesswork and rework.
* Agents produce artifacts like research documents, not chat messages alone.
* Artifacts carry context so the next phase builds on verified facts rather
  than starting from scratch.

## Next Step

You've installed HVE Core, talked to an agent, and run your first research.
The next step is a full Research, Plan, Implement cycle:
[Your First Full Workflow](first-workflow.md).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
