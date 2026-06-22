---
title: Section 508 framework reference
description: US Section 508 ICT Refresh (revised 2017) standards packaged as an accessibility assessment knowledge base
---

# Section 508 framework reference

This skill packages the US Section 508 ICT Refresh (revised 2017) standards as an accessibility assessment knowledge base. It covers four normative chapters: E202 (General Requirements), E205 (Electronic Content), E207 (Software), and E208 (Support Documentation and Services). Section 508 incorporates the W3C WCAG 2.0 Level A and AA success criteria by reference, so most clauses below carry WCAG cross-references that link into the sibling [`wcag-22`](wcag-22.md) skill's per-guideline reference files (anchored at `#sc-<n>-<m>-<k>`).

Source: US Access Board, Information and Communication Technology (ICT) Accessibility Standards, <https://www.access-board.gov/ict/>. Section 508 standards are works of the US federal government and reside in the public domain under 17 U.S.C. § 105. Clause summaries in this skill are paraphrased in the authors' own words for stylistic consistency with sibling W3C-licensed framework skills.

## Clause Roll-up

| Clause  | Title                        | Type     | WCAG cross-ref                                                                                                                                                      | Reference                                         |
|---------|------------------------------|----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------|
| E202.1  | Accessibility                | General  | n/a                                                                                                                                                                 | [chapter-e202.md#clause-e202-1](#clause-e202-1)   |
| E202.2  | Definitions                  | General  | n/a                                                                                                                                                                 | [chapter-e202.md#clause-e202-2](#clause-e202-2)   |
| E202.3  | Abbreviations                | General  | n/a                                                                                                                                                                 | [chapter-e202.md#clause-e202-3](#clause-e202-3)   |
| E202.4  | References to WCAG 2.0       | General  | [WCAG 2.0 A/AA (all SCs)](wcag-22.md)                                                                                                                               | [chapter-e202.md#clause-e202-4](#clause-e202-4)   |
| E205.1  | Scope                        | Content  | n/a                                                                                                                                                                 | [chapter-e205.md#clause-e205-1](#clause-e205-1)   |
| E205.2  | Technical Standards          | Content  | [sc-1-1-1](wcag-22.md#sc-1-1-1), [sc-1-3-1](wcag-22.md#sc-1-3-1), [sc-1-4-3](wcag-22.md#sc-1-4-3), [sc-4-1-2](wcag-22.md#sc-4-1-2)                                  | [chapter-e205.md#clause-e205-2](#clause-e205-2)   |
| E205.3  | PDF                          | Content  | [sc-1-1-1](wcag-22.md#sc-1-1-1), [sc-2-1-1](wcag-22.md#sc-2-1-1), [sc-4-1-2](wcag-22.md#sc-4-1-2)                                                                   | [chapter-e205.md#clause-e205-3](#clause-e205-3)   |
| E205.4  | WCAG 2.0 Level A and AA      | Content  | [WCAG 2.0 A/AA (all SCs)](wcag-22.md)                                                                                                                               | [chapter-e205.md#clause-e205-4](#clause-e205-4)   |
| E205.5  | Audio Description            | Content  | [sc-1-2-3](wcag-22.md#sc-1-2-3), [sc-1-2-5](wcag-22.md#sc-1-2-5)                                                                                                    | [chapter-e205.md#clause-e205-5](#clause-e205-5)   |
| E205.6  | Captions                     | Content  | [sc-1-2-2](wcag-22.md#sc-1-2-2), [sc-1-2-4](wcag-22.md#sc-1-2-4)                                                                                                    | [chapter-e205.md#clause-e205-6](#clause-e205-6)   |
| E205.7  | Flashing                     | Content  | [sc-2-3-1](wcag-22.md#sc-2-3-1), [sc-2-3-2](wcag-22.md#sc-2-3-2)                                                                                                    | [chapter-e205.md#clause-e205-7](#clause-e205-7)   |
| E205.8  | Color Dependency             | Content  | [sc-1-4-1](wcag-22.md#sc-1-4-1)                                                                                                                                     | [chapter-e205.md#clause-e205-8](#clause-e205-8)   |
| E205.9  | Alt Text                     | Content  | [sc-1-1-1](wcag-22.md#sc-1-1-1)                                                                                                                                     | [chapter-e205.md#clause-e205-9](#clause-e205-9)   |
| E205.10 | Tables                       | Content  | [sc-1-3-1](wcag-22.md#sc-1-3-1)                                                                                                                                     | [chapter-e205.md#clause-e205-10](#clause-e205-10) |
| E205.11 | Form Labels and Instructions | Content  | [sc-1-3-1](wcag-22.md#sc-1-3-1), [sc-3-2-2](wcag-22.md#sc-3-2-2), [sc-3-3-2](wcag-22.md#sc-3-3-2)                                                                   | [chapter-e205.md#clause-e205-11](#clause-e205-11) |
| E207.1  | Scope                        | Software | n/a                                                                                                                                                                 | [chapter-e207.md#clause-e207-1](#clause-e207-1)   |
| E207.2  | General Exceptions           | Software | n/a                                                                                                                                                                 | [chapter-e207.md#clause-e207-2](#clause-e207-2)   |
| E207.3  | User Interface Standards     | Software | [sc-1-4-3](wcag-22.md#sc-1-4-3), [sc-2-1-1](wcag-22.md#sc-2-1-1)                                                                                                    | [chapter-e207.md#clause-e207-3](#clause-e207-3)   |
| E207.4  | Keyboard                     | Software | [sc-2-1-1](wcag-22.md#sc-2-1-1), [sc-2-1-2](wcag-22.md#sc-2-1-2)                                                                                                    | [chapter-e207.md#clause-e207-4](#clause-e207-4)   |
| E207.5  | Keyboard Focus               | Software | [sc-2-4-3](wcag-22.md#sc-2-4-3), [sc-2-4-7](wcag-22.md#sc-2-4-7)                                                                                                    | [chapter-e207.md#clause-e207-5](#clause-e207-5)   |
| E207.6  | Status, Prompts, and Results | Software | [sc-3-2-1](wcag-22.md#sc-3-2-1), [sc-3-2-2](wcag-22.md#sc-3-2-2), [sc-4-1-3](wcag-22.md#sc-4-1-3)                                                                   | [chapter-e207.md#clause-e207-6](#clause-e207-6)   |
| E207.7  | Contrast                     | Software | [sc-1-4-3](wcag-22.md#sc-1-4-3)                                                                                                                                     | [chapter-e207.md#clause-e207-7](#clause-e207-7)   |
| E207.8  | Flashing                     | Software | [sc-2-3-1](wcag-22.md#sc-2-3-1), [sc-2-3-2](wcag-22.md#sc-2-3-2)                                                                                                    | [chapter-e207.md#clause-e207-8](#clause-e207-8)   |
| E207.9  | Controls                     | Software | [sc-2-1-1](wcag-22.md#sc-2-1-1), [sc-2-5-5](wcag-22.md#sc-2-5-5), [sc-3-2-1](wcag-22.md#sc-3-2-1), [sc-3-2-4](wcag-22.md#sc-3-2-4)                                  | [chapter-e207.md#clause-e207-9](#clause-e207-9)   |
| E207.10 | Text Properties              | Software | [sc-1-4-12](wcag-22.md#sc-1-4-12)                                                                                                                                   | [chapter-e207.md#clause-e207-10](#clause-e207-10) |
| E207.11 | Animation and Motion         | Software | [sc-2-3-3](wcag-22.md#sc-2-3-3)                                                                                                                                     | [chapter-e207.md#clause-e207-11](#clause-e207-11) |
| E208.1  | Scope                        | Support  | n/a                                                                                                                                                                 | [chapter-e208.md#clause-e208-1](#clause-e208-1)   |
| E208.2  | General                      | Support  | n/a                                                                                                                                                                 | [chapter-e208.md#clause-e208-2](#clause-e208-2)   |
| E208.3  | User Support Services        | Support  | n/a                                                                                                                                                                 | [chapter-e208.md#clause-e208-3](#clause-e208-3)   |
| E208.4  | Accessible Documentation     | Support  | [sc-1-1-1](wcag-22.md#sc-1-1-1), [sc-1-3-1](wcag-22.md#sc-1-3-1), [sc-1-4-3](wcag-22.md#sc-1-4-3), [sc-2-1-1](wcag-22.md#sc-2-1-1), [sc-4-1-2](wcag-22.md#sc-4-1-2) | [chapter-e208.md#clause-e208-4](#clause-e208-4)   |

Total: 30 clauses (E202: 4; E205: 11; E207: 11; E208: 4).

## Assessment Heuristics

Use these heuristics when applying the Section 508 standard against an ICT artifact:

* Treat WCAG 2.0 Level AA conformance as the baseline target for any electronic content covered by E205, and confirm it by running WCAG-based automated tooling plus targeted manual checks for each cited SC.
* For software covered by E207, validate keyboard operation, visible focus, status announcements, and 4.5:1 contrast first; these account for the majority of real-world Section 508 findings.
* For PDF and office documents under E205.3, verify the source authoring tool produced a tagged structure rather than relying on post-hoc remediation, and provide an HTML alternative whenever a scanned PDF cannot be tagged.
* For documentation and support under E208, audit each support channel (phone, chat, email, training) for an equivalent accessible path before treating documentation alone as compliant.
* When a clause is marked `n/a` for WCAG cross-reference, treat the Access Board URL as the authoritative source and rely on procurement and policy controls rather than automated WCAG tooling.
* Record every E207.2 exception with a documented rationale, a mitigation plan, and a review date so the exception does not silently expand over time.

## Chapter E202: General Requirements

Chapter E202 sets the foundational scope, vocabulary, and normative framing for the Section 508 ICT Refresh standard. It establishes accessibility as a mandatory conformance requirement for ICT procured, developed, or maintained by US federal agencies, defines the technical terminology used throughout chapters E205–E208, and incorporates WCAG 2.0 Level A and AA by reference as the underlying technical baseline for electronic content and software.

Source: US Access Board, ICT Accessibility 508 Standards, Chapter E202, <https://www.access-board.gov/ict/#e202-general-requirements>.

### clause-e202-1

**E202.1 Accessibility**

Information and communication technology covered by Section 508 must be accessible to people with disabilities; conformance with chapters E202 through E208 is mandatory whenever covered ICT is procured, developed, maintained, or used.

**Applies to**: All covered ICT (electronic content, software, hardware, and support services) across the procurement and lifecycle scope of Section 508.

**WCAG cross-reference**: n/a (scoping statement; downstream clauses carry the WCAG criteria).

**Assessment heuristics**:

* Confirm that procurement and contracting policy names Section 508 conformance as a gating criterion rather than a preference.
* Confirm that accessibility work is scheduled inside the product development lifecycle rather than treated as a post-release remediation activity.

Source: <https://www.access-board.gov/ict/#e202-general-requirements>

### clause-e202-2

**E202.2 Definitions**

Establishes the normative vocabulary used across the standard, including terms such as electronic content, software, user interface, assistive technology, and the accessibility principles (perceivable, operable, understandable) carried forward from WCAG 2.0.

**Applies to**: Interpretation of all clauses in chapters E202–E208; binding when resolving disputes over the meaning of standard terms.

**WCAG cross-reference**: n/a (definitional content).

**Assessment heuristics**:

* Check that procurement language, contract clauses, and team glossaries use these definitions verbatim rather than synonyms.
* Resolve disagreement about whether a component is in scope by mapping the component to a defined term (for example, distinguishing electronic content from software).

Source: <https://www.access-board.gov/ict/#e202-general-requirements>

### clause-e202-3

**E202.3 Abbreviations**

Lists the abbreviations used throughout the standard, including WCAG, HTML, PDF, and ARIA, so that downstream technical clauses are unambiguous for procurement officers, developers, and assessors.

**Applies to**: All written use of standard abbreviations in conformance documentation, procurement RFPs, vendor responses, and accessibility reports.

**WCAG cross-reference**: n/a (definitional content).

**Assessment heuristics**:

* Confirm that vendor accessibility conformance reports use the abbreviations defined here rather than agency-specific shorthand.
* Treat non-standard abbreviations in conformance documentation as a documentation defect.

Source: <https://www.access-board.gov/ict/#e202-general-requirements>

### clause-e202-4

**E202.4 References to WCAG 2.0**

Incorporates the W3C Web Content Accessibility Guidelines 2.0 Level A and Level AA success criteria into the Section 508 standard by reference, so that conformance to the technical chapters (E205 through E208) carries with it conformance to every cited WCAG 2.0 success criterion.

**Applies to**: All technical conformance work under E205 (electronic content), E207 (software), and E208 (support documentation) where WCAG 2.0 criteria are cited.

**WCAG cross-reference**: WCAG 2.0 Level A and Level AA in full (see the sibling `wcag-22` skill for per-criterion detail).

**Assessment heuristics**:

* Treat WCAG 2.0 Level AA as the default technical baseline for any electronic content covered by E205.
* Treat WCAG 2.0 criteria as the authoritative technical text when the Access Board chapter language is silent on a specific implementation detail.

Source: <https://www.access-board.gov/ict/#e202-general-requirements>

## Chapter E205: Electronic Content

Chapter E205 governs the accessibility of electronic documents and web content delivered by covered ICT, including HTML, PDF, office documents, EPUB, and multimedia. It incorporates the full set of WCAG 2.0 Level A and AA success criteria as the technical conformance baseline and adds clauses that address PDF tagging, captions, audio descriptions, color independence, alternative text, table structure, and form labelling. E205 is the broadest technical chapter and applies whenever content is delivered to users rather than executed as code.

Source: US Access Board, ICT Accessibility 508 Standards, Chapter E205, <https://www.access-board.gov/ict/#e205-electronic-content>.

### clause-e205-1

**E205.1 Scope**

Defines the categories of electronic content covered by chapter E205, including web pages, downloaded documents, email content, embedded media, and content delivered through cloud services or document repositories, regardless of whether the audience is the public or internal staff.

**Applies to**: All electronic documents and web content produced, procured, or maintained by the covered organisation.

**WCAG cross-reference**: n/a (scoping clause).

**Assessment heuristics**:

* Inventory every delivery channel for electronic content (public web, intranet, email attachments, cloud portals) and confirm each is in the assessment scope.
* Treat internal-only content as in scope by default; require explicit, documented justification for any exception.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-2

**E205.2 Technical Standards**

Requires electronic content to conform to applicable W3C technical standards (HTML, CSS, ARIA, PDF/A) and to use semantically correct markup so that assistive technology can perceive content structure, names, and roles.

**Applies to**: Web pages, web applications, and structured document formats where W3C standards apply.

**WCAG cross-reference**: [sc-1-1-1](wcag-22.md#sc-1-1-1), [sc-1-3-1](wcag-22.md#sc-1-3-1), [sc-1-4-3](wcag-22.md#sc-1-4-3), [sc-4-1-2](wcag-22.md#sc-4-1-2).

**Assessment heuristics**:

* Run an HTML and ARIA validator and confirm zero critical errors on representative pages.
* Confirm PDF outputs embed Unicode text and logical structure tags rather than raster images or untagged streams.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-3

**E205.3 PDF**

Requires PDF files to preserve real text as Unicode, expose a logical reading order through PDF tagging, and remain navigable by keyboard and assistive technology; image-only or scanned PDFs that cannot be remediated must be accompanied by an accessible alternative format.

**Applies to**: All PDF documents distributed to users.

**WCAG cross-reference**: [sc-1-1-1](wcag-22.md#sc-1-1-1), [sc-2-1-1](wcag-22.md#sc-2-1-1), [sc-4-1-2](wcag-22.md#sc-4-1-2).

**Assessment heuristics**:

* Generate PDFs from accessible source files (Word, InDesign) using styles, and validate the output with a PDF accessibility checker.
* For scanned PDFs that cannot carry tags, add an OCR text layer or publish a parallel HTML version and link the two together.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-4

**E205.4 Incorporation of WCAG 2.0 Level A and AA**

Requires electronic content to conform to the WCAG 2.0 Level A and Level AA success criteria in their entirety, making WCAG 2.0 AA the primary conformance target for web and document accessibility under Section 508.

**Applies to**: All electronic content within the scope of E205.1.

**WCAG cross-reference**: WCAG 2.0 Level A and Level AA in full (see the sibling `wcag-22` skill for per-criterion detail).

**Assessment heuristics**:

* Run automated WCAG conformance tooling against representative samples and supplement with manual checks targeting cognitive, keyboard, and screen reader scenarios.
* Maintain an accessibility statement that commits to WCAG 2.0 Level AA and lists known gaps with planned remediation dates.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-5

**E205.5 Audio Description**

Requires prerecorded synchronised media to provide audio descriptions of visual information that is essential to understanding the content but is not already conveyed by the main audio track.

**Applies to**: Prerecorded video content with significant visual information.

**WCAG cross-reference**: [sc-1-2-3](wcag-22.md#sc-1-2-3), [sc-1-2-5](wcag-22.md#sc-1-2-5).

**Assessment heuristics**:

* Confirm that each in-scope video carries either an embedded audio description track or a separately published descriptive transcript.
* Audit descriptions for coverage of on-screen text, scene changes, non-verbal action, and speaker identification.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-6

**E205.6 Captions**

Requires synchronised media to include captions that convey dialogue, speaker identification, and sound effects essential to understanding, synchronised with the audio track for both prerecorded and live media.

**Applies to**: All synchronised audio and video content, including live streams.

**WCAG cross-reference**: [sc-1-2-2](wcag-22.md#sc-1-2-2), [sc-1-2-4](wcag-22.md#sc-1-2-4).

**Assessment heuristics**:

* Confirm that captions are toggleable and synchronised to within roughly 100 milliseconds of the audio track.
* Confirm that captions include speaker labels, key sound effects, and significant non-speech audio cues.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-7

**E205.7 Flashing**

Prohibits electronic content from flashing more than three times in any one-second period to reduce the risk of triggering photosensitive seizures.

**Applies to**: All electronic content with animated, video, or auto-refreshing elements.

**WCAG cross-reference**: [sc-2-3-1](wcag-22.md#sc-2-3-1), [sc-2-3-2](wcag-22.md#sc-2-3-2).

**Assessment heuristics**:

* Review animated GIFs, video segments, and CSS animations for flash rates above 3 Hz and remove or replace any that exceed the threshold.
* Add user controls (pause or stop) for any content with motion that approaches the threshold.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-8

**E205.8 Color Dependency**

Prohibits electronic content from relying on colour alone to convey meaning, indicate an action, prompt a response, or distinguish a visual element; colour must always be paired with text, shape, pattern, or other non-colour cues.

**Applies to**: All visual content, including charts, status indicators, links, form validation, and infographics.

**WCAG cross-reference**: [sc-1-4-1](wcag-22.md#sc-1-4-1).

**Assessment heuristics**:

* Inspect status indicators (success, warning, error) and confirm each pairs a colour with a label, icon, or shape.
* Run a colour-blindness simulator over representative charts and dashboards and confirm that no information is lost.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-9

**E205.9 Alt Text**

Requires non-text content (images, graphics, photographs) to carry a text alternative that conveys the purpose or information of the image; decorative content must be marked so assistive technology can skip it.

**Applies to**: All images, icons, charts, and graphical elements in electronic content.

**WCAG cross-reference**: [sc-1-1-1](wcag-22.md#sc-1-1-1).

**Assessment heuristics**:

* Confirm that every meaningful image carries a concise, purpose-specific alt attribute rather than file names or generic phrasing.
* Confirm that decorative images use an empty alt attribute (or equivalent) so screen readers omit them.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-10

**E205.10 Tables**

Requires data tables to expose row and column relationships through markup so that assistive technology can announce header cells alongside their associated data cells.

**Applies to**: Data tables in HTML, office documents, and PDF; not required for purely presentational layout tables.

**WCAG cross-reference**: [sc-1-3-1](wcag-22.md#sc-1-3-1).

**Assessment heuristics**:

* Confirm that HTML tables use header (`<th>`) and data (`<td>`) elements with `scope` or `headers` attributes.
* Confirm that office document tables mark the header row as a repeating header rather than relying on visual styling alone.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

### clause-e205-11

**E205.11 Form Labels and Instructions**

Requires form fields to carry visible, programmatically associated labels and any instructions needed to complete the form; error messages must be clearly described and associated with the relevant control.

**Applies to**: All input forms in electronic content, including web forms, fillable PDF forms, and document templates.

**WCAG cross-reference**: [sc-1-3-1](wcag-22.md#sc-1-3-1), [sc-3-2-2](wcag-22.md#sc-3-2-2), [sc-3-3-2](wcag-22.md#sc-3-3-2).

**Assessment heuristics**:

* Confirm that every input has an associated `<label>` element rather than relying on placeholder text alone.
* Confirm that required-field indicators are announced by assistive technology and not communicated only through colour or symbols.

Source: <https://www.access-board.gov/ict/#e205-electronic-content>

## Chapter E207: Software

Chapter E207 governs accessibility for software applications, operating systems, and graphical user interfaces. It carries forward the WCAG 2.0 conformance baseline established in E205 and adapts it to non-web software contexts where HTML and browser APIs may be unavailable, addressing keyboard operation, focus management, contrast, controls, text customisation, and motion. Software in scope includes desktop applications, mobile applications, embedded systems, and any user-facing application or platform component.

Source: US Access Board, ICT Accessibility 508 Standards, Chapter E207, <https://www.access-board.gov/ict/#e207-software>.

### clause-e207-1

**E207.1 Scope**

Defines the scope of chapter E207 as all custom and third-party software components with a user interface, including desktop applications, mobile applications, browser extensions, authoring tools, and middleware that surface user-facing functionality.

**Applies to**: Any software component a user interacts with directly or indirectly through an interface.

**WCAG cross-reference**: n/a (scoping clause).

**Assessment heuristics**:

* Enumerate first-party and third-party software in the assessment, including embedded or OEM components.
* Treat documentation and support material accompanying covered software as covered by E208 rather than excluded.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-2

**E207.2 General Exceptions**

Permits narrow exceptions for software that is not user-facing or for which accessibility is technically infeasible, provided the exception is documented and does not reduce conformance expectations for the broader product.

**Applies to**: Backend services, administrative tools, and embedded subsystems claimed to be out of scope.

**WCAG cross-reference**: n/a (exception clause).

**Assessment heuristics**:

* Require every exception to document its rationale, its mitigation (alternative access path), and a review cadence.
* Re-evaluate each exception when supporting technology changes or when the in-scope user base changes.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-3

**E207.3 User Interface Standards**

Requires software user interfaces to conform to applicable platform accessibility standards (Windows UI Automation, macOS Accessibility, Android Accessibility Framework, iOS UIAccessibility, ARIA for web-based UIs) and to follow platform interaction guidelines.

**Applies to**: All user interface code for covered software.

**WCAG cross-reference**: [sc-1-4-3](wcag-22.md#sc-1-4-3), [sc-2-1-1](wcag-22.md#sc-2-1-1).

**Assessment heuristics**:

* Inspect the UI tree with the platform's accessibility inspector and confirm names, roles, states, and values are exposed.
* Confirm web-based interfaces use ARIA roles only where native HTML semantics do not already provide the correct affordance.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-4

**E207.4 Keyboard**

Requires every software function to be operable through a keyboard interface without requiring specific timings for individual keystrokes, and prohibits keyboard traps that prevent the user from moving focus away from a component.

**Applies to**: All keyboard-operable workflows in covered software.

**WCAG cross-reference**: [sc-2-1-1](wcag-22.md#sc-2-1-1), [sc-2-1-2](wcag-22.md#sc-2-1-2).

**Assessment heuristics**:

* Walk every primary task with the keyboard only, verifying that focus reaches and operates every interactive component.
* Confirm modal dialogs, embedded pickers, and custom widgets release focus when dismissed.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-5

**E207.5 Keyboard Focus**

Requires the current keyboard focus to be visibly indicated and to move through interactive components in a logical, predictable order; focus must not move unexpectedly without an explicit user action.

**Applies to**: All software with keyboard navigation.

**WCAG cross-reference**: [sc-2-4-3](wcag-22.md#sc-2-4-3), [sc-2-4-7](wcag-22.md#sc-2-4-7).

**Assessment heuristics**:

* Confirm the focus indicator has sufficient contrast against both focused and unfocused backgrounds, and is not suppressed by the application's stylesheet.
* Verify tab order matches the logical reading order of the interface rather than the DOM source order.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-6

**E207.6 Status, Prompts, and Results**

Requires software to provide clear status messages, prompts, and result feedback so that assistive technology users can perceive system state changes without losing keyboard focus.

**Applies to**: All software workflows that produce user-visible status, error, or confirmation messages.

**WCAG cross-reference**: [sc-3-2-1](wcag-22.md#sc-3-2-1), [sc-3-2-2](wcag-22.md#sc-3-2-2), [sc-4-1-3](wcag-22.md#sc-4-1-3).

**Assessment heuristics**:

* Confirm transient messages (toasts, banners) use `aria-live` regions or platform-equivalent announcement APIs.
* Confirm error messages describe the problem and recommend a remedy in plain language.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-7

**E207.7 Contrast**

Requires text and meaningful UI elements to meet minimum contrast ratios: 4.5:1 for body text and 3:1 for large text and non-text UI components such as borders, icons, and focus indicators.

**Applies to**: All visible UI elements in covered software.

**WCAG cross-reference**: [sc-1-4-3](wcag-22.md#sc-1-4-3).

**Assessment heuristics**:

* Audit screens with a contrast analyser, sampling primary and secondary themes (light, dark, high-contrast).
* Confirm disabled states are still distinguishable from enabled states without dropping below contrast thresholds for elements that remain readable.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-8

**E207.8 Flashing**

Prohibits software animations, progress indicators, and auto-refreshing content from flashing more than three times per second.

**Applies to**: All animated and auto-updating UI elements.

**WCAG cross-reference**: [sc-2-3-1](wcag-22.md#sc-2-3-1), [sc-2-3-2](wcag-22.md#sc-2-3-2).

**Assessment heuristics**:

* Review progress indicators, loading spinners, and notification animations for flash rates above 3 Hz.
* Provide a mechanism to pause or disable any content that flashes near the threshold.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-9

**E207.9 Controls**

Requires interactive controls (buttons, checkboxes, sliders, menu items) to be operable by keyboard and by standard input devices, with consistent activation semantics across the application.

**Applies to**: All interactive UI controls in covered software.

**WCAG cross-reference**: [sc-2-1-1](wcag-22.md#sc-2-1-1), [sc-2-5-5](wcag-22.md#sc-2-5-5), [sc-3-2-1](wcag-22.md#sc-3-2-1), [sc-3-2-4](wcag-22.md#sc-3-2-4).

**Assessment heuristics**:

* Confirm controls follow platform conventions (Enter or Space for buttons, Space for checkboxes, arrow keys for sliders and option lists).
* Confirm similarly named controls behave consistently across screens, especially in long-form workflows.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-10

**E207.10 Text Properties**

Requires software to allow customisation of text presentation (line height, letter spacing, word spacing, alignment) without loss of content or functionality.

**Applies to**: All text-presenting software where user-controlled text properties are technically possible.

**WCAG cross-reference**: [sc-1-4-12](wcag-22.md#sc-1-4-12).

**Assessment heuristics**:

* Verify the application honours OS-level text scaling and contrast settings.
* Confirm text reflows rather than truncating when spacing or font size is increased.

Source: <https://www.access-board.gov/ict/#e207-software>

### clause-e207-11

**E207.11 Animation and Motion**

Requires software to avoid auto-playing animations that may disorient users with vestibular conditions and to honour user preferences such as the operating system's reduced-motion setting.

**Applies to**: All software with animated transitions, parallax effects, or auto-playing motion.

**WCAG cross-reference**: [sc-2-3-3](wcag-22.md#sc-2-3-3).

**Assessment heuristics**:

* Confirm the application respects `prefers-reduced-motion` (or platform equivalent) and disables or shortens non-essential animation.
* Provide an in-application setting to disable decorative motion independent of the OS preference.

Source: <https://www.access-board.gov/ict/#e207-software>

## Chapter E208: Support Documentation and Services

Chapter E208 governs the accessibility of documentation and support services that accompany covered ICT, including user manuals, help systems, training materials, knowledge bases, and human support channels such as phone, chat, and email. Documentation is treated as part of the product itself: if the product is accessible but the documentation is not, the product is not in conformance. Support services must offer equivalent accommodations for users with disabilities (TTY, video relay, accessible chat, alternative formats).

Source: US Access Board, ICT Accessibility 508 Standards, Chapter E208, <https://www.access-board.gov/ict/#e208-support-documentation-and-services>.

### clause-e208-1

**E208.1 Scope**

Defines the scope of chapter E208 to include all documentation and support services associated with covered ICT, whether delivered in-product, online, in print, or through human support channels.

**Applies to**: All documentation and support deliverables accompanying covered ICT.

**WCAG cross-reference**: n/a (scoping clause).

**Assessment heuristics**:

* Inventory the documentation and support footprint (in-product help, manuals, knowledge bases, training, phone, chat, email).
* Treat documentation supplied by third-party vendors as in scope when it accompanies a procured covered ICT product.

Source: <https://www.access-board.gov/ict/#e208-support-documentation-and-services>

### clause-e208-2

**E208.2 General**

Establishes that accessibility of documentation and support is a conformance requirement rather than a recommendation, on the same footing as the underlying product or service.

**Applies to**: Documentation and support deliverables in the scope of E208.1.

**WCAG cross-reference**: n/a (conformance statement).

**Assessment heuristics**:

* Confirm that the organisation's documentation and support policy commits to accessibility and assigns ownership for the commitment.
* Confirm that accessibility accommodation requests have a tracked response time and a published escalation path.

Source: <https://www.access-board.gov/ict/#e208-support-documentation-and-services>

### clause-e208-3

**E208.3 User Support Services**

Requires user support services to provide equivalent access for people with disabilities through accommodations such as TTY or relay services for telephone support, video relay services for users who sign, accessible live chat, and email channels with documented response times.

**Applies to**: All human-staffed support channels accompanying covered ICT.

**WCAG cross-reference**: n/a (support service accessibility requirement; underlying technical channels still meet their own clauses).

**Assessment heuristics**:

* Confirm that contact information for accessible support channels (TTY, video relay, accessible chat) is published in a discoverable location alongside the primary contact details.
* Audit the live chat interface for keyboard operability and screen reader compatibility.

Source: <https://www.access-board.gov/ict/#e208-support-documentation-and-services>

### clause-e208-4

**E208.4 Accessible Documentation**

Requires the content and format of documentation to conform to the WCAG 2.0 Level A and AA success criteria that apply to the documentation's delivery format (HTML, tagged PDF, accessible office documents, captioned video tutorials).

**Applies to**: All documentation content delivered to users.

**WCAG cross-reference**: [sc-1-1-1](wcag-22.md#sc-1-1-1), [sc-1-3-1](wcag-22.md#sc-1-3-1), [sc-1-4-3](wcag-22.md#sc-1-4-3), [sc-2-1-1](wcag-22.md#sc-2-1-1), [sc-4-1-2](wcag-22.md#sc-4-1-2).

**Assessment heuristics**:

* Apply the same WCAG 2.0 conformance bar to documentation that applies to the underlying product under E205.4.
* Confirm video tutorials carry captions and audio descriptions, and that documentation search is keyboard-accessible and screen reader friendly.

Source: <https://www.access-board.gov/ict/#e208-support-documentation-and-services>

