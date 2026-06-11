---
title: "Guideline 1.1 — Text Alternatives"
description: "Guideline 1.1 (Text Alternatives) requires that every non-text element in the experience carry a text alternative that conveys the same purpose, so that the content can be re-rendered in any form t..."
---

# Guideline 1.1 — Text Alternatives

Guideline 1.1 (Text Alternatives) requires that every non-text element in the experience carry a text alternative that conveys the same purpose, so that the content can be re-rendered in any form that the user needs — large print, braille, speech, symbols, or simpler language.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 1.1, <https://www.w3.org/TR/WCAG22/#text-alternatives>.

## sc-1-1-1

**SC 1.1.1 Non-text Content (Level A)**

Every non-text element exposed in the user interface needs a programmatically associated text alternative that serves the same purpose. Decorative or formatting-only elements may carry an empty or ignorable alternative so that assistive technology skips them, and time-based media, tests, sensory experiences, CAPTCHAs, and pure decoration each have their own narrower exception described in the W3C source.

**Applies to**: Images, icons, image buttons, image maps, charts, complex graphics, video and audio (for the placeholder text-equivalent), form controls, audio-only and video-only content (placeholder text), CAPTCHAs, and any embedded object exposed to the user.

**Assessment heuristics**:

* Confirm that every image conveying meaning carries a non-empty `alt`, `aria-label`, or `aria-labelledby` that paraphrases the information conveyed by the image, not the file name.
* Confirm that decorative images carry `alt=""` or `role="presentation"` so assistive technology skips them.
* Confirm that image buttons announce the action (for example, "Submit application") rather than the icon name.
* Confirm that complex graphics carry a short text equivalent plus a longer description accessible via link or `aria-describedby`.
* Confirm that CAPTCHAs offer at least two alternative modalities (visual plus audio, plus a non-cognitive option where feasible).

Source: <https://www.w3.org/TR/WCAG22/#non-text-content>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
