---
description: 'Opt-in accessibility review reference for Code Review. Read only when the user explicitly requests an accessibility review.'
---

# Accessibility review (opt-in)

> [!IMPORTANT]
> Read this reference and activate `accessibility` **only** when the user explicitly requests an `accessibility` review. Never preload this file during a default functional review.

## Goal

Find user barriers in the assigned areas and distinguish static source inspection from runtime or assistive-technology evidence. Follow [review-contract.md](review-contract.md), activate the consolidated `accessibility` skill, and tag findings with vector `accessibility`.

## Review

Select only the framework references inside `accessibility` relevant to the assigned surface (WCAG 2.2, ARIA Authoring Practices, cognitive accessibility, or applicable procurement criteria). When no accessibility-relevant surface exists in the assigned area, complete with a reasoned `notApplicable` message.

Inspect changed controls and their consuming context for keyboard operation, focus order, focus visibility and restoration, accessible names and roles, live-region announcements, form errors, contrast, reflow, reduced motion, and understandable labels. Cite the specific criterion or pattern in `criterion` and state who is affected.

Record which checks relied on static inspection versus runtime interaction, accessibility-tree inspection, or assistive technology. Never convert an unrun browser or screen-reader check into a conformance claim, and do not install browsers or start servers merely to run a review.

## Completion

Record the inspection methods and remaining runtime gaps in `observations`. Stop `unavailable` when required framework references cannot be loaded.
