---
title: Graphics ARIA and SVG Accessibility API Mappings framework reference
description: WAI-ARIA Graphics Module and SVG Accessibility API Mappings packaged as an accessibility assessment knowledge base for charts, diagrams, and other authored graphics
---

# Graphics ARIA and SVG-AAM framework reference

This skill packages two W3C specifications that govern how a graphic conveys its meaning to assistive technology: the WAI-ARIA Graphics Module, which defines roles for the parts of a graphic, and SVG Accessibility API Mappings (SVG-AAM), which defines how SVG content reaches platform accessibility APIs.

These sit apart from the other framework references in this skill. [`wcag-22`](wcag-22.md) states what a user must be able to perceive, and [`aria-apg`](aria-apg.md) describes how to build interactive widgets. Neither says much about a chart or diagram whose meaning lives in its shapes rather than in its controls. That gap is what these two specifications fill.

They describe implementation targets, not an authoring format. Use them to decide which criterion identifiers an expectation cites and which sources a design intent record grounds itself in. They do not supply a schema of their own.

Sources:

* WAI-ARIA Graphics Module: <https://www.w3.org/TR/graphics-aria-1.0/>
* SVG Accessibility API Mappings: <https://www.w3.org/TR/svg-aam-1.0/>
* Graphics Accessibility API Mappings: <https://www.w3.org/TR/graphics-aam-1.0/>
* WAI Complex Images tutorial: <https://www.w3.org/WAI/tutorials/images/complex/>

Publication status and licensing are publication-specific. Graphics ARIA is a W3C Recommendation; SVG-AAM is a Working Draft. The WAI tutorial page is not in TR space and can carry a different document-license footer from a TR publication.

Per the accessibility licensing posture in `accessibility-license-posture.instructions.md`, every summary below is paraphrased in the authors' own words and links the canonical W3C URL for verification.

## Graphics roles

The Graphics Module adds three roles that describe a graphic's internal structure, so assistive technology can present a diagram as something with parts rather than as one opaque image.

| Role                | Describes                                                                               | Typical use                                               |
|---------------------|-----------------------------------------------------------------------------------------|-----------------------------------------------------------|
| `graphics-document` | A self-contained graphic that carries its own meaning and may contain further structure | The chart or diagram as a whole                           |
| `graphics-object`   | A meaningful part within a graphic, which may itself group further parts                | A plotted series, an axis, a labelled region of a map     |
| `graphics-symbol`   | A unit of meaning conveyed by a shape that is not decomposed further                    | A legend marker, a pictogram, a repeated data point glyph |

The module does not define a blanket accessible-name requirement for every graphics role. In particular, `graphics-object` does not carry a role-level required-name rule. Whether a given element needs a name depends on semantics and context.

## How SVG reaches assistive technology

SVG-AAM specifies how SVG elements and the graphics roles map onto platform accessibility APIs. Two practical consequences matter when declaring intent:

* An SVG `title` child contributes the accessible name for its parent element, and a `desc` child contributes the description. Position matters, so authors cannot rely on a title placed arbitrarily.
* A graphic that is purely decorative should be removed from the accessibility tree rather than left unnamed, so assistive technology does not announce a meaningless node.

The Complex Images tutorial covers the case where a short text alternative cannot carry the content — a chart with a trend, a diagram with relationships — and a longer description must be reachable rather than merely present.

## What automation can and cannot decide

This boundary is the reason the design intent contract distinguishes an expectation that `decides` a criterion from one that only `informs` it. Declaring intent for a graphic runs into that distinction immediately.

Mechanically decidable from the accessibility tree and the DOM:

* An element with a graphics role exposes a non-empty accessible name.
* A `title` or `desc` is present and associated with the element it describes.
* A decorative graphic is hidden from assistive technology.
* Structural children of a graphic are exposed rather than collapsed.
* An `aria-describedby` reference resolves to an element that exists.

Not decidable by any automated check:

* Whether the text alternative conveys the same meaning the graphic conveys visually.
* Whether the description captures the trend, relationship, or outlier that makes the graphic worth showing.
* Whether the level of detail suits the audience the record names.
* Whether the reading order of a graphic's parts matches how a sighted reader would traverse them.

The second list is the substance of what a practitioner decides when they declare what a surface must convey. It is human review evidence, not automation.

## Declaring graphics intent today

The runtime probe harness in this skill has no graphics probe. An expectation about graphics semantics therefore uses `assert: custom`, which the design intent contract holds to `role: informs` and `blocking: false`, and resolves through a human `override` carrying a rationale and reviewer.

This is a deliberate limit rather than a missing feature. The adequacy map in this skill does not let any probe decide a semantic-equivalence criterion, because no probe can. A future graphics probe could decide only the observable contracts in the first list above; the meaning of a graphic would still belong to a person.

Criterion references that graphics expectations commonly cite:

| Criterion        | Bears on                                                                | Realistic role for automation                     |
|------------------|-------------------------------------------------------------------------|---------------------------------------------------|
| `wcag-22:1.1.1`  | A non-text element has a text alternative serving an equivalent purpose | Presence: decidable. Equivalence: human           |
| `wcag-22:1.3.1`  | Structure and relationships are programmatically determinable           | Exposure: partially decidable. Correctness: human |
| `wcag-22:1.4.1`  | Colour is not the only means of conveying information                   | Human, with heuristic hints                       |
| `wcag-22:1.4.11` | Non-text visual elements and states preserve required contrast          | Presence: partly decidable. Equivalence: human    |
| `wcag-22:1.4.5`  | Text is real text rather than an image of text                          | Heuristic only                                    |
