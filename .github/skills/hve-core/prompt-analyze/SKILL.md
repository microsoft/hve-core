---
name: prompt-analyze
description: 'Execute prompt evaluation for existing prompt artifacts and produce an analysis report without modifying files.'
argument-hint: "[promptFiles=...]"
license: MIT
user-invocable: true
---

# Prompt Analyze Skill

This skill runs only the execution-and-evaluation phase (Phase 1) of the `prompt-builder` skill. Use the `prompt-builder` skill's orchestration reference for the sandbox contract, the `Prompt Tester` and `Prompt Evaluator` dispatch matrix, and the cleanup contract. This skill adds only the analyze-only scope, the durable Analysis Report it writes under `.copilot-tracking/reviews/logs/`, and the Analysis Report structure in [references/analysis-report-template.md](references/analysis-report-template.md).

## Goal

Execute only Phase 1 of the `prompt-builder` skill for existing prompt artifacts: run the target prompts in a sandbox, evaluate them against the Prompt Design Principles and the Prompt Quality Criteria in `prompt-builder.instructions.md`, write a durable Analysis Report, and return markdown links to that report and to every evaluated artifact. This skill is read-only with respect to the analyzed artifacts: it never modifies the artifacts it analyzes, and its only writes are the sandbox logs and the durable Analysis Report.

## Flow

1. Confirm the target prompt file(s) and derive the sandbox folder from the `prompt-builder` skill's sandbox contract in its orchestration reference. Reuse the same `{{topic}}` and `{{run-number}}` derivation to name the durable Analysis Report at `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{topic}}-{{run-number}}-analysis.md`, where `{{run-number}}` matches the sandbox run number so repeated same-day, same-topic analyses never overwrite a prior report.
2. Dispatch `Prompt Tester` to execute the target prompt file(s) literally inside the sandbox and write an execution log, following the dispatch matrix in the `prompt-builder` skill's orchestration reference. When the only input is `promptFiles`, default the analysis purpose/requirements/expectations to "evaluate the target artifact(s) against the Prompt Quality Criteria."
3. Dispatch `Prompt Evaluator` to review the execution log and the target files against the Prompt Quality Criteria and write an evaluation log, following the same dispatch matrix.
4. Read the evaluation log and synthesize the Analysis Report from the evaluator findings using [references/analysis-report-template.md](references/analysis-report-template.md). Write the report to the durable path from step 1, then present it inline as the final response. Stop after this phase and do not continue into research, build, or modification behavior.
5. Close the response with the Evaluated Artifacts and Report section near the end, listing a markdown link to each durable Analysis Report and to every evaluated artifact, following [references/analysis-report-template.md](references/analysis-report-template.md).

## Inputs

* `promptFiles` (optional): Existing prompt, instruction, agent, or skill artifact(s) to analyze. If omitted, use the current open or attached file(s).

## Success criteria

* An Analysis Report is written to `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{topic}}-{{run-number}}-analysis.md` and presented inline in the final response using the template structure.
* The report faithfully reflects the evaluator findings.
* The final response ends with an Evaluated Artifacts and Report section containing valid workspace-relative markdown links to every durable Analysis Report and to each evaluated artifact.
* The run halts after Phase 1 with no modifications to the analyzed artifacts.

## Constraints

* Remain read-only with respect to the analyzed artifacts: never edit the target artifacts.
* Writing the sandbox execution log and evaluation log, and the durable Analysis Report under `.copilot-tracking/reviews/logs/`, is allowed and expected; the durable report stays outside the sandbox so it survives sandbox cleanup.
* Do not enter research or modification phases.
* Format every artifact and report reference as a proper markdown link using its workspace-relative path; never present these references as bare paths or wrap them in backticks.
* Follow the subagent dispatch contract exactly and keep the response concise and evidence-first.

## Stop rules

* Hard stop if the target files or sandbox context cannot be determined.
* Stop if the Analysis Report cannot be produced.
* Stop after the evaluation phase completes; do not continue to later prompt-builder phases.
* Apply the `prompt-builder` skill's cleanup contract from its orchestration reference to the sandbox before the final response; preserve the durable Analysis Report under `.copilot-tracking/reviews/logs/`.

## Handoff

If follow-up changes are needed, recommend `/prompt-builder` or `/prompt-refactor` briefly, referencing the issues identified in the Analysis Report.

## Final response contract

Present the Analysis Report inline as the final response using the template structure (Purpose and Capabilities, Issues Found, Quality Assessment), then add, in order:
* The quality outcome (a pass, or the severity-graded issues found).
* An Evaluated Artifacts and Report section near the end that lists, as proper workspace-relative markdown links, every durable Analysis Report and each evaluated artifact (prompt, instruction, agent, or skill), labeled by artifact type.
* The recommended next action.

> Brought to you by microsoft/hve-core
