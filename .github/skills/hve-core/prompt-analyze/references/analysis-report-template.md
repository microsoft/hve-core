---
description: "Analysis report structure and analyze-only contract for the prompt-analyze skill"
---

# Analysis Report Template

Use this structure to synthesize the evaluator findings into a concise report. The shared execution contract is centralized in the `prompt-builder` skill; this reference adds only the analyze-only scope and the report structure.

## Sandbox, report, and dispatch contract

Derive the sandbox folder and dispatch `Prompt Tester` and `Prompt Evaluator` using the `prompt-builder` skill's sandbox contract and subagent dispatch matrix in its orchestration reference. Write the execution log and evaluation log inside that sandbox folder. Reuse the same `{{topic}}` and `{{run-number}}` derivation to write the consolidated Analysis Report to `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{topic}}-{{run-number}}-analysis.md`, where `{{run-number}}` matches the sandbox run number so repeated same-day, same-topic analyses never overwrite a prior report, starting that file with `<!-- markdownlint-disable-file -->`; this durable report lives outside the sandbox so it survives the sandbox cleanup pass. Present the same Analysis Report inline as the final response. The analysis stays read-only with respect to the analyzed artifacts: it never modifies the artifacts it analyzes, and this skill dispatches only `Prompt Tester` and `Prompt Evaluator`, never `Researcher Subagent` or `Prompt Updater`.

## Analysis Report Template

## Purpose and Capabilities

* State the prompt's purpose in one sentence.
* List the workflow type and key capabilities.
* Describe the protocol structure if present.

## Issues Found

Group issues by severity, starting with Critical, then High, then Medium, then Low.

* Severity: Critical
  * Category:
  * Description:
  * Suggested fix:
* Severity: High
  * Category:
  * Description:
  * Suggested fix:
* Severity: Medium
  * Category:
  * Description:
  * Suggested fix:
* Severity: Low
  * Category:
  * Description:
  * Suggested fix:

When issues are found, highlight the most impactful items first and include a count by severity.

## Quality Assessment

Summarize which Prompt Quality Criteria passed and which failed, and note any patterns of concern across multiple criteria.

If no issues are found, include this exact line:

✅ Quality Assessment Passed - This prompt meets all Prompt Quality Criteria.

## Evaluated Artifacts and Report

Place this section near the end of the response so the user can navigate to the durable report and every analyzed artifact. Format each entry as a proper markdown link using the file's workspace-relative path, and never wrap the path in backticks.

* Analysis report(s): one link per durable Analysis Report written under `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/`.
* Evaluated artifacts: one link per analyzed file, labeled by artifact type (prompt, instruction, agent, or skill).

Example layout:

```markdown
* Analysis report: [.copilot-tracking/reviews/logs/2026-01-13/git-commit-001-analysis.md](.copilot-tracking/reviews/logs/2026-01-13/git-commit-001-analysis.md)
* Evaluated artifacts:
  * Prompt: [.github/prompts/hve-core/git-commit-message.prompt.md](.github/prompts/hve-core/git-commit-message.prompt.md)
  * Instruction: [.github/instructions/hve-core/commit-message.instructions.md](.github/instructions/hve-core/commit-message.instructions.md)
```
