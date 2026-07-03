---
name: prompt-analyze
description: 'Execute prompt evaluation for existing prompt artifacts and produce an analysis report without modifying files.'
argument-hint: "[promptFiles=...]"
license: MIT
user-invocable: true
---

# Prompt Analyze Skill

This skill runs only the execution-and-evaluation phase from the `prompt-builder` skill. It uses `Prompt Builder` workflow concepts, dispatches only `Prompt Tester` and `Prompt Evaluator`, evaluates artifacts against the Prompt Design Principles and Prompt Quality Criteria section in `prompt-builder.instructions.md`, and writes a durable Analysis Report without modifying analyzed source artifacts.

The prompt-analyze capability can be reached through the `/prompt-analyze` slash prompt or semantic skill intent. In skill-driven execution, this skill package owns the analyze-only boundary, durable-report requirement, read-only source boundary, severity normalization, and report structure in [references/analysis-report-template.md](references/analysis-report-template.md) and [references/evidence-and-outcome-contract.md](references/evidence-and-outcome-contract.md).

## Goal

Execute only the analysis phase for existing prompt-engineering artifacts: run the target artifacts in a sandbox when executable, evaluate them against the Prompt Design Principles and the Prompt Quality Criteria section in `prompt-builder.instructions.md`, write a durable Analysis Report, and return markdown links to that report and to every evaluated artifact. This skill is read-only with respect to analyzed artifacts; its only writes are sandbox execution/evaluation logs and the durable Analysis Report.

## Flow

1. Confirm the target prompt-engineering file(s) and derive the sandbox folder using the `prompt-builder` skill sandbox naming contract: selected sandbox root plus `{{YYYY-MM-DD}}-{{topic}}-{{run-number}}`. Derive `{{topic}}` from the primary artifact, using the parent folder for `SKILL.md` or the artifact basename with the suffix stripped for prompt, instruction, and agent files.
2. Name the durable Analysis Report `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{topic}}-{{run-number}}-analysis.md`, where `{{run-number}}` matches the sandbox run number so same-day analyses never overwrite prior reports. When a caller supplies a run folder or evidence root, mirror sandbox evidence there only after applying the `prompt-builder` caller-root validation and disclosure rules. Keep the durable Analysis Report under `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/` unless the caller explicitly provides a durable report path that passes the same root validation.
3. Dispatch `Prompt Tester` to execute the target artifacts literally inside the sandbox and write an execution log. When artifacts are not directly executable, have `Prompt Tester` record the executable boundary and any sandbox-only test constraints instead of modifying source files. When the only input is `promptFiles`, default the purpose, requirements, and expectations to "evaluate the target artifact(s) against the Prompt Quality Criteria."
4. Dispatch `Prompt Evaluator` to review the execution log and target artifacts against the Prompt Quality Criteria section in `prompt-builder.instructions.md`, the analyze-only contract, and the local evidence contract. Require Critical, High, Medium, and Low severity output; normalize incoming critical, major, and minor wording into that taxonomy in the durable report.
5. Read the execution log and evaluation log, apply [references/evidence-and-outcome-contract.md](references/evidence-and-outcome-contract.md), and synthesize the Analysis Report using [references/analysis-report-template.md](references/analysis-report-template.md). Include fallback handling for missing, contradictory, blocked, or incomplete subagent output.
6. Write the report to the durable path from step 2, present it inline as the final response, and stop. Do not continue into research, build, refactor, or modification behavior.
7. Clean up sandbox files and folders created for the run before the final response unless the user asks to keep them. The cleanup boundary excludes the durable Analysis Report and any caller-approved tracking evidence outside the sandbox.

## Inputs

* `promptFiles` (optional): Existing prompt, instruction, agent, skill, reference, template, or related prompt-engineering artifact(s) to analyze. If omitted, use the current open or attached file(s).

## Success criteria

* An Analysis Report is written to `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{topic}}-{{run-number}}-analysis.md` and presented inline in the final response using the template structure.
* The report faithfully reflects the execution and evaluator findings, including any fallback handling from the local evidence contract.
* The report includes per-artifact purpose, capabilities, outcome, severity-graded findings, strengths, quality assessment, and evaluated artifact/report links.
* The final response ends with an Evaluated Artifacts and Report section containing valid workspace-relative markdown links to every durable Analysis Report and to each evaluated artifact.
* The run halts after Phase 1 with no modifications to the analyzed artifacts.

## Constraints

* Remain read-only with respect to the analyzed artifacts: never edit the target artifacts.
* Writing the sandbox execution log and evaluation log, and the durable Analysis Report under `.copilot-tracking/reviews/logs/`, is allowed and expected; the durable report stays outside the sandbox so it survives sandbox cleanup.
* Do not enter research or modification phases. Do not add `Researcher Subagent` or `Prompt Updater` to normal prompt-analyze execution.
* Keep execution and evaluation logs inside the selected sandbox during the run. In sandbox-only tests, record durable-report writes as allowed, emulated, or deferred according to the parent test constraints.
* Format every artifact and report reference as a proper markdown link using its workspace-relative path; never present these references as bare paths or wrap them in backticks.
* Normalize severity in the durable report to Critical, High, Medium, and Low. Map incoming critical, major, and minor wording into this taxonomy before reporting.
* Follow the subagent dispatch contract exactly and keep the response concise and evidence-first.

## Stop rules

* Hard stop if the target files or sandbox context cannot be determined.
* Stop if the Analysis Report cannot be produced.
* Stop after the evaluation phase completes; do not continue to later prompt-builder phases.
* Apply the `prompt-builder` skill cleanup contract to the sandbox before the final response; preserve the durable Analysis Report under `.copilot-tracking/reviews/logs/`.

## Handoff

If follow-up changes are needed, recommend `/prompt-builder` or `/prompt-refactor` briefly, referencing the issues identified in the Analysis Report.

## Final response contract

Present the Analysis Report inline as the final response using the template structure, then add, in order:

* The executive summary with run completeness, quality outcome, top findings, and highest-priority recommendations.
* Per-artifact purpose, capabilities, and outcomes.
* Strengths, severity-graded findings, non-issue improvement opportunities, and quality assessment.
* An Evaluated Artifacts and Report section near the end that lists, as proper workspace-relative markdown links, every durable Analysis Report and each evaluated artifact, labeled by artifact type.
* The recommended next action.


