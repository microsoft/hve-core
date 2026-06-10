---
title: "Chapter E205: Electronic Content"
description: "Chapter E205 governs the accessibility of electronic documents and web content delivered by covered ICT, including HTML, PDF, office documents, EPUB, and multimedia."
---

# Chapter E205: Electronic Content

Chapter E205 governs the accessibility of electronic documents and web content delivered by covered ICT, including HTML, PDF, office documents, EPUB, and multimedia. It incorporates the full set of WCAG 2.0 Level A and AA success criteria as the technical conformance baseline and adds clauses that address PDF tagging, captions, audio descriptions, color independence, alternative text, table structure, and form labelling. E205 is the broadest technical chapter and applies whenever content is delivered to users rather than executed as code.

Source: US Access Board, ICT Accessibility 508 Standards, Chapter E205, <https://www.access-board.gov/ict/#e205-electronic-content>.

## clause-e205-1

**E205.1 Scope**

Defines the categories of electronic content covered by chapter E205, including web pages, downloaded documents, email content, embedded media, and content delivered through cloud services or document repositories, regardless of whether the audience is the public or internal staff.

**Applies to**: All electronic documents and web content produced, procured, or maintained by the covered organisation.

**WCAG cross-reference**: n/a (scoping clause).

**Assessment heuristics**:

* Inventory every delivery channel for electronic content (public web, intranet, email attachments, cloud portals) and confirm each is in the assessment scope.
* Treat internal-only content as in scope by default; require explicit, documented justification for any exception.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-2

**E205.2 Technical Standards**

Requires electronic content to conform to applicable W3C technical standards (HTML, CSS, ARIA, PDF/A) and to use semantically correct markup so that assistive technology can perceive content structure, names, and roles.

**Applies to**: Web pages, web applications, and structured document formats where W3C standards apply.

**WCAG cross-reference**: [sc-1-1-1](../../wcag-22/references/guideline-1-1.md#sc-1-1-1), [sc-1-3-1](../../wcag-22/references/guideline-1-3.md#sc-1-3-1), [sc-1-4-3](../../wcag-22/references/guideline-1-4.md#sc-1-4-3), [sc-4-1-2](../../wcag-22/references/guideline-4-1.md#sc-4-1-2).

**Assessment heuristics**:

* Run an HTML and ARIA validator and confirm zero critical errors on representative pages.
* Confirm PDF outputs embed Unicode text and logical structure tags rather than raster images or untagged streams.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-3

**E205.3 PDF**

Requires PDF files to preserve real text as Unicode, expose a logical reading order through PDF tagging, and remain navigable by keyboard and assistive technology; image-only or scanned PDFs that cannot be remediated must be accompanied by an accessible alternative format.

**Applies to**: All PDF documents distributed to users.

**WCAG cross-reference**: [sc-1-1-1](../../wcag-22/references/guideline-1-1.md#sc-1-1-1), [sc-2-1-1](../../wcag-22/references/guideline-2-1.md#sc-2-1-1), [sc-4-1-2](../../wcag-22/references/guideline-4-1.md#sc-4-1-2).

**Assessment heuristics**:

* Generate PDFs from accessible source files (Word, InDesign) using styles, and validate the output with a PDF accessibility checker.
* For scanned PDFs that cannot carry tags, add an OCR text layer or publish a parallel HTML version and link the two together.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-4

**E205.4 Incorporation of WCAG 2.0 Level A and AA**

Requires electronic content to conform to the WCAG 2.0 Level A and Level AA success criteria in their entirety, making WCAG 2.0 AA the primary conformance target for web and document accessibility under Section 508.

**Applies to**: All electronic content within the scope of E205.1.

**WCAG cross-reference**: WCAG 2.0 Level A and Level AA in full (see the sibling `wcag-22` skill for per-criterion detail).

**Assessment heuristics**:

* Run automated WCAG conformance tooling against representative samples and supplement with manual checks targeting cognitive, keyboard, and screen reader scenarios.
* Maintain an accessibility statement that commits to WCAG 2.0 Level AA and lists known gaps with planned remediation dates.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-5

**E205.5 Audio Description**

Requires prerecorded synchronised media to provide audio descriptions of visual information that is essential to understanding the content but is not already conveyed by the main audio track.

**Applies to**: Prerecorded video content with significant visual information.

**WCAG cross-reference**: [sc-1-2-3](../../wcag-22/references/guideline-1-2.md#sc-1-2-3), [sc-1-2-5](../../wcag-22/references/guideline-1-2.md#sc-1-2-5).

**Assessment heuristics**:

* Confirm that each in-scope video carries either an embedded audio description track or a separately published descriptive transcript.
* Audit descriptions for coverage of on-screen text, scene changes, non-verbal action, and speaker identification.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-6

**E205.6 Captions**

Requires synchronised media to include captions that convey dialogue, speaker identification, and sound effects essential to understanding, synchronised with the audio track for both prerecorded and live media.

**Applies to**: All synchronised audio and video content, including live streams.

**WCAG cross-reference**: [sc-1-2-2](../../wcag-22/references/guideline-1-2.md#sc-1-2-2), [sc-1-2-4](../../wcag-22/references/guideline-1-2.md#sc-1-2-4).

**Assessment heuristics**:

* Confirm that captions are toggleable and synchronised to within roughly 100 milliseconds of the audio track.
* Confirm that captions include speaker labels, key sound effects, and significant non-speech audio cues.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-7

**E205.7 Flashing**

Prohibits electronic content from flashing more than three times in any one-second period to reduce the risk of triggering photosensitive seizures.

**Applies to**: All electronic content with animated, video, or auto-refreshing elements.

**WCAG cross-reference**: [sc-2-3-1](../../wcag-22/references/guideline-2-3.md#sc-2-3-1), [sc-2-3-2](../../wcag-22/references/guideline-2-3.md#sc-2-3-2).

**Assessment heuristics**:

* Review animated GIFs, video segments, and CSS animations for flash rates above 3 Hz and remove or replace any that exceed the threshold.
* Add user controls (pause or stop) for any content with motion that approaches the threshold.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-8

**E205.8 Color Dependency**

Prohibits electronic content from relying on colour alone to convey meaning, indicate an action, prompt a response, or distinguish a visual element; colour must always be paired with text, shape, pattern, or other non-colour cues.

**Applies to**: All visual content, including charts, status indicators, links, form validation, and infographics.

**WCAG cross-reference**: [sc-1-4-1](../../wcag-22/references/guideline-1-4.md#sc-1-4-1).

**Assessment heuristics**:

* Inspect status indicators (success, warning, error) and confirm each pairs a colour with a label, icon, or shape.
* Run a colour-blindness simulator over representative charts and dashboards and confirm that no information is lost.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-9

**E205.9 Alt Text**

Requires non-text content (images, graphics, photographs) to carry a text alternative that conveys the purpose or information of the image; decorative content must be marked so assistive technology can skip it.

**Applies to**: All images, icons, charts, and graphical elements in electronic content.

**WCAG cross-reference**: [sc-1-1-1](../../wcag-22/references/guideline-1-1.md#sc-1-1-1).

**Assessment heuristics**:

* Confirm that every meaningful image carries a concise, purpose-specific alt attribute rather than file names or generic phrasing.
* Confirm that decorative images use an empty alt attribute (or equivalent) so screen readers omit them.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-10

**E205.10 Tables**

Requires data tables to expose row and column relationships through markup so that assistive technology can announce header cells alongside their associated data cells.

**Applies to**: Data tables in HTML, office documents, and PDF; not required for purely presentational layout tables.

**WCAG cross-reference**: [sc-1-3-1](../../wcag-22/references/guideline-1-3.md#sc-1-3-1).

**Assessment heuristics**:

* Confirm that HTML tables use header (`<th>`) and data (`<td>`) elements with `scope` or `headers` attributes.
* Confirm that office document tables mark the header row as a repeating header rather than relying on visual styling alone.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## clause-e205-11

**E205.11 Form Labels and Instructions**

Requires form fields to carry visible, programmatically associated labels and any instructions needed to complete the form; error messages must be clearly described and associated with the relevant control.

**Applies to**: All input forms in electronic content, including web forms, fillable PDF forms, and document templates.

**WCAG cross-reference**: [sc-1-3-1](../../wcag-22/references/guideline-1-3.md#sc-1-3-1), [sc-3-2-2](../../wcag-22/references/guideline-3-2.md#sc-3-2-2), [sc-3-3-2](../../wcag-22/references/guideline-3-3.md#sc-3-3-2).

**Assessment heuristics**:

* Confirm that every input has an associated `<label>` element rather than relying on placeholder text alone.
* Confirm that required-field indicators are announced by assistive technology and not communicated only through colour or symbols.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
