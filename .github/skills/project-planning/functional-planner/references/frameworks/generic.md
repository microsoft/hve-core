---
description: 'Generic platform-native decomposition lens for translating PRD scope into a work item hierarchy without a named agile framework'
---

<!-- markdownlint-disable-file -->
# Generic Platform-Native Decomposition Lens

Default decomposition lens for the [functional-planner](../../SKILL.md) skill. This is repository-original content (Microsoft, CC BY 4.0); it describes a platform-native hierarchy without depending on any external framework.

## When to Use

Use this lens by default, and whenever the team has no specific framework preference or the PRD does not signal one. It maps a PRD to whatever hierarchy the target platform natively supports, with no additional ceremony.

## Decomposition Approach

* **Outcome to top level.** Map each major product outcome in the PRD to one top-level item (an Epic on ADO or Jira when supported; a tracking issue on GitHub).
* **Capability to middle level.** Group related requirements that deliver a coherent capability under the top level (a Feature on ADO; a Story grouping or Epic child on Jira; a sub-issue of the tracking issue on GitHub).
* **Deliverable to leaf level.** Express each independently valuable, testable slice as a leaf item (a User Story on ADO; a Story or Task on Jira; a sub-issue on GitHub), carrying acceptance criteria from the PRD's success criteria.
* **Optional work items.** Add Tasks or Bugs only when the PRD explicitly warrants them; do not manufacture leaf items to fill a level.

## Sizing and Boundaries

* Prefer the smallest hierarchy that faithfully represents the PRD; flatten a level when it adds no planning value.
* Keep each leaf item independently valuable and testable, with acceptance criteria traceable to a PRD requirement.
* Defer the concrete type names and parent rules to the platform reference ([ado.md](../ado.md), [github.md](../github.md), or [jira.md](../jira.md)); this lens only shapes how the PRD is split.

## Attribution

Repository-original content. © Microsoft, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
