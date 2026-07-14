---
title: Task Researcher Guide
description: Use Task Researcher for a demonstrated evidence gap before planning or implementation
sidebar_position: 4
author: Microsoft
ms.date: 2026-07-14
ms.topic: tutorial
keywords:
  - task researcher
  - rpi workflow
  - research phase
  - github copilot
estimated_reading_time: 4
---

Task Researcher investigates a demonstrated readiness gap before planning or implementation. It examines your codebase, external documentation, and APIs within the assigned boundary, then creates evidence-backed recommendations for the next lifecycle concept.

## When to Use Task Researcher

Use Task Researcher when supplied or completed research is not adequate for a task's:

* Requirements or acceptance criteria
* Dependencies or material risks
* Complexity or uncertainty
* Decision-critical question

Multi-file changes, new patterns, external integrations, unclear requirements, and architecture decisions can demonstrate one of these gaps, but they do not automatically require fresh research. Reuse adequate evidence and record why Research is reused or satisfied-and-skipped.

## What Task Researcher Does

1. Investigates using workspace search, file reads, and external tools.
2. Documents findings with evidence, sources, and precise source locations when useful.
3. Evaluates alternatives with benefits and trade-offs.
4. Recommends one approach per technical scenario.
5. Outputs a research document with planning-readiness evidence.

> [!NOTE]
> **Why the constraint matters:** Task Researcher does not write implementation code. It searches for existing patterns instead of inventing new ones, cites supporting sources, and records assumptions that the evidence cannot resolve.

## Output Artifact

Task Researcher creates a research document at:

```text
.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md
```

This document includes:

* Scope, readiness gap, and success criteria
* Evidence log with sources and supported source locations
* Codebase and external findings
* Recommended approach, rationale, and unresolved decisions
* Planning-readiness disposition

## How to Use Task Researcher

### Option 1: Use the RPI Research Skill

Type `/rpi-research <topic>` in GitHub Copilot Chat when research readiness identifies a gap:

```text
/rpi-research Azure Blob Storage integration for Python pipelines
```

This activates the research phase for the stated gap.

### Option 2: Select the Custom Agent Manually

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown at the top
3. Select **Task Researcher**
4. Describe your task

### Step 2: Describe Your Task

Provide context about what you're trying to accomplish. Be specific about:

* The problem you're solving
* Technologies or patterns involved
* Any constraints or requirements

### Step 3: Let It Research

Task Researcher works within its assigned research boundary. It will:

* Search your codebase for patterns
* Read relevant files and documentation
* Use external tools (Context7, Azure docs, etc.)
* Create the canonical research document

### Step 4: Review the Research

When complete, Task Researcher provides:

* Summary of key findings
* Location of the research document
* Next steps for planning phase

## Example Prompt

```text
I need to add Azure Blob Storage integration to our Python data pipeline.
The pipeline currently writes to local disk in src/pipeline/writers/.
Research:
- Azure SDK for Python blob storage options
- Authentication approaches (managed identity vs connection string)
- Streaming uploads for files > 1GB
- Error handling and retry patterns

Focus on approaches that match our existing patterns in the codebase.
```

## Tips for Better Research

✅ **Do:**

* Provide specific technical context
* Mention existing code patterns to match
* List specific questions to answer
* Include constraints (performance, security, etc.)

❌ **Don't:**

* Ask for implementation (that is Task Implementor's job)
* Repeat research when supplied evidence is adequate
* Provide vague descriptions of the demonstrated gap

## Common Pitfalls

| Pitfall                        | Solution                                               |
|--------------------------------|--------------------------------------------------------|
| Research too broad             | Focus on the demonstrated technical question           |
| Research started without a gap | Reassess readiness and reuse adequate evidence         |
| Not reviewing output           | Read the research artifact before planning             |

## Next Steps

After Task Researcher completes:

1. Review `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`.
2. Resume deliberately from the durable artifact, using a fresh context when the conversation has accumulated unrelated detail.
3. Proceed to planning with [Task Planner](task-planner).

Pass the research document path to Task Planner so it can create an actionable implementation plan.

> [!TIP]
> The planning parent uses the research evidence with the stable task ID, then navigates plan and detail work through `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
