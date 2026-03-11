---
description: "Create, update, or manage PowerPoint slide decks"
agent: PowerPoint Builder
argument-hint: "[source=PPTX or content] {action=create|update|cleanup|from-existing} [requirements=...]"
---

# PowerPoint Slide Deck

## Inputs

* ${input:source}: (Optional) Source PPTX file or content directory to work from. Defaults to creating a new deck.
* ${input:action}: (Optional) Action to perform: `create`, `update`, `cleanup`, or `from-existing`. Defaults to `create` when omitted.
* ${input:requirements}: (Optional) Additional requirements, objectives, or constraints for the slide deck.

## Requirements

1. Establish a working directory under `.copilot-tracking/ppt/` for all artifacts.
2. Organize content, images, and scripts as separate artifacts before generating slides.
3. Generate slide decks programmatically using Python with `python-pptx`.
4. Validate each iteration against the quality checklist before presenting results.
5. Iterate on fixes until the deck passes all validation checks.
