---
description: 'PRD story-quality reference - the six INVEST attributes (Independent, Negotiable, Valuable, Estimable, Small, Testable) described in original Microsoft prose with cite-only attribution to Bill Wake; applied during functional-requirement decomposition into stories and epics'
---

# INVEST Story-Quality Reference

INVEST is a six-attribute checklist for judging whether a user story is well formed. The PRD Builder applies it when decomposing functional requirements into stories or epics during the Build and Integrate phases. The guidance below is original HVE-Core prose; the INVEST acronym is attributed by name to its author.

## The six attributes

| Letter | Attribute   | What the PRD Builder checks                                                                                                                                          |
|--------|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| I      | Independent | The story can be scheduled and delivered without a hard ordering dependency on another story. Overlapping stories are merged or re-sliced so each can stand alone.   |
| N      | Negotiable  | The story captures intent, not a frozen contract. Implementation detail is left open for the delivery team to refine with the product owner.                         |
| V      | Valuable    | The story delivers observable value to a user or buyer. Pure technical tasks are reframed to express the value they unlock or are folded into a value-bearing story. |
| E      | Estimable   | The team has enough shared understanding to size the story. Unestimable stories signal a missing spike, an unstated assumption, or excessive scope.                  |
| S      | Small       | The story fits within a single iteration. Stories that span iterations are split along workflow steps, data variations, or acceptance scenarios.                     |
| T      | Testable    | The story has acceptance criteria that can be objectively verified. Untestable stories lack a definition of done and are returned for acceptance authoring.          |

## How the PRD Builder uses INVEST

* During functional-requirement decomposition, each candidate story is scored pass/fail against all six attributes.
* A failing attribute is a coaching trigger, not an automatic block — the PRD Builder names the attribute and proposes a concrete re-slice or clarification.
* "Small" and "Testable" failures are the most common; the PRD Builder pairs them with the vertical-slice rubric in [mvp-framing.md](mvp-framing.md) and the acceptance patterns in [ears-acceptance.md](ears-acceptance.md).
* INVEST complements the requirement-level quality rubric: ISO 29148 attributes judge an individual requirement statement, while INVEST judges a deliverable story's shape and schedulability.

## Relationship to other references

* For the user-story sentence form, see [connextra-template.md](connextra-template.md).
* For acceptance-criteria authoring, see [ears-acceptance.md](ears-acceptance.md) and the shared [given-when-then.md](../_shared/given-when-then.md).
* For prioritization of stories within a release, see the shared [prioritization-schemes.md](../_shared/prioritization-schemes.md).

## Cite-only attribution

* **Author** — Bill Wake, *INVEST in Good Stories, and SMART Tasks*, 2003.
* **URL** — [https://xp123.com/articles/invest-in-good-stories-and-smart-tasks/](https://xp123.com/articles/invest-in-good-stories-and-smart-tasks/)
* **Why the PRD Builder cites it** — Source of the INVEST acronym for story-quality assessment. The attribute checks and coaching guidance above are repository-original; no upstream prose is reproduced.

## License

This reference file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The story-quality guidance is HVE-Core IP and may be reused under the same license. The INVEST acronym remains attributable to its author; the source is accessed by the reader through the cited URL and is never redistributed here.


