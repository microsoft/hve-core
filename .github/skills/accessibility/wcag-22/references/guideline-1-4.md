---
title: "Guideline 1.4 — Distinguishable"
description: "Guideline 1.4 (Distinguishable) requires that content be easy to see and hear, including separating foreground from background, supporting text resizing and reflow, and providing sufficient contras..."
---

# Guideline 1.4 — Distinguishable

Guideline 1.4 (Distinguishable) requires that content be easy to see and hear, including separating foreground from background, supporting text resizing and reflow, and providing sufficient contrast for text and non-text UI elements.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 1.4, <https://www.w3.org/TR/WCAG22/#distinguishable>.

## sc-1-4-1

**SC 1.4.1 Use of Color (Level A)**

Colour is not used as the only visual means of conveying information, indicating an action, prompting a response, or distinguishing a visual element.

**Assessment heuristics**:

* Confirm required form fields are indicated by text or icon in addition to colour.
* Confirm errors, warnings, and status callouts carry an icon or text label, not just a colour.
* Confirm chart legends, link styling, and stateful UI elements use a non-colour cue (underline, pattern, icon, text).

Source: <https://www.w3.org/TR/WCAG22/#use-of-color>

## sc-1-4-2

**SC 1.4.2 Audio Control (Level A)**

If audio plays automatically for more than 3 seconds, either provide a mechanism to pause or stop the audio or a mechanism to control its volume independently from the overall system volume.

**Assessment heuristics**:

* Confirm autoplaying audio carries a visible pause/stop control that is keyboard reachable within the first three seconds.
* Confirm a media player provides an independent volume control rather than relying solely on OS volume.

Source: <https://www.w3.org/TR/WCAG22/#audio-control>

## sc-1-4-3

**SC 1.4.3 Contrast (Minimum) (Level AA)**

The visual presentation of text and images of text has a contrast ratio of at least 4.5:1, except for large text (3:1), incidental text, and logotypes.

**Assessment heuristics**:

* Confirm body text reaches 4.5:1 against its background using a contrast tool.
* Confirm large text (18pt regular or 14pt bold) reaches at least 3:1.
* Confirm placeholder text and disabled-looking states that still convey information meet 4.5:1.
* Confirm text over images, gradients, or video uses a backplate or shadow that brings effective contrast to 4.5:1.

Source: <https://www.w3.org/TR/WCAG22/#contrast-minimum>

## sc-1-4-4

**SC 1.4.4 Resize Text (Level AA)**

Text can be resized up to 200 per cent without loss of content or functionality, except for captions and images of text.

**Assessment heuristics**:

* Confirm zooming the browser to 200% does not clip content, hide controls, or create horizontal scrolling on text blocks.
* Confirm text is sized in relative units (`rem`, `em`, `%`) rather than fixed pixels for body copy.

Source: <https://www.w3.org/TR/WCAG22/#resize-text>

## sc-1-4-5

**SC 1.4.5 Images of Text (Level AA)**

Text is used to convey information rather than images of text, unless the image is essential (for example, a logotype) or fully customisable by the user.

**Assessment heuristics**:

* Confirm marketing banners, navigation labels, and instructional content use HTML text styled with CSS rather than baked-in image text.
* Confirm logotype images are the only allowed image-of-text exception.

Source: <https://www.w3.org/TR/WCAG22/#images-of-text>

## sc-1-4-6

**SC 1.4.6 Contrast (Enhanced) (Level AAA)**

Text and images of text have a contrast ratio of at least 7:1 (4.5:1 for large text).

**Assessment heuristics**:

* Confirm body text reaches 7:1 contrast for AAA-targeted experiences.

Source: <https://www.w3.org/TR/WCAG22/#contrast-enhanced>

## sc-1-4-7

**SC 1.4.7 Low or No Background Audio (Level AAA)**

Prerecorded audio that contains primarily speech in the foreground has no background sound, the background sound can be turned off, or the background is at least 20 dB lower than the foreground speech.

**Assessment heuristics**:

* Confirm narration tracks reduce or remove background music during speech.
* Confirm an alternative track with no background music is offered when background sound is desired.

Source: <https://www.w3.org/TR/WCAG22/#low-or-no-background-audio>

## sc-1-4-8

**SC 1.4.8 Visual Presentation (Level AAA)**

For blocks of text, users can select foreground and background colours, line width does not exceed 80 characters, text is not justified, line and paragraph spacing reach defined minimums, and text resizes to 200% without horizontal scroll.

**Assessment heuristics**:

* Confirm a high-contrast or user-themed mode is offered for long-form text.
* Confirm line length stays below 80 characters in the default presentation.

Source: <https://www.w3.org/TR/WCAG22/#visual-presentation>

## sc-1-4-9

**SC 1.4.9 Images of Text (No Exception) (Level AAA)**

Images of text are used only for decoration or where a particular presentation of text is essential (no general customisation exemption).

**Assessment heuristics**:

* Confirm even customisable imagery rendered with text is replaced with live text for AAA scope.

Source: <https://www.w3.org/TR/WCAG22/#images-of-text-no-exception>

## sc-1-4-10

**SC 1.4.10 Reflow (Level AA)**

Content can be presented without loss of information or functionality, and without requiring scrolling in two dimensions, at a viewport width of 320 CSS pixels (or 256 CSS pixels height for vertical scrolling content), except for parts that require two-dimensional layout.

**Assessment heuristics**:

* Confirm a 320-pixel-wide viewport (or 400% zoom on a 1280-pixel viewport) does not produce horizontal scrolling on text content.
* Confirm tables, code blocks, and large images may scroll horizontally only when two-dimensional layout is essential.

Source: <https://www.w3.org/TR/WCAG22/#reflow>

## sc-1-4-11

**SC 1.4.11 Non-text Contrast (Level AA)**

Visual presentation of user-interface components and graphical objects required to understand the content has a contrast ratio of at least 3:1 against adjacent colours.

**Assessment heuristics**:

* Confirm form-control borders, focus indicators, and active/selected states reach 3:1 against adjacent colours.
* Confirm icons that convey information reach 3:1 against their background.
* Confirm chart elements distinguishable by shape rely on 3:1 contrast for those shape outlines.

Source: <https://www.w3.org/TR/WCAG22/#non-text-contrast>

## sc-1-4-12

**SC 1.4.12 Text Spacing (Level AA)**

No loss of content or functionality when users override line height (1.5x font), paragraph spacing (2x font), letter spacing (0.12x font), and word spacing (0.16x font).

**Assessment heuristics**:

* Confirm injecting the WCAG text-spacing CSS does not clip text, overlap content, or hide controls.
* Confirm container heights do not constrain text such that the spacing override truncates content.

Source: <https://www.w3.org/TR/WCAG22/#text-spacing>

## sc-1-4-13

**SC 1.4.13 Content on Hover or Focus (Level AA)**

Additional content triggered by hover or focus is dismissible, hoverable (the pointer can move into it without dismissing), and persistent (remains visible until dismissed or no longer relevant).

**Assessment heuristics**:

* Confirm tooltips, popovers, and submenus can be dismissed with the Escape key without moving focus.
* Confirm hover-triggered overlays do not disappear when the pointer moves over the overlay itself.
* Confirm the overlay persists until the triggering condition ends or the user dismisses it.

Source: <https://www.w3.org/TR/WCAG22/#content-on-hover-or-focus>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
