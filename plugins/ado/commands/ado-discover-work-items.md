---
description: "Discover Azure DevOps work items through user-centric queries, artifact-driven analysis, or search-based exploration"
agent: ADO Backlog Manager
argument-hint: "project=... [documents=...] [searchTerms=...]"
---

# Discover ADO Work Items

Classify the discovery path based on user intent, execute the appropriate discovery workflow, assess similarity against existing work items, and produce planning files. Three discovery paths are supported: user-centric queries (Path A), artifact-driven analysis from documents (Path B), and search-based exploration (Path C).

Follow all instructions from #file:../instructions/ado-wit-discovery.md while executing this workflow.
Follow all instructions from #file:../instructions/ado-wit-planning.md for shared conventions, planning file templates, and field definitions.

## Inputs

* `${input:project}`: (Required) Azure DevOps project name.
* `${input:documents}`: (Optional) Document paths for artifact-driven analysis. Triggers Path B when provided.
* `${input:searchTerms}`: (Optional) Keywords for search-based discovery. Triggers Path C when provided without documents.
* `${input:areaPath}`: (Optional) Area Path filter to scope discovery.
* `${input:iterationPath}`: (Optional) Iteration Path filter to scope discovery.
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates during handoff review. Values: `full`, `partial`, `manual`.
* `${input:contentFormat:Markdown}`: (Optional) Content format for rich-text fields in planning files. Use `Markdown` for Azure DevOps Services (dev.azure.com) or `Html` for Azure DevOps Server (on-premises). Defaults to Markdown.

## Requirements

* Classify the discovery path before executing any searches or document parsing.
* Scope all searches to `${input:project}` and apply `${input:areaPath}` and `${input:iterationPath}` filters when provided.
* Path B produces planning artifacts in `.copilot-tracking/workitems/discovery/{{scope-name}}/` including *artifact-analysis.md*, *work-items.md*, and *handoff.md*. Use `${input:contentFormat}` for fenced code block annotations in *work-items.md* multi-line field values. When input contains formal PRD or requirements documents, the orchestrator routes to `AzDO PRD to WIT` instead of this path.
* Paths A and C produce a *planning-log.md* and a conversational summary without creating a handoff.
* Discovery does not execute work item operations. The handoff is presented for review before any execution occurs.
* When neither documents nor search terms are provided and user intent is unclear, ask for clarification before proceeding.

---

Proceed with discovering Azure DevOps work items following the discovery workflow instructions.
