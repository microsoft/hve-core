---
description: 'Uniform work item quality conventions spanning epic, feature, user story, and task level, with an authoring and refinement loop'
---

<!-- markdownlint-disable-file -->
# Work Item Quality

Platform-agnostic quality conventions for authoring and evaluating work items at every level of a backlog hierarchy. Read this alongside the [core conventions](../SKILL.md) and the active platform reference. This file owns what makes a work item good; the platform reference owns which fields carry each part and how they render.

Quality is assessed at four levels — epic, feature, user story, and task. The dimensions below apply to all four, but what satisfies a dimension changes with the level. A discovery, triage, or execution workflow applies this reference whenever it authors item content or judges whether an existing item is ready.

## Level Vocabulary

Platforms name hierarchy levels differently. Resolve the level through the active platform reference before applying a rule; the levels themselves are constant.

| Level      | What it represents                                          | Typical horizon             |
|------------|-------------------------------------------------------------|-----------------------------|
| Epic       | A business outcome spanning multiple features               | Quarters                    |
| Feature    | A user-visible capability that delivers part of an epic     | Weeks to a release boundary |
| User story | A single beneficiary-facing change with verifiable behavior | Days to about a week        |
| Task       | An implementation step inside a story                       | Hours to days               |

A platform without a native four-level hierarchy expresses the missing levels through its own grouping mechanism. The platform reference names the mapping; never invent a level a platform does not have.

## Title Conventions

Applies at every level.

* Action-oriented phrasing; ideally starts with a verb.
* Concise and specific; a reader understands the deliverable from the title alone.
* Avoid vague language ("improve", "update", "fix things") without a concrete qualifier.

## Description Format

Use the clearest format for the context. Three patterns are acceptable at any level:

| Pattern            | When to use                 | Example                                                                                            |
|--------------------|-----------------------------|----------------------------------------------------------------------------------------------------|
| Classic user story | End-user-facing capability  | "As a reviewer, I want inline comments so that I can give feedback without leaving the diff view." |
| Goal statement     | Internal or technical work  | "Enable CSV export of user profile data for GDPR compliance."                                      |
| Problem statement  | Bug-adjacent or improvement | "Search latency exceeds 3 seconds for queries with more than 100 results."                         |

Every description states **who** benefits and in what context, **what** is broken, missing, or needed, and **why** it matters, grounded in evidence when available.

The per-level emphasis differs:

* Epic — business goal, in-scope and out-of-scope boundaries, success metrics, and dependencies.
* Feature — overview, user impact, and technical approach.
* User story — beneficiary, capability, and outcome, plus the requirements that bound it.
* Task — objective, approach, and definition of done.

The active platform reference supplies the concrete field and rendering for each of these.

## Acceptance Criteria

Acceptance criteria are binary, testable, and checklist-style.

* Write each criterion as a verifiable statement a reviewer can check without ambiguity.
* Use `- [ ]` checkbox syntax unless the platform reference specifies another rendering.
* Target 5-10 focused items per story.
* Cover these categories when applicable:
  * Functional behavior (core capability works as described).
  * Edge cases (boundary conditions, error states, empty inputs).
  * Performance (latency, throughput, or resource thresholds).
  * Observability (logging, metrics, or alerting when relevant).

Criteria belong at the level that can verify them. An epic carries success metrics rather than acceptance criteria; a feature carries acceptance criteria at capability granularity; a story carries them at behavior granularity; a task carries a definition of done. Duplicating a story's criteria onto its parent is noise, not traceability.

## Definition of Done

The Definition of Done captures team standards that apply to every deliverable beyond the item-specific acceptance criteria. Include this section when relevant standards exist.

Common items:

* Unit or integration tests cover new behavior.
* Documentation updated (API docs, guides, inline comments).
* Observability (structured logging, metrics, dashboards).
* Migration steps documented when schema or data changes are involved.
* Accessibility requirements verified when UI changes are included.

## Scope and Sizing

* Each item targets a single component or concern with clear boundaries.
* Work spanning more than one week is structured as a parent with children, each independently deliverable.
* State what is explicitly excluded to prevent scope creep.
* When an item touches multiple systems, split by system boundary.

Sizing signals that an item sits at the wrong level:

| Signal                                                     | Likely correction                |
|------------------------------------------------------------|----------------------------------|
| A story cannot be verified without splitting its criteria  | Promote to feature and decompose |
| A feature has exactly one child that restates it           | Collapse the redundant level     |
| A task carries beneficiary framing and acceptance criteria | It is a story, not a task        |
| An epic has no children after decomposition                | It is a feature, not an epic     |

## Evidence Source

Note whether each requirement comes from one of these sources:

* User research (interviews, usability studies, support tickets).
* Analytics data (usage metrics, error rates, performance traces).
* Stakeholder input (business sponsor, product owner, or team lead request).
* Assumption (team hypothesis without direct evidence).

Requirements without direct user evidence are labeled as unvalidated assumptions in the item body so reviewers understand the confidence level.

## Completeness Dimensions

Evaluate every work item against these dimensions before marking it ready:

* **User identification** — who benefits and in what context.
* **Problem statement** — what is broken or missing, grounded in evidence.
* **Evidence source** — origin of each requirement (see Evidence Source above).
* **Success criteria** — specific, measurable outcomes tied to user or business goals.
* **Acceptance criteria** — testable conditions following the Acceptance Criteria section, at the granularity the level supports.
* **Dependencies** — upstream blockers and downstream consumers identified.
* **Scope boundaries** — what is explicitly excluded to prevent scope creep.

Triage uses these dimensions as its readiness rubric. An item failing a dimension is flagged for grooming rather than silently completed, because inventing a missing requirement fabricates intent the user never stated.

## Open Questions and Risks

Include an optional section for unresolved items when the conversation surfaces them:

* Anything still unclear or requiring follow-up.
* Assumptions made during item creation.
* Items that belong in other stories or epics.
* Known risks or external dependencies.

## Authoring and Refinement Loop

Requirements rarely arrive backlog-ready. When a workflow turns functional or non-functional requirements into work items, or when a user brings a rough idea or a weak existing item, run this coaching loop before the item enters a handoff. It is conversational rather than mechanical: ask one focused question at a time, summarize the understanding, and confirm before moving on. Guide with questions and suggestions rather than lecturing.

### Mode selection

Determine whether the work is creating a new item from an idea or refining one that already exists. When refining, gather the current title, description, and acceptance criteria first.

### Create mode

1. Understand the high-level idea and context: what problem this solves and who it affects.
2. Probe intent, outcome, and beneficiaries: what success looks like once shipped.
3. Surface hidden assumptions and unknowns: technical constraints or dependencies that could change scope.
4. Determine the right level from the Level Vocabulary and the Scope and Sizing signals before writing criteria, because the level decides what kind of criteria the item carries.
5. Build acceptance criteria iteratively: which specific behaviors confirm this works.

### Refine mode

1. Review the provided content against the Completeness Dimensions.
2. Identify vague, missing, or ambiguous elements and share the observations plainly.
3. Ask targeted questions to fill gaps and make outcomes measurable: how someone would verify this is done and what they would check.
4. Re-check the level. A common defect is a story that should have been a feature, which no amount of criteria rewriting fixes.

### Exit condition

The loop ends when the user confirms the item captures their intent, the Completeness Dimensions are satisfied at the item's level, and the acceptance criteria are measurable. Unresolved gaps become Open Questions rather than guessed-at content.

## Item Output Template

Present a polished item using this structure, including optional sections when the conversation gathered relevant information. The active platform reference maps each block onto concrete fields.

```markdown
## Title

[Action-oriented title, ideally starts with a verb]

## Level

[Epic, Feature, User story, or Task]

## Description

[1-3 concise sentences in the clearest format for the context]

## Acceptance Criteria

- [ ] Verifiable statement that can be checked off
- [ ] ...

(usually 5-10 focused items; an epic carries success metrics instead)

## Definition of Done notes

*(optional)*

* Standards that always apply (tests, docs, observability, migration steps)

## Open questions, risks, and dependencies

*(optional)*

* Unresolved items, assumptions, items belonging in other stories
```

Section labels are Markdown headings rather than bold text. Bold changes appearance only, while a heading carries structure that assistive technology can navigate, and this output is frequently pasted into a tracker where that structure is what a screen-reader user relies on to move between sections.
