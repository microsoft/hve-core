---
description: "Analysis report structure and analyze-only contract for the prompt-analyze skill"
---

# Analysis Report Template

Use this structure to synthesize `Prompt Tester` execution output and `Prompt Evaluator` findings into a concise durable report. The shared execution contract is centralized in the `prompt-builder` skill; this reference adds the analyze-only scope, report structure, and local evidence model from [evidence-and-outcome-contract.md](evidence-and-outcome-contract.md).

## Sandbox, report, and dispatch contract

Derive the sandbox folder and dispatch `Prompt Tester` and `Prompt Evaluator` using the `prompt-builder` skill sandbox contract and subagent dispatch matrix. The selected sandbox folder uses `{{YYYY-MM-DD}}-{{topic}}-{{run-number}}` under `.copilot-tracking/sandbox/` or a caller-owned sandbox root. Write the execution log and evaluation log inside that sandbox folder.

Reuse the same `{{topic}}` and `{{run-number}}` derivation to write the consolidated Analysis Report to `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{topic}}-{{run-number}}-analysis.md`, where `{{run-number}}` matches the sandbox run number so repeated same-day analyses never overwrite prior reports. Start the durable report with `<!-- markdownlint-disable-file -->`. This durable report lives outside the sandbox and survives sandbox cleanup.

The analysis stays read-only with respect to the analyzed artifacts. This skill dispatches only `Prompt Tester` and `Prompt Evaluator`, never `Researcher Subagent` or `Prompt Updater`. Sandbox-only tests record durable-report writes as allowed, emulated, or deferred according to parent test constraints. Sandbox cleanup must not remove the durable Analysis Report.

## Analysis Report Template

### Executive Summary

Open with a short summary that lets the reader understand the result without scanning the full report.

Include:

* Quality outcome: Pass, Pass with notes, Needs changes, Blocked, or Failed
* Run completeness: Complete, Partial, Blocked, or Failed
* Top findings: count by Critical, High, Medium, and Low severity
* Highest-priority recommendations: the smallest practical next actions
* Evidence basis: execution log, evaluation log, direct artifact review, and any fallback handling used

### Purpose and Capabilities

For mixed artifact sets, include one row per analyzed artifact.

| Artifact         | Artifact type                                                    | Purpose                       | Capabilities                              |
|------------------|------------------------------------------------------------------|-------------------------------|-------------------------------------------|
| Link to artifact | Prompt, instruction, agent, skill, reference, template, or other | Intended role in one sentence | Main user-facing or workflow capabilities |

### Per-Artifact Outcomes

Use the outcome fields from [evidence-and-outcome-contract.md](evidence-and-outcome-contract.md). Include every target artifact, even when no issues are found.

| Artifact         | Artifact type                                                    | Evaluation outcome                                              | Key evidence                                                | Next action                |
|------------------|------------------------------------------------------------------|-----------------------------------------------------------------|-------------------------------------------------------------|----------------------------|
| Link to artifact | Prompt, instruction, agent, skill, reference, template, or other | Pass, Pass with notes, Needs changes, Blocked, or Not evaluated | Most important passing evidence, issue evidence, or blocker | Follow-up action or `None` |

### Strengths

List concrete strengths separately from issues. Tie each strength to artifact evidence, execution behavior, or evaluator findings.

### Severity-Graded Findings

Group findings by Critical, High, Medium, then Low. Normalize incoming critical, major, and minor wording into this taxonomy before writing the durable report.

Each finding includes:

| Field                      | Content                                                                                                                         |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Artifact                   | Workspace-relative markdown link to the affected artifact                                                                       |
| Criterion or contract area | Failed Prompt Quality Criteria item, Prompt Design Principles item, analyze-only contract area, or local evidence contract area |
| Severity                   | Critical, High, Medium, or Low                                                                                                  |
| Evidence                   | Specific artifact text, execution-log finding, evaluation-log finding, or observed behavior                                     |
| Impact                     | Why the issue matters                                                                                                           |
| Recommendation             | Smallest practical next action                                                                                                  |

Use `None` when no findings exist for a severity.

### Non-Issue Improvement Opportunities

Use this section for optional improvements that do not fail the Prompt Quality Criteria or local contracts. Keep them separate from severity-graded findings and label them as optional.

### Quality Assessment

Summarize which Prompt Quality Criteria passed, failed, or were not applicable. Note cross-artifact patterns, missing evidence, and any fallback handling from the evidence contract.

If no issues are found, include this exact line:

✅ Quality Assessment Passed - This prompt meets all Prompt Quality Criteria.

### Sandbox and Retention Notes

State where execution and evaluation logs were written during the run. State that the durable Analysis Report was written under `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/` and survives sandbox cleanup. If sandbox-only test constraints affected durable-report writes, record whether the write was allowed, emulated, or deferred.

### Evaluated Artifacts and Report

Place this section near the end of the response so the user can navigate to the durable report and every analyzed artifact. Format each entry as a proper markdown link using the file's workspace-relative path, and never wrap the path in backticks.

* Analysis report(s): one link per durable Analysis Report written under `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/`.
* Evaluated artifacts: one link per analyzed file, labeled by artifact type.

Example layout:

```markdown
* Analysis report: [.copilot-tracking/reviews/logs/2026-01-13/git-commit-001-analysis.md](.copilot-tracking/reviews/logs/2026-01-13/git-commit-001-analysis.md)
* Evaluated artifacts:
  * Prompt: [.github/prompts/hve-core/git-commit-message.prompt.md](.github/prompts/hve-core/git-commit-message.prompt.md)
  * Instruction: [.github/instructions/hve-core/commit-message.instructions.md](.github/instructions/hve-core/commit-message.instructions.md)
```

> Brought to you by microsoft/hve-core
