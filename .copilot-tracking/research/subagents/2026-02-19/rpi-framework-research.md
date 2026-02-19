---
title: RPI Framework Research
description: Comprehensive research on the RPI workflow phases, benefits, quality comparisons, and decision guidance
author: Copilot Researcher Subagent
ms.date: 2026-02-19
ms.topic: reference
keywords:
  - rpi workflow
  - research plan implement review
  - ai constraints
  - quality comparison
  - type transformation pipeline
---

## Overview

The RPI (Research, Plan, Implement, Review) workflow is a four-phase framework that transforms complex coding tasks into validated solutions by constraining what AI can do at each stage. The core insight: when AI knows it *cannot* implement, it stops optimizing for "plausible code" and starts optimizing for "verified truth."

Sources: [docs/rpi/README.md](docs/rpi/README.md), [docs/rpi/why-rpi.md](docs/rpi/why-rpi.md), [docs/rpi/using-together.md](docs/rpi/using-together.md)

## Type Transformation Pipeline

The framework models work as a type transformation, where each phase converts one form of understanding into the next:

```text
Uncertainty → Knowledge → Strategy → Working Code → Validated Code
```

Each phase has a single-responsibility constraint that prevents AI from conflating investigation with implementation. The pipeline metaphor reinforces that outputs from one phase become typed inputs to the next, and skipping a phase means operating on the wrong type.

Source: [docs/rpi/README.md](docs/rpi/README.md) Lines 20-22

## Phase Details

### Phase 1: Research (Task Researcher)

| Attribute | Detail |
|-----------|--------|
| **Purpose** | Transform uncertainty into verified knowledge |
| **Key behaviors** | Investigates codebase, external APIs, and documentation; cites specific files and line numbers as evidence; questions its own assumptions; documents dependencies and conventions with precision |
| **Core constraint** | Knows it will never write the code — searches for existing patterns instead of inventing new ones |
| **Output artifact** | `.copilot-tracking/research/{{YYYY-MM-DD}}-<topic>-research.md` |
| **Duration** | 20-60 minutes (autonomous) |
| **Invocation** | `/task-research <topic>` |

**Why the constraint matters:** When the researcher agent cannot implement, it stops producing plausible-looking code and instead produces verifiable claims backed by file paths and line numbers. The output is a document anyone can audit — no tribal knowledge, no "I think this is how it works."

Source: [docs/rpi/task-researcher.md](docs/rpi/task-researcher.md), [docs/rpi/why-rpi.md](docs/rpi/why-rpi.md) Lines 60-70

### Phase 2: Plan (Task Planner)

| Attribute | Detail |
|-----------|--------|
| **Purpose** | Transform knowledge into actionable strategy |
| **Key behaviors** | Validates research exists (mandatory first step); creates coordinated planning files with checkboxes; includes line number references for precision; organizes tasks into logical phases with dependencies |
| **Core constraint** | Cannot implement — focuses entirely on sequencing, dependencies, and success criteria |
| **Output artifacts** | `.copilot-tracking/plans/{{YYYY-MM-DD}}-<topic>-plan.instructions.md` (checklist with phases) and `.copilot-tracking/details/{{YYYY-MM-DD}}-<topic>-details.md` (specifications per task) |
| **Invocation** | `/task-plan` with research file open in editor |

**Traceability chain:** Every plan task references exact lines in the details file, which in turn references research:

```text
Plan → Details (Lines X-Y) → Research (Lines A-B)
```

The plan becomes a contract that prevents improvisation during implementation.

Source: [docs/rpi/task-planner.md](docs/rpi/task-planner.md)

### Phase 3: Implement (Task Implementor)

| Attribute | Detail |
|-----------|--------|
| **Purpose** | Transform strategy into working code |
| **Key behaviors** | Reads the plan phase by phase, task by task; loads only needed details using line ranges; implements following workspace conventions; tracks changes in a changes log; verifies success criteria before marking complete |
| **Core constraint** | Executes the plan using patterns documented in research — no creative decisions that break existing patterns |
| **Output artifacts** | Working code files + `.copilot-tracking/changes/{{YYYY-MM-DD}}-<topic>-changes.md` |
| **Stop controls** | `phaseStop=true` (default: pause after each phase), `taskStop=true` (pause after each task) |
| **Invocation** | `/task-implement` |

Source: [docs/rpi/task-implementor.md](docs/rpi/task-implementor.md)

### Phase 4: Review (Task Reviewer)

| Attribute | Detail |
|-----------|--------|
| **Purpose** | Transform working code into validated code |
| **Key behaviors** | Locates review artifacts (research, plan, changes logs); extracts implementation checklist from source documents; validates each item with evidence from the codebase; runs validation commands (lint, build, test); documents findings with severity levels |
| **Core constraint** | Validates against documented specifications, not assumptions — gaps in research or planning become visible |
| **Output artifact** | `.copilot-tracking/reviews/{{YYYY-MM-DD}}-<topic>-review.md` |
| **Severity levels** | Critical (incorrect/missing required functionality), Major (deviates from specs/conventions), Minor (style, docs, optimization) |
| **Invocation** | `/task-review [scope]` |

Source: [docs/rpi/task-reviewer.md](docs/rpi/task-reviewer.md)

## The Review Phase Feedback Loop

The review phase closes the loop by triggering iteration back to earlier phases when findings reveal gaps:

| Review Status | Action | Target Phase |
|---------------|--------|--------------|
| Complete | Commit changes | Done |
| Needs Rework | Fix implementation issues | Implement |
| Research Gap | Investigate missing context | Research |
| Plan Gap | Add missing scope | Plan |

The iteration is explicit: clear context, open the review log, invoke the target phase agent. This prevents accumulated assumptions from contaminating the corrective work.

```text
Task Reviewer ──→ 🔬 Research More ──→ Task Researcher
Task Reviewer ──→ 📋 Revise Plan   ──→ Task Planner
Task Reviewer ──→ ⚡ Fix Issues    ──→ Task Implementor
```

Source: [docs/rpi/using-together.md](docs/rpi/using-together.md) Lines 225-265

## The /clear Rule and Why It Matters

**Always use `/clear` or start a new chat between phases.**

```text
Task Researcher → /clear → Task Planner → /clear → Task Implementor → /clear → Task Reviewer
```

Why this is critical:

* Each agent has different instructions and behavioral constraints.
* Accumulated context causes confusion — the implementation agent inherits research-phase assumptions and reasoning patterns that degrade its execution.
* Research findings live in files, not chat history. Clean context forces each agent to read the canonical artifacts rather than relying on stale conversational memory.
* Context contamination is the primary failure mode of single-session AI workflows.

Source: [docs/rpi/README.md](docs/rpi/README.md) Lines 70-79, [docs/rpi/using-together.md](docs/rpi/using-together.md)

## Quality Comparison: Traditional vs RPI

| Aspect | Traditional Approach | RPI Approach |
|--------|---------------------|--------------|
| **Pattern matching** | Invents plausible patterns | Uses verified existing patterns |
| **Traceability** | "The AI wrote it this way" | "Research document cites lines 47-52" |
| **Knowledge transfer** | Tribal knowledge in your head | Research documents anyone can follow |
| **Rework** | Frequent, after discovering assumptions were wrong | Rare, because assumptions are verified first |
| **Validation** | Hope it works or manual testing | Validated against specifications with evidence |

**The paradigm shift:** Stop asking AI "Write this code." Start asking: "Help me research, plan, then implement with evidence."

Source: [docs/rpi/why-rpi.md](docs/rpi/why-rpi.md) Lines 98-112

## Decision Matrix: Strict RPI vs rpi-agent

| Factor | Strict RPI | rpi-agent |
|--------|-----------|-----------|
| Research depth | Deep, verified, cited | Moderate, inline |
| Context contamination | Eliminated via `/clear` | Possible |
| Audit trail | Complete artifacts | Summary only |
| Review phase | Explicit with findings log | Integrated in iteration loop |
| Best for | Complex, unfamiliar, team work | Simple, familiar, solo work |

### When to Choose Strict RPI

* Deep research needed: new frameworks, external APIs, compliance requirements
* Multi-file changes: pattern discovery across the codebase
* Team handoff: artifacts document decisions for others
* Long-term maintenance: work you'll maintain and evolve

### When to Choose rpi-agent

* Clear scope: straightforward feature or bug fix
* Minimal research: codebase-only investigation
* Quick iteration: active development with fast feedback loops
* Exploratory or prototype work

### Escalation Path

Start with rpi-agent for speed. If the task reveals hidden complexity, rpi-agent can hand off to Task Researcher. The Review phase can also trigger escalation. This hybrid approach avoids premature commitment to either workflow.

Source: [docs/rpi/why-rpi.md](docs/rpi/why-rpi.md) Lines 130-172, [docs/rpi/using-together.md](docs/rpi/using-together.md) Lines 330-367

## When to Use RPI vs Quick Edits

| Use RPI When... | Use Quick Edits When... |
|----------------|------------------------|
| Changes span multiple files | Fixing a typo |
| Learning new patterns/APIs | Adding a log statement |
| External dependencies involved | Refactoring < 50 lines |
| Requirements are unclear | Change is obvious |

**Rule of Thumb:** If you need to understand something before implementing, use RPI.

Source: [docs/rpi/README.md](docs/rpi/README.md) Lines 82-90

## Learning Curve and Compounding Value

The documentation is candid: **the first RPI workflow feels slower.** You're learning the process, building muscle memory for context clearing, and adjusting to phase handoffs.

By the third feature, the workflow feels natural:

* The research phase accelerates because you know what questions to ask.
* The planning phase tightens because you recognize the right level of detail.
* Implementation becomes almost mechanical — following verified patterns rather than inventing them.

**The compounding effect:** Research documents accumulate into institutional memory. New team members read how past decisions were made. Patterns get documented once and referenced forever. The value isn't just in the current task — it's in every future task that touches the same area.

Source: [docs/rpi/why-rpi.md](docs/rpi/why-rpi.md) Lines 114-125

## Walkthrough Example: Azure Blob Storage Integration

The documentation includes a complete end-to-end walkthrough adding Azure Blob Storage to a Python data pipeline.

### Phase 1 — Research

Prompt: `/task-research Azure Blob Storage integration for Python data pipeline`

Topics investigated: Azure SDK for Python blob storage options, authentication approaches (managed identity vs connection string), streaming uploads for files > 1GB, error handling and retry patterns. Focus: match existing patterns in the codebase.

Output: `.copilot-tracking/research/2025-01-28-blob-storage-research.md` with key findings — recommended `azure-storage-blob` SDK with async streaming, managed identity for production, existing `WriterBase` class pattern discovered in `src/pipeline/writers/base.py`.

### Phase 2 — Plan

After `/clear`, invoke `/task-plan` with research file open.

Output: Plan with three phases (Storage Client Setup → Writer Implementation → Integration), two coordinated files (plan + details), checkboxes for each task.

### Phase 3 — Implement

After `/clear`, invoke `/task-implement`.

Stop controls enabled (`phaseStop=true`). After each phase: review changes, run linters, continue. Final output: 3 files created, 2 files modified, changes log produced.

### Phase 4 — Review

After `/clear`, invoke `/task-review`.

Result: 0 Critical, 0 Major, 2 Minor findings (missing docstring, configuration suggestion), 1 follow-up item (performance benchmarks deferred). Status: ready for commit.

Source: [docs/rpi/using-together.md](docs/rpi/using-together.md) Lines 40-190

## Artifact Summary

| Artifact | Location | Purpose |
|----------|----------|---------|
| Research | `.copilot-tracking/research/` | Evidence and recommendations |
| Plan | `.copilot-tracking/plans/` | Checkboxes and phases |
| Details | `.copilot-tracking/details/` | Task specifications |
| Changes | `.copilot-tracking/changes/` | Change log |
| Review | `.copilot-tracking/reviews/` | Validation findings |
| Code | Source directories | Working implementation |

## rpi-agent Orchestrator Details

The `rpi-agent.agent.md` defines a 5-phase autonomous orchestrator (Research → Plan → Implement → Review → Discover) that uses `runSubagent` to dispatch specialized task agents.

Key capabilities:

* **Three autonomy modes:** Full autonomy ("keep going"), Partial (default — continue obvious items, present options when unclear), Manual ("ask me")
* **Intent detection:** Continuation signals ("do 1", "option 2"), Discovery signals ("what's next"), Autonomy changes
* **Subagent dispatch:** Each phase dispatches to the corresponding `task-*.agent.md` via `runSubagent`
* **Handoff buttons:** Numbered options (1, 2, 3), "All", "Suggest", "Auto", "Save"
* **Requires `runSubagent` tool** — falls back to strict RPI when unavailable

Source: [.github/agents/rpi-agent.agent.md](.github/agents/rpi-agent.agent.md) Lines 1-100

## Identified Gaps

1. **No quantitative metrics:** The quality comparison is qualitative ("frequent" vs "rare" rework). No measured data on time savings, defect reduction rates, or rework percentages.
2. **Duration estimates are approximate:** Task Researcher states "20-60 minutes" but no guidance on what affects duration (codebase size, topic complexity, tool availability).
3. **No failure mode documentation:** The docs describe what happens when RPI succeeds but don't catalog common failure scenarios (tool unavailable, research inconclusive, plan-implementation mismatch).
4. **Handoff button availability unclear:** Documentation mentions handoff buttons ("when available") without specifying what VS Code version or extension state enables them.
5. **rpi-agent coverage limited:** Only first 100 lines of the 302-line agent file were reviewed; later phases (Implement, Review, Discover) and edge handling may contain additional presentation-relevant content.

## Presentation-Ready Findings

### Top 5 Impactful Points

1. **The Counterintuitive Insight:** Constraining AI from implementing during research *improves* implementation quality. The constraint changes the optimization target from "plausible code" to "verified truth."

2. **The Type Transformation Pipeline:** `Uncertainty → Knowledge → Strategy → Working Code → Validated Code` — each phase produces a typed artifact that becomes the mandatory input for the next. Skipping phases means operating on the wrong type.

3. **The /clear Rule as Architecture:** Context clearing between phases isn't a convenience — it's a structural requirement that prevents context contamination, the primary failure mode of single-session AI workflows.

4. **Compounding Value Over Time:** Research documents accumulate into institutional memory. The third RPI workflow is faster than the first. Patterns documented once get referenced forever.

5. **The Escalation Path:** You don't have to decide upfront. Start with rpi-agent for speed, escalate to strict RPI when complexity emerges. The Review phase can trigger iteration back to any earlier phase.
