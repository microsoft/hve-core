---
title: "Clause 10: Non-Web Documents"
description: "Clause 10 of EN 301 549 V3.2.1 adopts a curated subset of WCAG 2.1 Level A and AA success criteria and reapplies them to non-web documents (tagged PDF, DOCX, PPTX, XLSX, EPUB, ODT, and other portab..."
---

# Clause 10: Non-Web Documents

Clause 10 of EN 301 549 V3.2.1 adopts a curated subset of WCAG 2.1 Level A and AA success criteria and reapplies them to non-web documents (tagged PDF, DOCX, PPTX, XLSX, EPUB, ODT, and other portable formats). The reading experience for these formats is driven by document viewers and assistive technology rather than by browsers, so each sub-clause restates the WCAG requirement in terms of what a document author and a document-producing tool chain must encode into the file itself. Live web behaviours (timing, scripted state, dynamic input) are out of scope; the curated list focuses on perceivable content, operable navigation, and understandable language as expressed through document structure and metadata.

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 10, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording and the linked WCAG 2.2 reference files for criterion-level technical detail.

## clause-10-1-1-1

**10.1.1.1 Non-text content**

Every non-text element in the document (images, charts, icons, decorative ornaments, scanned pages) shall carry a text alternative that conveys equivalent information or function, or shall be marked as decorative so assistive technology can skip it. Purely decorative artwork shall be tagged as an artifact; informational graphics shall expose alternative text through the document format's native mechanism (PDF `/Alt`, Office image alt-text, EPUB `alt` attribute).

**Applies to**: Images in documents.

**WCAG cross-reference**: [sc-1-1-1](../../wcag-22/references/guideline-1-1.md#sc-1-1-1).

**Assessment heuristics**:

* Enumerate every image, shape, chart, and icon in the document and confirm each one has either an alternative text string or an "artifact / decorative" tag.
* Open the file in a screen reader (NVDA + Acrobat, VoiceOver + Preview, JAWS + Word) and verify the alternative is announced when navigating to the image.
* Confirm scanned pages have been processed through OCR so the underlying text is available to assistive technology, not just the page image.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-2-1

**10.1.2.1 Audio-only and video-only (prerecorded)**

For prerecorded audio-only content embedded in or referenced by the document, an equivalent text transcript shall be provided. For prerecorded video-only content (silent video), either a text description or an equivalent audio track shall be provided so users who cannot see the video receive the same information.

**Applies to**: Prerecorded media in documents.

**WCAG cross-reference**: [sc-1-2-1](../../wcag-22/references/guideline-1-2.md#sc-1-2-1).

**Assessment heuristics**:

* For each embedded audio file, confirm a transcript is included in the document body or linked from the same page that hosts the audio.
* For each embedded silent video, confirm a textual description or equivalent narration accompanies the video and conveys the same information.
* Verify alternatives are reachable by the document's reading order, not stranded in a separate file the screen reader cannot locate.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-2-2

**10.1.2.2 Captions (prerecorded)**

Prerecorded video with synchronized audio that is embedded in or referenced by the document shall be accompanied by captions for all spoken dialogue and meaningful non-speech audio. Captions shall be either open (burned into the video) or available through a caption track the document viewer can render.

**Applies to**: Video in documents.

**WCAG cross-reference**: [sc-1-2-2](../../wcag-22/references/guideline-1-2.md#sc-1-2-2).

**Assessment heuristics**:

* For each video with audio, verify a synchronized caption track is bundled with the document or made available alongside it.
* Confirm captions cover dialogue, speaker identification when ambiguous, and non-speech sounds that carry meaning.
* Spot-check timing against the audio to confirm captions match speech without drift.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-2-3

**10.1.2.3 Audio description or media alternative (prerecorded)**

Prerecorded video with synchronized audio shall be accompanied by either an audio description of the visual track during natural pauses in dialogue, or a full media alternative (a text document that describes both the audio and the visual track in sequence).

**Applies to**: Video in documents.

**WCAG cross-reference**: [sc-1-2-3](../../wcag-22/references/guideline-1-2.md#sc-1-2-3).

**Assessment heuristics**:

* For each video, confirm either an audio-described version is available or a full text alternative is provided in the document.
* Verify the text alternative includes setting, actions, on-screen text, and speaker cues sufficient for a non-sighted reader to follow the narrative.
* Confirm the alternative is linked from the same context as the video so users can locate it without separate instructions.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-3-1

**10.1.3.1 Info and relationships**

The structure that is conveyed visually (headings, paragraphs, lists, tables, columns, sidebars, captions) shall also be encoded in the document's underlying semantics so assistive technology can present the same relationships. Use real heading styles instead of bold text, real list elements instead of bullet glyphs, and tagged tables with header rows or columns marked as such.

**Applies to**: Document structure.

**WCAG cross-reference**: [sc-1-3-1](../../wcag-22/references/guideline-1-3.md#sc-1-3-1).

**Assessment heuristics**:

* Inspect the document's tag tree (Acrobat Tags pane, Word accessibility checker, EPUB nav doc) and confirm headings, lists, and tables map to their semantic equivalents.
* Verify data tables identify header cells; complex tables additionally use scope or header-id associations so cell relationships are unambiguous.
* Confirm form fields, where present, carry programmatic labels and group associations rather than placeholder text alone.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-3-2

**10.1.3.2 Meaningful sequence**

The reading order encoded in the document shall match the order required to understand the content. Multi-column layouts, sidebars, callouts, and floating images shall be sequenced so a linear read (screen reader, refreshable braille, reflow on small screens) presents content in the author's intended order.

**Applies to**: Content order in documents.

**WCAG cross-reference**: [sc-1-3-2](../../wcag-22/references/guideline-1-3.md#sc-1-3-2).

**Assessment heuristics**:

* Use the viewer's "read order" or "reflow" view to walk the document linearly and confirm the sequence matches the visual narrative.
* For PDFs, inspect the tag tree to confirm sidebars and pull quotes are placed at the intended position rather than interrupting body flow.
* Test with a screen reader on a multi-column page and confirm reading does not cross columns mid-sentence.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-3-3

**10.1.3.3 Sensory characteristics**

Instructions embedded in the document shall not rely solely on sensory properties (shape, colour, size, visual location, sound) to identify referenced elements. Pair a sensory cue with a text descriptor such as the figure number, section title, or field label.

**Applies to**: Document instructions.

**WCAG cross-reference**: [sc-1-3-3](../../wcag-22/references/guideline-1-3.md#sc-1-3-3).

**Assessment heuristics**:

* Search the document for instructional phrasing ("click the green button", "see the chart on the right", "the round icon") and confirm each instance also names the element by label or section.
* Verify cross-references use figure or section identifiers rather than positional shorthand ("see above", "the box on the left").
* Confirm any audio cues are paired with a textual alert that delivers the same information.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-4-1

**10.1.4.1 Use of color**

Colour shall not be the sole means of conveying information, indicating an action, prompting a response, or distinguishing a visual element. Pair colour with text, iconography, patterns, or labels so the same information reaches users who cannot perceive the colour distinction.

**Applies to**: Visual design in documents.

**WCAG cross-reference**: [sc-1-4-1](../../wcag-22/references/guideline-1-4.md#sc-1-4-1).

**Assessment heuristics**:

* Review charts, status indicators, highlighted text, and legends; verify each colour distinction is paired with a label, pattern, or icon.
* Convert the document to greyscale and confirm the meaning still comes through.
* Inspect required-field markers and error highlights to confirm they carry text or an icon alongside the colour.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-4-2

**10.1.4.2 Audio control**

When the document auto-plays audio that lasts more than three seconds, it shall provide a mechanism to pause, stop, or independently lower the audio volume without requiring the user to change system-wide settings. Documents that do not auto-play audio satisfy the clause by construction.

**Applies to**: Sound in documents.

**WCAG cross-reference**: [sc-1-4-2](../../wcag-22/references/guideline-1-4.md#sc-1-4-2).

**Assessment heuristics**:

* Open the document and confirm whether any audio starts automatically; if it does, time it against the three-second threshold.
* When auto-play exceeds three seconds, verify a pause or stop control is exposed in the document or by the viewer.
* Confirm volume control is independent of the operating system mixer (in-document slider, viewer-level volume control) so users can lower the document's audio without muting other applications.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-1-4-3

**10.1.4.3 Contrast (minimum)**

Body text and images of text in the document shall meet a 4.5 to 1 contrast ratio against their background; large-scale text (18 point regular or 14 point bold and above) shall meet a 3 to 1 ratio. Logotypes and incidental text are exempt.

**Applies to**: Text and graphics in documents.

**WCAG cross-reference**: [sc-1-4-3](../../wcag-22/references/guideline-1-4.md#sc-1-4-3).

**Assessment heuristics**:

* Sample representative body and heading styles on each page background colour and measure the contrast ratio with a colour-contrast tool.
* Verify text that overlays photographs, gradients, or watermarks meets the ratio at the worst-case overlap region.
* Confirm images of text used in the document (banners, diagrams with embedded labels) also meet the ratio, or replace them with live text.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-2-1-1

**10.2.1.1 Keyboard**

Any interactive functionality the document exposes (form fields, buttons, hyperlinks, navigation aids, embedded media controls) shall be operable through a keyboard interface, without requiring specific timings for individual keystrokes. Pointer-only interactions are not acceptable as the sole operating mode.

**Applies to**: Document navigation.

**WCAG cross-reference**: [sc-2-1-1](../../wcag-22/references/guideline-2-1.md#sc-2-1-1).

**Assessment heuristics**:

* Tab through the document and confirm every interactive element receives focus and can be activated with Enter, Space, or the appropriate key for the control type.
* Verify embedded media players expose keyboard-operable play, pause, and seek controls.
* Confirm form submission, signature fields, and bookmark navigation work without the mouse.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-2-1-2

**10.2.1.2 No keyboard trap**

When the keyboard moves focus into any part of the document, focus shall also be able to move away from that part using the keyboard alone. If a non-standard interaction (modal, embedded media, signature pad) requires a particular key to exit, the exit method shall be discoverable.

**Applies to**: Document input.

**WCAG cross-reference**: [sc-2-1-2](../../wcag-22/references/guideline-2-1.md#sc-2-1-2).

**Assessment heuristics**:

* Tab forward and backward through every interactive region and confirm focus exits each control without requiring the mouse.
* Test embedded media, scripted forms, and signature widgets; confirm Escape, Tab, or a documented key combination releases focus.
* Verify any documented exit shortcut appears in the document's instructions or tooltip text.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-2-4-2

**10.2.4.2 Page titled**

The document shall carry a title that identifies its topic or purpose. The title shall be stored in the document's metadata (PDF `/Title`, Office document properties, EPUB metadata, ODF meta:title) so viewers and assistive technology can announce it.

**Applies to**: Document identification.

**WCAG cross-reference**: [sc-2-4-2](../../wcag-22/references/guideline-2-4.md#sc-2-4-2).

**Assessment heuristics**:

* Open the document properties dialog and confirm the title field is populated with a descriptive string rather than a file name or boilerplate.
* Configure the viewer to display the document title (Acrobat: View > Page Display > Document Title) and confirm it surfaces in the window chrome.
* Verify automated export pipelines preserve the title across format conversions.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-2-4-3

**10.2.4.3 Focus order**

When the document supports keyboard navigation, focus shall move through interactive elements in an order that preserves meaning and operability. The tab order shall align with the document's reading order and shall not skip past required fields or jump unexpectedly across the page.

**Applies to**: Document focus.

**WCAG cross-reference**: [sc-2-4-3](../../wcag-22/references/guideline-2-4.md#sc-2-4-3).

**Assessment heuristics**:

* Tab through a form-bearing document and confirm focus moves field-by-field in the same order a sighted user would complete the form.
* For PDFs, inspect the Tab Order setting and confirm it is set to "Use Document Structure" rather than the row or column default.
* Verify focus order remains coherent when the document is reflowed for small-screen viewers.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-10-3-1-1

**10.3.1.1 Language of document**

The default human language of the document shall be programmatically identified in the document's metadata or root structure (PDF `/Lang`, Office language property, EPUB `xml:lang` on the root, ODF document language). Assistive technology uses this value to select the correct speech synthesiser and pronunciation rules.

**Applies to**: Document language.

**WCAG cross-reference**: [sc-3-1-1](../../wcag-22/references/guideline-3-1.md#sc-3-1-1).

**Assessment heuristics**:

* Inspect the document properties and confirm the language field is set to a valid BCP 47 tag that matches the document's primary language.
* Open the document with a screen reader configured for a different default language and confirm it switches to the document's declared language during reading.
* Verify automated authoring pipelines emit the language tag rather than relying on viewer defaults.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
