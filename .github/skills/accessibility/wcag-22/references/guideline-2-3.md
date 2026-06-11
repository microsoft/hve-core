---
title: "Guideline 2.3 — Seizures and Physical Reactions"
description: "Guideline 2.3 (Seizures and Physical Reactions) requires that content not be designed in a way known to cause seizures or physical reactions, especially through flashing content."
---

# Guideline 2.3 — Seizures and Physical Reactions

Guideline 2.3 (Seizures and Physical Reactions) requires that content not be designed in a way known to cause seizures or physical reactions, especially through flashing content.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.3, <https://www.w3.org/TR/WCAG22/#seizures-and-physical-reactions>.

## sc-2-3-1

**SC 2.3.1 Three Flashes or Below Threshold (Level A)**

Web pages do not contain anything that flashes more than three times in any one-second period, or the flash is below the general flash and red flash thresholds defined by WCAG.

**Assessment heuristics**:

* Confirm video, animations, and decorative effects do not exceed three flashes per second.
* Confirm flashing red content is checked against the WCAG red-flash threshold using a recognised tool such as PEAT.

Source: <https://www.w3.org/TR/WCAG22/#three-flashes-or-below-threshold>

## sc-2-3-2

**SC 2.3.2 Three Flashes (Level AAA)**

Web pages do not contain anything that flashes more than three times in any one-second period (no general or red flash exception threshold).

**Assessment heuristics**:

* Confirm AAA-targeted experiences contain no content that flashes more than three times per second under any luminance condition.

Source: <https://www.w3.org/TR/WCAG22/#three-flashes>

## sc-2-3-3

**SC 2.3.3 Animation from Interactions (Level AAA)**

Motion animation triggered by interaction can be disabled, unless the animation is essential to the functionality or the information being conveyed.

**Assessment heuristics**:

* Confirm a `prefers-reduced-motion` media query disables decorative motion.
* Confirm the user can disable scroll-linked or parallax animations through a setting where the OS preference is unavailable.

Source: <https://www.w3.org/TR/WCAG22/#animation-from-interactions>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
