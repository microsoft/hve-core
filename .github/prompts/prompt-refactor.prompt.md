---
description: "Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core"
argument-hint: "file=..."
agent: 'prompt-builder'
---

# Prompt Refactor

## Inputs

* ${input:file}: (Required) Target prompt file to refactor. Accepts `.prompt.md`, `.agent.md`, or `.instructions.md` files.
* ${input:requirements}: (Optional) Additional refactoring requirements or focus areas.

## Required Steps

Act as an agent orchestrator. Follow the Required Phases from the mode instructions, dispatching subagents for all phase work. Apply these refactoring-specific requirements throughout the protocol:

* Remove or condense redundant instructions while preserving intent.
* Replace verbose examples with concise instruction lines where examples are not essential.
* Update outdated prompting patterns to follow current Prompt Writing Style.
* Correct any schema, API, SDK, or tool call instructions based on research findings.

### Step 1: Baseline and Research

Follow the mode's Phase 1 (Baseline) and Phase 2 (Research) to evaluate the current state and verify external references in the target file at `${input:file}`.

### Step 2: Refactor

Follow the mode's Phase 3 (Build) to apply compression and cleanup changes along with any user-provided `${input:requirements}`.

### Step 3: Validate and Iterate

Follow the mode's Phase 4 (Validate) and Phase 5 (Iterate) until all Prompt Quality Criteria pass.

### Step 4: Report Outcomes

After validation passes, summarize the refactoring session:

* Changes made with file paths.
* Instructions removed, compressed, or updated.
* Schema, API, or tool call corrections applied.
* Prompt Quality Criteria validation results.

---

Follow the Required Phases from the mode instructions, dispatching subagents for all phase work, and proceed with refactoring the target file.
