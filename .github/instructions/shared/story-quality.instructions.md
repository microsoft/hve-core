---
description: "Shared story quality conventions for work item creation and evaluation across agents and workflows"
applyTo: '**/*.agent.md, **/.github/instructions/ado/**'
---

# Story Quality Conventions

Shared conventions for creating and evaluating work items. Agents and instructions that create, refine, or assess stories reference this file as the single source of truth for quality standards.

## Title Conventions

* Action-oriented phrasing; ideally starts with a verb.
* Concise and specific; a reader understands the deliverable from the title alone.
* Avoid vague language ("improve", "update", "fix things") without a concrete qualifier.

## Description Format

Use the clearest format for the context. Three patterns are acceptable:

| Pattern | When to Use | Example |
| --- | --- | --- |
| Classic user story | End-user-facing capability | "As a reviewer, I want inline comments so that I can give feedback without leaving the diff view." |
| Goal statement | Internal or technical work | "Enable CSV export of user profile data for GDPR compliance." |
| Problem statement | Bug-adjacent or improvement | "Search latency exceeds 3 seconds for queries with more than 100 results." |

Every description includes:

* **Who** benefits and in what context.
* **What** is broken, missing, or needed.
* **Why** it matters, grounded in evidence when available.

## Acceptance Criteria

Acceptance criteria are binary, testable, and checklist-style.

* Write each criterion as a verifiable statement a reviewer can check without ambiguity.
* Use `- [ ]` checkbox syntax for consistency across platforms.
* Target 5-10 focused items per story.
* Cover these categories when applicable:
  * Functional behavior (core capability works as described).
  * Edge cases (boundary conditions, error states, empty inputs).
  * Performance (latency, throughput, or resource thresholds).
  * Observability (logging, metrics, or alerting when relevant).

## Definition of Done

The Definition of Done captures team standards that apply to every deliverable beyond the story-specific acceptance criteria. Include this section when relevant standards exist.

Common items:

* Unit or integration tests cover new behavior.
* Documentation updated (API docs, guides, inline comments).
* Observability (structured logging, metrics, dashboards).
* Migration steps documented when schema or data changes are involved.
* Accessibility requirements verified when UI changes are included.

## Scope and Sizing

* Each story targets a single component or concern with clear boundaries.
* Work spanning more than one week should be structured as an epic with sub-issues, each independently deliverable.
* State what is explicitly excluded to prevent scope creep.
* When a story touches multiple systems, split by system boundary.

## Evidence Source

Note whether each requirement comes from one of these sources:

* User research (interviews, usability studies, support tickets).
* Analytics data (usage metrics, error rates, performance traces).
* Stakeholder input (business sponsor, product owner, or team lead request).
* Assumption (team hypothesis without direct evidence).

Requirements without direct user evidence are labeled as unvalidated assumptions in the issue body so reviewers understand the confidence level.

## Completeness Dimensions

Evaluate every work item against these dimensions before marking it ready:

* **User identification**: who benefits and in what context.
* **Problem statement**: what is broken or missing, grounded in evidence.
* **Evidence source**: origin of each requirement (see Evidence Source section).
* **Success criteria**: specific, measurable outcomes tied to user or business goals.
* **Acceptance criteria**: testable conditions following the Acceptance Criteria section.
* **Dependencies**: upstream blockers and downstream consumers identified.
* **Scope boundaries**: what is explicitly excluded to prevent scope creep.

## Open Questions and Risks

Include an optional section for unresolved items when the conversation surfaces them:

* Anything still unclear or requiring follow-up.
* Assumptions made during story creation.
* Items that belong in other stories or epics.
* Known risks or external dependencies.

## Story Output Template

Present polished stories using this structure. Include optional sections when relevant information was gathered.

```markdown
**Title**
[Action-oriented title, ideally starts with a verb]

**Description**
[1-3 concise sentences in the clearest format for the context]

**Acceptance Criteria**
- [ ] Verifiable statement that can be checked off
- [ ] ...
(usually 5-10 focused items)

**Definition of Done notes** (optional)
* Standards that always apply (tests, docs, observability, migration steps)

**Open questions / risks / dependencies** (optional)
* Unresolved items, assumptions, items belonging in other stories
```
