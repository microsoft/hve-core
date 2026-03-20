---
description: "Triage untriaged Azure DevOps work items with field classification, iteration assignment, and duplicate detection"
agent: ADO Backlog Manager
argument-hint: "project=... [areaPath=...] [maxItems=20] [autonomy={full|partial|manual}]"
---

# Triage ADO Work Items

Fetch work items in `New` state with incomplete classification, analyze each for field recommendations, detect duplicates, and produce a triage plan for review before execution.

Follow all instructions from #file:../instructions/ado-backlog-triage.md while executing this workflow.
Follow all instructions from #file:../instructions/ado-wit-planning.md for shared conventions, planning file templates, and field definitions.

## Inputs

* `${input:project}`: (Required) Azure DevOps project name.
* `${input:areaPath}`: (Optional) Area Path filter to scope triage to a specific area of the backlog.
* `${input:iterationPath}`: (Optional) Target iteration for assignment when classifying work items.
* `${input:maxItems:20}`: (Optional, defaults to 20) Maximum work items to process per batch.
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates. Values: `full`, `partial`, `manual`.
* `${input:contentFormat:Markdown}`: (Optional) Content format for rich-text fields written during triage. Use `Markdown` for Azure DevOps Services (dev.azure.com) or `Html` for Azure DevOps Server (on-premises). Defaults to Markdown.

## Requirements

* Scope searches to `${input:project}` and apply `${input:areaPath}` when provided.
* Limit fetched items to `${input:maxItems}`.
* Apply `${input:iterationPath}` as the default target iteration when provided.
* Record triage artifacts in `.copilot-tracking/workitems/triage/{{YYYY-MM-DD}}/`.
* When no untriaged items are found, inform the user and suggest broadening search criteria.

---

Proceed with triaging untriaged Azure DevOps work items following the triage workflow instructions.
