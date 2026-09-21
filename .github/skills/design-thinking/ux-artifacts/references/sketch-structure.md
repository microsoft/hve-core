---
title: "UX artifact mode: Sketch structure"
description: Capture a surface's regions, controls, interaction states, and transitions as an evidence-labelled structure asset without rendering or claiming conformance.
---

# Sketch structure

Use this mode when decisions about what a surface contains and how it behaves are ready to be recorded. The asset describes composition and interaction affordances. It is not a rendered wireframe, a visual design, or a conformance assessment.

## Inputs

* Supplied concept, needs, journey, or decision evidence, or an explicit `source` pointer
* The surface or set of surfaces in question
* Regions, controls, and content already decided
* Interaction states and the conditions that produce them
* Known transitions, alternatives, and unresolved structural questions

An explicit Design Thinking Solution Space handoff may be the `source` when the caller passes its pointer. Read only that pointer. Never discover Design Thinking session state, and never treat a concept sketch as a decided structure.

## Output body

After the common evidence sections, write:

```markdown
## Surface Scope

| Surface   | Intended user outcome | Entry context          | Source boundary                  |
|-----------|-----------------------|------------------------|----------------------------------|
| <surface> | <outcome>             | <how the user arrives> | <what this asset does not cover> |

## Surface Composition

| Surface   | Region   | Order                          | Content purpose            | Control or content element | Visible label or affordance | Applies in state | Basis and source                             |
|-----------|----------|--------------------------------|----------------------------|----------------------------|-----------------------------|------------------|----------------------------------------------|
| <surface> | <region> | <reading or interaction order> | <why this content is here> | <element>                  | <label or affordance>       | <state or All>   | <Observed, Reported, or Assumed plus source> |

## Interaction States

| Surface   | State   | Entry condition | Available controls | Information conveyed   | Exit condition | Basis and source                             |
|-----------|---------|-----------------|--------------------|------------------------|----------------|----------------------------------------------|
| <surface> | <state> | <condition>     | <controls>         | <what the user learns> | <condition>    | <Observed, Reported, or Assumed plus source> |

## State Transitions

| Surface   | From state | User action or event | To state | Surface change or feedback | Unresolved behavior | Basis and source                             |
|-----------|------------|----------------------|----------|----------------------------|---------------------|----------------------------------------------|
| <surface> | <state>    | <action or event>    | <state>  | <what changes>             | <gap or None>       | <Observed, Reported, or Assumed plus source> |

## Existing Design Intent References

| Surface   | Existing record or intent identifier | Relationship to this structure    |
|-----------|--------------------------------------|-----------------------------------|
| <surface> | <existing identifier or None>        | <how the structure depends on it> |
```

## Region vocabulary

Name regions with plain structural terms such as banner, navigation, main, complementary, and content information. This vocabulary is adapted from the W3C Web Accessibility Initiative page structure guidance at <https://www.w3.org/WAI/tutorials/page-structure/regions/> and is used here as shared naming only.

Naming a region does not make the surface accessible and does not satisfy any success criterion. Route conformance to `accessibility`.

## Evidence rules

* Every composition, state, and transition row carries a basis and source. A structural claim with no source is `Assumed` or belongs in `Unresolved`.
* Record only structure the supplied evidence decides. Do not infer a control, state, or transition to complete a pattern.
* Order describes reading or interaction sequence, not pixels, spacing, grid, or breakpoint behavior.
* An unnamed or undecided region stays unresolved rather than becoming a plausible default layout.
* Reference an existing Design Intent Record only when the caller supplies its identifier. Never invent one.

## Representation boundary

The tables are the authoritative representation. Do not add an ASCII layout, a Mermaid diagram, an image, or any second view of the same structure inside the asset, because a second view drifts from the row-level evidence it duplicates.

Visual representation belongs to the destination mappings. Map a completed asset to Figma Design, FigJam, or Mural when the caller asks for a picture.

## Ownership boundary

* This mode owns surface composition, region hierarchy, control placement, visible affordances, local interaction states, and transitions between them.
* `prepare-handoff` owns cross-state experience flow, system response, success and exit conditions, recovery paths, engineering questions, and acceptance inputs. Pass this asset to it by pointer rather than restating flow here.
* `decide-inclusion` owns who a concept may exclude and what it demands of memory, attention, language, senses, or movement.
* `accessibility` owns technical conformance, ARIA patterns, COGA guidance, and the Design Intent Record contract.

## Completion conditions

* Every named surface has a scope row and at least one composition row.
* States and transitions are explicit where evidence supports them, and unsupported behavior stays unresolved.
* Each row identifies its evidence strength and source.
* The asset carries no rendered view, conformance claim, or invented intent identifier.

## Stop conditions

Stop with a partial asset when the supplied evidence does not decide the structure. Name what is missing rather than completing the surface from convention. Stop and name `prepare-handoff` when the real request is implementation-facing flow, or `accessibility` when it is conformance.
