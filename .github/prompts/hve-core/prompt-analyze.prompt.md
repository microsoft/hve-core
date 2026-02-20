---
description: "Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core"
agent: 'prompt-builder'
argument-hint: "[promptFiles=...]"
---

# Prompt Analyze

## Inputs

* (Optional) promptFiles - ${input:promptFiles}: Existing target prompt file(s) for creation or modification. Defaults to the current open file or attached file.

## Analysis Report

Compile the *evaluation-log* results into this report structure:

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

When issues are found:

* Present the analysis report with all sections.
* Highlight the most impactful issues that should be addressed first.
* Provide a count of issues by severity.

When no issues are found:

* Present the purpose and capabilities section.
* Display: ✅ **Quality Assessment Passed** - This prompt meets all Prompt Quality Criteria.
* Summarize the criteria validated.

## Required Steps

1. Follow all instructions from Step 1 and Step 2 in Phase 1: Prompt File(s) Execution and Evaluation to completion.
2. Do not continue on to other phases past Phase 1.
3. Read all of and interpret the *evaluation-log* and the response from prompt-evaluator.
4. Format the Analysis Report for your response to the user.
