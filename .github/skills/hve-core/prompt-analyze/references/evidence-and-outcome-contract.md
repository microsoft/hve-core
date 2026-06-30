---
description: "Evidence and outcome contract for prompt-analyze reports"
---

# Evidence and Outcome Contract

Use this contract when synthesizing `Prompt Tester` execution output and `Prompt Evaluator` findings into the durable Analysis Report. The contract keeps prompt-analyze reports evidence-first, comparable across runs, and useful for mixed artifact sets without adding research or modification behavior.

## Finding Fields

Every severity-graded finding in the Analysis Report includes these fields:

| Field                      | Requirement                                                                                                                                                |
|----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Artifact                   | Name the evaluated artifact and link to it with a workspace-relative markdown link.                                                                        |
| Criterion or contract area | Name the failed Prompt Quality Criteria item, Prompt Design Principles item, analyze-only contract area, or other local contract area.                     |
| Severity                   | Use Critical, High, Medium, or Low after normalizing incoming wording.                                                                                     |
| Evidence                   | Cite the specific observed behavior, artifact text, execution-log finding, or evaluation-log finding.                                                      |
| Impact                     | Explain why the issue affects prompt reliability, execution quality, user safety, maintainability, or reviewability.                                       |
| Recommendation             | Provide the smallest practical next action. Recommendations may describe follow-up work but must not perform source edits during prompt-analyze execution. |

## Per-Artifact Outcome Fields

Every evaluated artifact has one outcome row, even when it has no issues.

| Field              | Requirement                                                                   |
|--------------------|-------------------------------------------------------------------------------|
| Artifact           | Link to the evaluated artifact with a workspace-relative markdown link.       |
| Artifact type      | Classify as prompt, instruction, agent, skill, reference, template, or other. |
| Purpose            | State the artifact's intended role in one sentence.                           |
| Evaluation outcome | Use Pass, Pass with notes, Needs changes, Blocked, or Not evaluated.          |
| Key evidence       | Summarize the most important passing evidence, issue evidence, or blocker.    |
| Next action        | State the recommended follow-up, or `None` when no action is needed.          |

## Run Completeness Labels

Use one of these labels in the Analysis Report summary:

| Label    | Use When                                                                                                                                  |
|----------|-------------------------------------------------------------------------------------------------------------------------------------------|
| Complete | Prompt Tester and Prompt Evaluator both produced usable outputs, and every target artifact was evaluated.                                 |
| Partial  | Some outputs or target artifacts were evaluated, but coverage is incomplete and the usable evidence is still enough for a bounded report. |
| Blocked  | A missing target, missing sandbox context, tool failure, permission issue, or required clarification prevents reliable evaluation.        |
| Failed   | The run attempted evaluation but produced unusable or contradictory results that cannot support a report.                                 |

## Severity Normalization

Normalize all durable report findings to Critical, High, Medium, or Low.

| Incoming wording                                 | Durable report severity |
|--------------------------------------------------|-------------------------|
| Critical, blocker, blocking, must fix before use | Critical                |
| High, major, severe, significant                 | High                    |
| Medium, moderate, minor, should fix              | Medium                  |
| Low, informational, nit, optional                | Low                     |

When incoming wording conflicts with observed impact, choose the severity that matches the impact and note the normalization in the finding evidence.

## Fallback Handling

Use these fallbacks when Prompt Tester or Prompt Evaluator output is missing, contradictory, blocked, or incomplete:

| Condition                       | Required handling                                                                                                                              |
|---------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Missing Prompt Tester output    | Mark run completeness as Blocked unless direct artifact review can support a Partial report; identify the missing execution log as a blocker.  |
| Missing Prompt Evaluator output | Mark run completeness as Blocked unless direct artifact review can support a Partial report; identify the missing evaluation log as a blocker. |
| Contradictory outputs           | Prefer concrete artifact evidence over summary claims, mark the affected outcome Partial, and describe the contradiction.                      |
| Incomplete artifact coverage    | Mark unevaluated artifacts as Not evaluated, set run completeness to Partial, and list the missing coverage.                                   |
| Tool or sandbox failure         | Mark run completeness as Blocked or Failed based on whether any reliable evidence remains.                                                     |
| Sandbox-only test constraints   | Record durable-report writes as allowed, emulated, or deferred according to the parent test constraints, and keep source artifacts read-only.  |

## Retention Boundary

Execution and evaluation logs live inside the selected sandbox folder during the run. The durable Analysis Report lives under `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/` and survives sandbox cleanup. Sandbox cleanup must remove only sandbox files and folders created for the run, never the durable Analysis Report.


