---
description: 'Scrum decomposition lens for translating PRD scope into an epic, story, and sprint-oriented work item hierarchy'
---

<!-- markdownlint-disable-file -->
# Scrum Decomposition Lens

Scrum decomposition lens for the [functional-planner](../../SKILL.md) skill. This file paraphrases the product-backlog and increment concepts from the Scrum Guide; it does not reproduce the Guide's text. Source: The Scrum Guide (2020), Ken Schwaber and Jeff Sutherland, <https://scrumguides.org/>, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

## When to Use

Use this lens when the team plans with a Scrum product backlog and delivers value in Sprints. It frames the PRD as backlog items ordered by value and refined progressively.

## Decomposition Approach (paraphrased)

* **Product goal → top level.** Treat each major product outcome as a larger backlog item (commonly modeled as an Epic on the platform) that advances a product goal.
* **Product Backlog Items → deliverable level.** Decompose each outcome into Product Backlog Items — the smallest independently valuable, orderable units the team can plan into a Sprint (Stories on the platform).
* **Refinement → progressive detail.** Add detail, acceptance criteria, and order to items as they near a Sprint; leave larger, further-out items coarser. Model this as `needs_review` or coarser leaf items rather than over-specifying distant work.
* **Definition of Done.** Express the PRD's acceptance criteria as the per-item completion conditions so each item is releasable when done.

## Boundaries

* This lens shapes ordering and progressive refinement; it does not change the platform's validated type names or parent rules. Defer those to the platform reference ([ado.md](../ado.md), [github.md](../github.md), or [jira.md](../jira.md)).
* Keep items independently valuable and orderable; avoid dependency chains that prevent independent delivery.

## Attribution

Paraphrased from The Scrum Guide (2020), © Ken Schwaber and Jeff Sutherland. Offered under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Official source: <https://scrumguides.org/>. This file is a paraphrase, not a reproduction; consult the official Guide for authoritative definitions.
