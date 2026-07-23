---
description: 'PRD product-discovery reference - repository-original persona archetype and customer-journey-map templates, plus a cite-only registry of opportunity-solution-tree, jobs-to-be-done, and story-mapping discovery frameworks'
---

# PRD Product Discovery

This document supplies the product-discovery scaffolding the PRD Builder uses to frame users, opportunities, and journeys before requirements are written. The persona-archetype and customer-journey-map templates below are repository-original Microsoft content. The discovery frameworks in the cite-only registry are referenced by name only; no upstream prose, diagram, or canvas is redistributed.

## When to apply

Apply this reference during the PRD Discover phase when:

* Building or refining the Users & Personas section of the canonical PRD template.
* Framing the opportunity space before committing functional requirements.
* Capturing user journeys that motivate scope and acceptance criteria.

## Persona archetype template (repository-original)

Use one block per persona. Personas are archetypes, not individuals; keep them grounded in observed behavior rather than demographics alone.

```text
Persona: <archetype name>
Role / context: <where this person sits in the workflow>
Primary goals: <what success looks like for them>
Pain points: <frictions in the current state>
Triggers: <events that bring them to the product>
Success signals: <observable outcomes that mean the product helped>
Anti-goals: <outcomes this persona actively wants to avoid>
```

Authoring rules:

1. One archetype per block; do not merge distinct goal sets into a composite persona.
2. Every pain point should map to at least one functional requirement or open question downstream.
3. Avoid solution language in the persona; describe needs, not features.

## Customer journey map template (repository-original)

Use one row per stage. A journey map records the persona's experience across stages so the PRD can target the highest-friction moments.

| Stage        | Persona action | Goal at this stage    | Friction / pain        | Opportunity                  | Success signal           |
|--------------|----------------|-----------------------|------------------------|------------------------------|--------------------------|
| <stage name> | <what they do> | <what they want here> | <what gets in the way> | <where the product can help> | <observable improvement> |

Authoring rules:

1. Stages move in the persona's chronological order, not the system's internal order.
2. Each high-friction stage should connect to a goal, a functional requirement, or an open question.
3. Keep opportunities outcome-oriented; defer solution choices to the requirements sections.

## Cite-only discovery framework registry

The frameworks below inform PRD discovery framing. They are cited by name only. The PRD Builder writes its own discovery prose and never reproduces upstream canvases, trees, or definitions.

### Opportunity Solution Tree (Teresa Torres)

* **Author / source** — Teresa Torres, *Continuous Discovery Habits* (Product Talk Press, 2021).
* **URL** — [https://www.producttalk.org/opportunity-solution-tree/](https://www.producttalk.org/opportunity-solution-tree/)
* **Why the PRD Builder cites it** — Framing device for connecting a desired outcome to discovered opportunities and candidate solutions during the Discover phase. The tree structure is described by name only; the PRD Builder records opportunities and solutions in its own scope and goal sections.

### Jobs To Be Done (Clayton Christensen)

* **Author / source** — Clayton M. Christensen et al., *Competing Against Luck* (HarperBusiness, 2016); "Jobs to Be Done" / "Forces of Progress" framing.
* **URL** — [https://www.christenseninstitute.org/jobs-to-be-done/](https://www.christenseninstitute.org/jobs-to-be-done/)
* **Why the PRD Builder cites it** — Lens for expressing the underlying job a persona is trying to accomplish. The "four forces of progress" are referenced by name and are not enumerated inline; the PRD captures the job and its context in original prose.

### User Story Mapping (Jeff Patton)

* **Author / source** — Jeff Patton, *User Story Mapping* (O'Reilly, 2014).
* **URL** — [https://www.jpattonassociates.com/user-story-mapping/](https://www.jpattonassociates.com/user-story-mapping/)
* **Why the PRD Builder cites it** — Method pattern for arranging user activities into a narrative backbone that informs scope slicing and the feature hierarchy. The PRD Builder uses its own templates for the feature hierarchy and does not reproduce the story-map canvas.

## License

This reference file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The persona and journey-map templates are HVE-Core IP and may be reused under the same license. The discovery frameworks named in the cite-only registry remain the property of their respective authors and publishers; their prose is accessed by the reader through the cited URLs and is never redistributed here.


