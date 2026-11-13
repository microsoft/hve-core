---
name: code-review-accessibility
description: 'Review changed interaction, markup, and user-facing content with the consolidated accessibility capability. Use for Code Review accessibility work.'
license: CC-BY-4.0
user-invocable: false
---

# Accessibility review

## Goal

Find user barriers in the assigned change and distinguish static evidence from
interaction or assistive-technology evidence. Use `code-review-core` and activate
the consolidated `accessibility` skill.

## Review

Select only the framework references relevant to the surface and declared scope:
WCAG, ARIA patterns, cognitive accessibility, or applicable procurement criteria.
Use the consolidated skill's current references rather than obsolete skill names.
When no accessibility-relevant surface exists, complete with a not-applicable
reason.

Inspect changed controls and their consuming context for keyboard operation,
focus order/visibility/restoration, names and roles, state announcements,
form errors, contrast, reflow, motion, and understandable content. Cite the
criterion or authoring pattern behind each finding and explain who is affected.
Separate a required barrier fix from a stylistic preference.

Record which checks used source inspection, runtime interaction, an accessibility
tree, or assistive technology. Static reads cannot prove keyboard, rendering,
or screen-reader behavior. Missing required methods remain limitations; do not
convert an unavailable runtime check into a conformance claim. Do not install
browsers or start services merely to satisfy review.

## Completion

Record the methods used and the evidence gaps in the result. Stop unavailable
when the required framework or method is missing. A deeper audit may be a parent
follow-up when its capability exists.
