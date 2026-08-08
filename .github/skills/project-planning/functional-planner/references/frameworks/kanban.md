---
description: 'Kanban decomposition lens for translating PRD scope into a flow-oriented work item hierarchy'
---

<!-- markdownlint-disable-file -->
# Kanban Decomposition Lens

Kanban decomposition lens for the [functional-planner](../../SKILL.md) skill. This file paraphrases flow and right-sizing concepts from the Kanban Guide; it does not reproduce the Guide's text. Source: The Kanban Guide (May 2025), <https://kanbanguides.org/english/>, © Orderly Disruption Limited and Daniel S. Vacanti, Inc.

The Guide states its license inconsistently: its preface offers the publication under Attribution-ShareAlike, while its License section states Attribution 4.0 International. This file follows the more restrictive of the two and treats the content as [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

## When to Use

Use this lens when the team plans by flow and continuous delivery rather than a fixed multi-level hierarchy. It frames the PRD as a stream of right-sized work items that move through a workflow.

## Decomposition Approach (paraphrased)

* **Flow over hierarchy.** Prefer a shallow structure: a small number of grouping items (for example, Epics for major outcomes) over a flat stream of independently deliverable work items, rather than deep nesting.
* **Right-sizing.** Split each requirement into items small enough to flow smoothly and predictably; avoid items so large they stall the workflow. Model an oversized requirement as multiple leaf items instead of one broad item.
* **Explicit, testable completion.** Give each item explicit completion criteria drawn from the PRD's success criteria so its readiness to move through the workflow is unambiguous.
* **Limit work in progress conceptually.** Sequence the plan so the most valuable, ready items are surfaced first; defer speculative items as `needs_review` rather than fully specifying them now.

## Boundaries

* This lens shapes right-sizing and sequencing; it does not change the platform's validated type names or parent rules. Defer those to the platform reference ([ado.md](../ado.md), [github.md](../github.md), or [jira.md](../jira.md)).
* Keep the hierarchy shallow; do not manufacture intermediate levels the platform or PRD does not need.

## Attribution

Paraphrased from The Kanban Guide (May 2025), © Orderly Disruption Limited and Daniel S. Vacanti, Inc. Treated as [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), the more restrictive of the two licenses the Guide states for itself. Official source: <https://kanbanguides.org/english/>. This file is a paraphrase, not a reproduction; consult the official Guide for authoritative definitions.
