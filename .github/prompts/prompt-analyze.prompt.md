---
description: "Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core"
argument-hint: "file=..."
---

# Prompt Analyze

This prompt evaluates prompt engineering artifacts against the Prompt Quality Criteria defined in the prompt-builder protocol. The analyzer dispatches subagents to understand the target prompt's intent and validate it against all quality requirements, then reports findings without modifying the target file.

## Inputs

* ${input:file}: (Required) Target prompt file to analyze. Accepts `.prompt.md`, `.chatmode.md`, `.agent.md`, or `.instructions.md` files.

## Required Steps

Follow each step in order. Read the prompt-builder instructions at `.github/instructions/prompt-builder.instructions.md` before beginning analysis.

### Step 1: Load Target and Instructions

Read the target file at `${input:file}` along with the prompt-builder instructions to establish the evaluation baseline:

* Capture the full content of the target file for analysis.
* Identify the file type from the extension to determine applicable validation rules.
* Note the frontmatter fields present and their values.

### Step 2: Dispatch Execution Analysis Subagent

Use `runSubagent` to analyze what the target prompt does. When `runSubagent` is unavailable, perform this analysis directly.

Provide the subagent with these instructions:

* Read the target file content and identify its purpose.
* Determine the intended workflow: single-session, conversational, or autonomous.
* Catalog the main capabilities and features the prompt provides.
* Identify any protocols, phases, or steps defined in the file.
* Note input variables and their purposes.
* Return a structured summary covering purpose, workflow type, capabilities, and structure.

### Step 3: Dispatch Evaluation Subagent

Use `runSubagent` to validate the target against all Prompt Quality Criteria. When `runSubagent` is unavailable, perform this evaluation directly.

Provide the subagent with these instructions:

* Read the prompt-builder instructions at `.github/instructions/prompt-builder.instructions.md`.
* Read the writing-style instructions at `.github/instructions/writing-style.instructions.md`.
* Evaluate the target file against each item in the Prompt Quality Criteria checklist.
* Check writing style compliance against the Prompt Writing Style section.
* Validate key criteria: clarity, consistency, alignment, coherence, calibration, correctness.
* Verify few-shot examples are in fenced code blocks and match instructions exactly.
* Confirm file structure follows the appropriate file type guidelines.
* Validate protocol patterns if protocols are present.
* Return findings as a list with severity (critical, major, minor), category (research gap, implementation issue), description, and suggested fix.

### Step 4: Format Analysis Report

Compile results from both subagents into a structured report with these sections:

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

### Step 5: Deliver Verdict

When issues are found:

* Present the analysis report with all sections.
* Highlight the most impactful issues that should be addressed first.
* Provide a count of issues by severity.

When no issues are found:

* Present the purpose and capabilities section.
* Display: ✅ **Quality Assessment Passed** - This prompt meets all Prompt Quality Criteria.
* Summarize the criteria validated.

---

Proceed with analysis of the target file following the Required Steps.
