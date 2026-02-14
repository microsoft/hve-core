---
description: "Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core"
agent: 'prompt-builder'
argument-hint: "file=..."
---

# Prompt Analyze

## Inputs

* ${input:file}: (Required) Target prompt file to analyze. Accepts `.prompt.md`, `.agent.md`, or `.instructions.md` files.

## Required Steps

Act as an agent orchestrator. Follow the mode instructions to run Phase 1 (Baseline) testing and evaluation against the target file. Do not modify the target file. Compile findings into a structured analysis report for the user.

### Step 1: Run Baseline Testing and Evaluation

Execute only the mode's Phase 1 (Baseline) instructions to test and evaluate the target file at `${input:file}`. Do not proceed to Phase 2 or later phases. The mode dispatches `prompt-tester` and `prompt-evaluator` subagents for this work.

### Step 2: Format Analysis Report

Compile the evaluation results into this report structure:

Purpose and Capabilities:

* State the prompt's purpose in one sentence.
* List the workflow type and key capabilities.
* Describe the protocol structure if present.

Issues Found:

* Group issues by severity: critical first, then major, then minor.
* For each issue, include the category, a concise description, and an actionable suggestion.
* Reference specific sections or line numbers when relevant.

Quality Assessment:

* Summarize which Prompt Quality Criteria passed and which failed.
* Note any patterns of concern across multiple criteria.

### Step 3: Deliver Verdict

When issues are found:

* Present the analysis report with all sections.
* Highlight the most impactful issues that should be addressed first.
* Provide a count of issues by severity.

When no issues are found:

* Present the purpose and capabilities section.
* Display: ✅ **Quality Assessment Passed** - This prompt meets all Prompt Quality Criteria.
* Summarize the criteria validated.

---

Follow the mode's Phase 1 (Baseline) instructions, dispatching subagents for testing and evaluation, then report findings to the user without modifying the target file.
