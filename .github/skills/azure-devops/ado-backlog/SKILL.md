---
name: ado-backlog
description: 'Plan and apply Azure Boards backlog operations in one Azure DevOps project. Use for work-item discovery, triage, iterations, PRD hierarchies, and reviewed handoffs.'
argument-hint: '[inspect|discover|my-work|task-plan|triage|sprint|resume|prd|add|run] [project] [query, item, or handoff]'
license: MIT AND CC-BY-4.0
user-invocable: true
---

# Azure DevOps Backlog

Use the [Azure Boards bindings](references/platform.md) for the target project's commands, work-item types, fields, links, search, iteration paths, and authoring templates. When another workflow requests the bindings, supply the relevant section without starting a second workflow.

For a direct request, carry the project and the supplied query, item, PRD, or handoff into the matching workflow:

* To inspect a work item or answer a bounded query, run the preflight and reads in the Azure Boards bindings. Return matching IDs and requested fields from that project; this is not a write or a planning handoff.
* For discovery, assigned work, task planning, triage, sprint planning, or resumption, use `backlog-plan` with Azure DevOps as the platform. Return the findings or local plan; do not write to the tracker.
* For a PRD, use `functional-planner` with the [Azure Boards hierarchy](references/hierarchy.md). Return a reviewable handoff, not created work items.
* For a single create (`add`) or a reviewed handoff (`run`), use `backlog-execute` with the Azure Boards bindings. Apply the destination, authorization, sanitization, and review controls in `backlog-management` before any write. Return the completed work-item IDs and any blocked operations.

For an Azure Repos pull request use `ado-pull-request`; for an Azure Pipelines build use `ado-build-info`.

The hierarchy reference retains CC-BY-4.0; the platform reference and entry point are MIT.
