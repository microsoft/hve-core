---
description: "Plan an Azure DevOps sprint by analyzing iteration coverage, capacity, dependencies, and backlog gaps"
agent: ADO Backlog Manager
argument-hint: "project=... iteration=... [documents=...] [capacity=...] [autonomy={full|partial|manual}]"
---

# Plan ADO Sprint

Analyze an Azure DevOps iteration, assess work item coverage against Area Paths and optional planning documents, and produce a prioritized sprint plan with gap analysis and dependency awareness.

Follow all instructions from #file:../../instructions/ado/ado-backlog-sprint.instructions.md for sprint planning workflows, coverage analysis, and capacity tracking.
Follow all instructions from #file:../../instructions/ado/ado-wit-planning.instructions.md for shared conventions, planning file templates, and field definitions.

## Inputs

* `${input:project}`: (Required) Azure DevOps project name.
* `${input:iteration}`: (Required) Target iteration name or path for the sprint.
* `${input:documents}`: (Optional) File paths or URLs of source documents (PRDs, RFCs) for cross-referencing against iteration work items.
* `${input:sprintGoal}`: (Optional) Sprint goal or theme description to focus prioritization.
* `${input:capacity}`: (Optional) Team capacity or story point limit for the sprint.
* `${input:contentFormat:Markdown}`: (Optional) Content format for rich-text fields in planning files. Use `Markdown` for Azure DevOps Services (dev.azure.com) or `Html` for Azure DevOps Server (on-premises). Defaults to Markdown.

## Requirements

* Resolve `${input:iteration}` and verify it exists before fetching work items.
* When `${input:documents}` is provided, cross-reference extracted requirements against iteration work items and identify coverage gaps.
* When `${input:capacity}` is provided, include only top-ranked items up to the capacity limit.
* Prioritize `${input:sprintGoal}`-aligned items when a sprint goal is provided.
* Write planning artifacts to `.copilot-tracking/workitems/sprint/{{iteration-kebab}}/`.
* When the iteration contains no work items, suggest running discovery via *ado-discover-work-items.prompt.md*.
* When excessive unclassified items are found, recommend triage via *ado-triage-work-items.prompt.md* before sprint planning.

---

Proceed with planning the sprint for the specified iteration following the sprint planning workflow instructions.
