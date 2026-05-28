---
name: lofi-image-prompts
description: 'Pencil-sketch storyboard prompt templates for DT Method 6 lo-fi prototype visualization - Brought to you by microsoft/hve-core'
---

# Lo-Fi Image Prompts

Parameterized image-generation prompt templates that produce hand-drawn pencil-sketch-style storyboards and prototype visualizations for Design Thinking Method 6 (Lo-Fi Prototypes).

## Overview

Generates prompts in a physical sketchbook style — graphite pencil, ballpoint pen accents, Moleskine paper — for Method 6's prototype building phase. These prompts enforce deliberate roughness so stakeholders evaluate behavior and assumptions rather than aesthetics.

This skill complements `dt-image-prompt-generation.instructions.md` (Method 5 stick-figure style) by providing higher-detail but still intentionally imperfect sketches suited to prototype testing artifacts.

## Prerequisites

* Method 5 concept card with finalized concept name
* Method 6 prototype plan with declared hypothesis
* Panel descriptions or scene descriptions drafted during prototype planning

## Quick Start

Generate a storyboard prompt using the template with a concept from your prototype plan:

```text
A hand-drawn pencil sketch on slightly off-white sketchbook paper, in the style
of a designer's lo-fi prototype scribbled during a working session. Top of the
page reads "Brewed Awakening — Service Flow LO-FI v0.1" in casual hand-printed
lettering with a wavy underline. The sketch is laid out as a 5-step storyboard
with rough hand-drawn arrows connecting the panels.

Panel 1: Customer approaches counter, menu board above with scribbled items
Panel 2: Barista points to phone screen showing order confirmation
Panel 3: Customer taps card on reader, arrow shows "beep" in a speech bubble
Panel 4: Barista slides drink across counter with a check-mark doodle
Panel 5: Customer walks away holding cup, satisfaction stars above head

Style: graphite pencil and a touch of blue ballpoint pen for accents and arrows.
Imperfect lines, slightly crooked rectangles, the kind of sketch a designer
makes with a real human hand on real paper. Some words slightly larger or
underlined for emphasis. Visible eraser marks and one or two small smudges.
NOT digital, NOT polished UI, NOT a wireframe tool output. Should feel like
a photo of a page torn from a Moleskine.

WHAT WE'RE TESTING: Customers complete payment without verbal confirmation.
```

## Parameters Reference

| Parameter          | Required | Default      | Description                                                                                  |
|--------------------|----------|--------------|----------------------------------------------------------------------------------------------|
| Concept name       | Yes      | —            | Name from Method 5 concept card or Method 6 prototype plan                                   |
| Hypothesis         | Yes      | —            | Assumption being tested (appears in "WHAT WE'RE TESTING" footer)                             |
| Format             | Yes      | —            | `storyboard`, `single-scene`, or `annotated-concept`                                         |
| Panel count        | No       | 5            | Number of panels for storyboard format (3–7)                                                 |
| Panel descriptions | Yes*     | —            | Brief scene description per panel (*required for storyboard)                                 |
| Annotation list    | No       | —            | Margin notes or constraint callouts for annotated-concept format                             |
| Accent color       | No       | blue         | Single ballpoint pen color for accents                                                       |
| Aspect ratio       | No       | portrait     | `4:3`, `portrait`, or `landscape`                                                            |
| Prototype type     | No       | "Storyboard" | Subtitle label in the header (e.g., "Service Flow", "Drive-Thru", "Detail")                  |
| Scene description  | Yes*     | —            | Central scene for single-scene and annotated-concept formats (*required for those formats)   |
| Hypothesis items   | No       | —            | Checklist items for annotated-concept "Testing:" box (defaults to hypothesis as single item) |

## Prompt Templates

Replace `[PLACEHOLDERS]` with the corresponding parameter value. Remove unused optional parameters entirely.

### Storyboard (Multi-Panel)

Tests user journeys, sequences, and service flows.

```text
A hand-drawn pencil sketch on slightly off-white sketchbook paper, in the style
of a designer's lo-fi prototype scribbled during a working session. Top of the
page reads "[CONCEPT_NAME] — [PROTOTYPE_TYPE] LO-FI v0.1" in casual hand-printed
lettering with a wavy underline. The sketch is laid out as a [N]-step storyboard
with rough hand-drawn arrows connecting the panels.

Panel 1: [description]
Panel 2: [description]
...
Panel N: [description]

Style: graphite pencil and a touch of [ACCENT_COLOR] ballpoint pen for accents
and arrows. Imperfect lines, slightly crooked rectangles, the kind of sketch a
designer makes with a real human hand on real paper. Some words slightly larger
or underlined for emphasis. Visible eraser marks and one or two small smudges.
NOT digital, NOT polished UI, NOT a wireframe tool output. Should feel like a
photo of a page torn from a Moleskine.

WHAT WE'RE TESTING: [HYPOTHESIS]
Aspect ratio: [ASPECT_RATIO].
```

### Single-Scene Sketch

Tests one interaction moment in detail.

```text
A hand-drawn pencil sketch on slightly off-white sketchbook paper showing a
single detailed scene: [SCENE_DESCRIPTION]. The sketch title "[CONCEPT_NAME]
— Detail v0.1" is hand-printed at the top with a wavy underline.

Style: graphite pencil and a touch of [ACCENT_COLOR] ballpoint pen for callout
arrows. Imperfect lines, slightly crooked rectangles, visible eraser marks.
The kind of sketch a designer makes with a real human hand on real paper.
NOT digital, NOT polished UI, NOT a wireframe tool output. Should feel like
a photo of a page torn from a Moleskine.

WHAT WE'RE TESTING: [HYPOTHESIS]
Aspect ratio: [ASPECT_RATIO].
```

### Annotated Concept

Sketch with margin notes testing assumptions with visible checklist.

```text
A hand-drawn pencil sketch on slightly off-white sketchbook paper. Center of
the page shows [SCENE_DESCRIPTION]. Around the margins, handwritten notes in
[ACCENT_COLOR] ballpoint pen with arrows pointing to relevant parts of the
sketch: [ANNOTATION_1], [ANNOTATION_2], [ANNOTATION_3].

Bottom-right corner has a small hand-drawn checkbox list titled "Testing:"
with items: [HYPOTHESIS_ITEMS].

Title "[CONCEPT_NAME] — Annotated v0.1" hand-printed at top. Style: only
graphite grey and [ACCENT_COLOR] pen, no other colors. Imperfect lines,
slightly crooked rectangles, visible eraser marks. The kind of sketch a
designer makes with a real human hand on real paper. NOT digital, NOT polished
UI, NOT a wireframe tool output. Should feel like a photo of a page torn from
a Moleskine.

WHAT WE'RE TESTING: [HYPOTHESIS]
Aspect ratio: [ASPECT_RATIO].
```

## Style Enforcement

All prompts must include the complete 6-layer directive stack:

| Layer                | Directive                                                                  | Purpose                             |
|----------------------|----------------------------------------------------------------------------|-------------------------------------|
| 1. Medium            | "hand-drawn pencil sketch" or "graphite pencil and ballpoint pen"          | Establishes physical drawing medium |
| 2. Surface           | "slightly off-white sketchbook paper" or "Moleskine page"                  | Anchors to physical artifact        |
| 3. Imperfection      | "imperfect lines, slightly crooked rectangles, visible eraser marks"       | Enforces roughness                  |
| 4. Anti-Digital      | "NOT digital, NOT polished UI, NOT a wireframe tool output"                | Blocks tool-generated aesthetics    |
| 5. Human Feel        | "the kind of sketch a designer makes with a real human hand on real paper" | Reinforces authenticity             |
| 6. Color Restriction | "graphite pencil with optional single accent color (ballpoint)"            | Prevents multi-color polish         |

**Anti-pattern vocabulary (never include):** "clean lines", "pixel-perfect", "wireframe", "mockup tool", "UI kit", "high-fidelity", "digital illustration", "vector"

Negation usage is acceptable. Layer 4 uses "NOT a wireframe tool output" to actively block the style — this is not a violation.

## Iteration Guidance

Image models struggle with hand-printed text. Expect iteration.

**Text rendering limitations:**

* Models frequently produce gibberish or misspelled hand-printed text
* Gibberish is acceptable for lo-fi — preserves the "thinking artifact" vibe
* Generate without text labels and add them manually in post-processing
* Request "illegible scribbled notes" when legibility is not required

**Push-back techniques when models produce polished output:**

* Prepend "rough, unfinished" before any scene description
* Add "as if sketched in 30 seconds during a meeting"
* Strengthen Anti-Digital layer: "absolutely NOT a Figma export or Balsamiq wireframe"
* Add physical artifact cues: "coffee ring stain in corner", "page slightly crumpled"

**Regeneration triggers:**

* Output looks like a wireframing tool produced it → strengthen layers 4–5
* Lines are too straight and uniform → add "wobbly hand-drawn lines, uneven spacing"
* Multiple colors appear → reinforce layer 6 explicitly
* Text is too legible/typeset → request "scribbled" or "barely legible handwriting"

## Troubleshooting

| Symptom                            | Cause                              | Fix                                                              |
|------------------------------------|------------------------------------|------------------------------------------------------------------|
| Output resembles Balsamiq or Figma | Anti-Digital layer too weak        | Add "absolutely NOT tool-generated" and physical cues            |
| Multiple colors in output          | Color restriction missing          | Explicitly state "only graphite grey and [accent] pen"           |
| Perfect straight lines             | Imperfection layer insufficient    | Add "wobbly", "uneven", "hand-tremor quality"                    |
| Legible typeset text               | Model defaulting to font rendering | Request "illegible scribbled handwriting" or omit text           |
| Too few panels rendered            | Panel count ambiguous              | State exact count: "exactly 5 panels, no more, no fewer"         |
| Panels lack connecting flow        | Missing arrow directive            | Add "rough hand-drawn arrows connecting each panel sequentially" |

> Brought to you by microsoft/hve-core
