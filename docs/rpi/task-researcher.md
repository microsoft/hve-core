---
title: Task Researcher Guide
description: Use the Task Researcher custom agent to conduct deep, evidence-based research before coding
author: Microsoft
ms.date: 2026-01-24
ms.topic: tutorial
keywords:
  - task researcher
  - rpi workflow
  - research phase
  - github copilot
estimated_reading_time: 4
---

The Task Researcher custom agent transforms uncertainty into verified knowledge through deep, autonomous research. It investigates your codebase, external documentation, and APIs to create evidence-backed recommendations.

## When to Use Task Researcher

Escalate to Task Researcher when your task involves:

* 🔄 **Multi-file changes** requiring coordination
* 📚 **New patterns or frameworks** you haven't used before
* 🔌 **External API integrations** with authentication or complex workflows
* ❓ **Unclear requirements** needing investigation
* 🏗️ **Architecture decisions** affecting multiple components

## What Task Researcher Does

1. **Investigates** using workspace search, file reads, and external tools
2. **Documents** findings with evidence, sources, and line references
3. **Evaluates** alternatives with benefits and trade-offs
4. **Recommends** ONE approach per technical scenario
5. **Outputs** a comprehensive research document

> [!NOTE]
> **Why the constraint matters:** Task Researcher knows it will never write the code. This single constraint transforms its behavior—it searches for existing patterns instead of inventing new ones, cites specific files as evidence, and questions its own assumptions because it can't hide them in implementation.

## Output Artifact

Task Researcher creates a research document at:

```text
.copilot-tracking/research/{{YYYY-MM-DD}}-<topic>-research.md
```

This document includes:

* Scope and success criteria
* Evidence log with sources
* Code examples from the codebase
* External research findings
* Recommended approach with rationale

## How to Use Task Researcher

### Option 1: Use the Prompt Shortcut (Recommended)

Type `/task-research <topic>` in GitHub Copilot Chat where `<topic>` describes what you want to research:

```text
/task-research Azure Blob Storage integration for Python pipelines
```

This automatically switches to Task Researcher and begins the research protocol.

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

Task Researcher works autonomously for 20-60 minutes. It will:

* Search your codebase for patterns
* Read relevant files and documentation
* Use external tools (Context7, Azure docs, etc.)
* Create the research document

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

* Ask for implementation (that's Task Implementor's job)
* Skip research for complex tasks
* Provide vague descriptions

## Common Pitfalls

| Pitfall              | Solution                                         |
|----------------------|--------------------------------------------------|
| Research too broad   | Focus on specific technical questions            |
| Skipping research    | Always research multi-file or unfamiliar changes |
| Not reviewing output | Read the research doc before planning            |

## Next Steps

After Task Researcher completes:

1. **Review** the research document in `.copilot-tracking/research/`
2. **Clear context** using `/clear` or starting a new chat
3. **Proceed to planning** with [Task Planner](task-planner.md)

Pass the research document path to Task Planner so it can create an actionable implementation plan.

> [!TIP]
> Use the **📋 Create Plan** handoff button when available to transition directly to Task Planner with context.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
