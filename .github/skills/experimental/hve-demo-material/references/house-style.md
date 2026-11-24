---
description: "Canonical HVE Slides theme ownership and permitted demo-material layout styling, verified against delivered HTML."
---

# Demo Material House Style

## One Theme Owner

All levels use the loaded `hve-slides` skill's canonical `templates/deck/theme.css`
and `components.css`. HTML and its exported video frames share that theme.
Do not fork a palette or infer rendered styling from a YAML declaration.
The HVE Slides owner retains typography, colors, controls and accessibility
behavior across repository and installed use.

## Permitted Demo Styling

The adapter appends only this skill's `templates/html-deck.css` and generated
embedded-image rules to canonical `components.css`. That stylesheet maps
text, cards, tables, ordered flows, steps and images to the HVE Slides design.
Authored YAML cannot add CSS, JavaScript, HTML resource markup or remote fonts.
Recognized old visual hints may guide semantic grouping but do not override CSS.

## Metadata and Language

Copy `templates/style.yaml` to `content/global/style.yaml` and fill the deck
title, subject and keywords. Set `metadata.language` to the actual language
(default `en-US`). The adapter applies language to HTML and individual slides;
this is not a presentation-library text-run operation.

## Acceptance Evidence

T-08 compares the delivered HTML's bundled `theme.css` with the canonical bytes,
and its `components.css` with canonical components plus permitted demo layout
and embedded-image rules. Additional styling fails rather than being certified
by an unrelated metadata comparison.

T-09 checks titles, image alternatives and language, alongside caption/transcript
evidence. T-10 requires offline startup, no overflow and matching ordered frame
evidence for the delivered revision. Inspect actual rendered text, contrast and
fidelity before `validation.deck: pass`; these machine checks are not a complete
accessibility certification. Missing evidence remains deferred or failed.
