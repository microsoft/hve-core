---
title: "Clause 9: Web"
description: "Clause 9 of EN 301 549 V3.2.1 adopts WCAG 2.1 Level A and AA success criteria wholesale and reapplies them to web pages, web applications, and web content delivered through user agents."
---

# Clause 9: Web

Clause 9 of EN 301 549 V3.2.1 adopts WCAG 2.1 Level A and AA success criteria wholesale and reapplies them to web pages, web applications, and web content delivered through user agents. Each sub-clause is the EN 301 549 web-context obligation that procurement and conformance reports map to: the requirement is the WCAG criterion, and the assessment work is to demonstrate, document, and evidence that the website meets it. Sub-clauses are organised by WCAG principle (1 perceivable, 2 operable, 3 understandable, 4 robust) and inherit the criterion numbering directly, so 9.X.Y.Z always corresponds to WCAG X.Y.Z.

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 9, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording and the linked WCAG 2.2 reference files for criterion-level technical detail.

## clause-9-1-1-1

**9.1.1.1 Non-text content**

Every non-text element on the page (images, icons, charts, image-based form controls, decorative ornaments, CAPTCHA, sensory content) shall expose a programmatic text alternative that conveys equivalent information or function. Decorative-only graphics shall be marked so assistive technology can skip them.

**Applies to**: Images and media.

**WCAG cross-reference**: [sc-1-1-1](../../wcag-22/references/guideline-1-1.md#sc-1-1-1).

**Assessment heuristics**:

* Run an automated scan that flags every `<img>`, `<svg>`, `<canvas>`, CSS background-as-content, and image-based control that lacks an accessible name, then triage manually.
* Confirm decorative graphics use `alt=""`, `role="presentation"`, or `aria-hidden="true"` so screen readers skip them rather than announce filenames.
* Capture the alt-text policy and the list of CAPTCHA/sensory alternatives in the accessibility conformance report so procurers can verify coverage.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-2-1

**9.1.2.1 Audio-only and video-only (prerecorded)**

Prerecorded audio-only content shall have an equivalent text transcript, and prerecorded video-only (silent) content shall have either a text description or an equivalent audio track. The alternative shall be reachable from the same context as the media.

**Applies to**: Prerecorded media.

**WCAG cross-reference**: [sc-1-2-1](../../wcag-22/references/guideline-1-2.md#sc-1-2-1).

**Assessment heuristics**:

* Inventory every audio-only and silent-video asset and verify each links to a transcript or descriptive alternative in the same page region.
* Confirm transcripts capture speaker turns, non-speech audio that carries meaning, and time markers where helpful.
* Verify alternatives are exposed as page content (not stranded behind a "download" link the screen reader cannot locate without instructions).

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-2-2

**9.1.2.2 Captions (prerecorded)**

Prerecorded video with synchronized audio shall include captions for all dialogue and meaningful non-speech audio. Captions shall be synchronized with the soundtrack and shall identify speakers when ambiguity would otherwise arise.

**Applies to**: Prerecorded video.

**WCAG cross-reference**: [sc-1-2-2](../../wcag-22/references/guideline-1-2.md#sc-1-2-2).

**Assessment heuristics**:

* Confirm every prerecorded video bundles a caption track (WebVTT, TTML, or open captions burned into the video) and that the player exposes a caption toggle.
* Spot-check caption timing, accuracy, and speaker identification against the audio.
* Reject auto-generated captions that fall below the procurement quality bar (typical thresholds: >95% word accuracy, <3 second latency, correct punctuation and speaker labels).

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-2-3

**9.1.2.3 Audio description or media alternative (prerecorded)**

Prerecorded video with synchronized audio shall provide either an audio description of essential visual content or a full text media alternative covering both the audio and visual tracks. Audio descriptions shall be inserted during natural pauses in dialogue.

**Applies to**: Prerecorded video.

**WCAG cross-reference**: [sc-1-2-3](../../wcag-22/references/guideline-1-2.md#sc-1-2-3).

**Assessment heuristics**:

* For each prerecorded video, confirm either a descriptive audio track or a full media-alternative document is available and discoverable from the video page.
* Verify the media alternative covers setting, on-screen text, actions, and speaker cues sufficient for a non-sighted user to follow the narrative.
* Confirm the alternative is rendered in accessible HTML or a tagged document rather than only in an image or scanned PDF.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-2-4

**9.1.2.4 Captions (live)**

Live video that carries synchronized audio shall be accompanied by live captions covering all spoken content as it is delivered.

**Applies to**: Live video.

**WCAG cross-reference**: [sc-1-2-4](../../wcag-22/references/guideline-1-2.md#sc-1-2-4).

**Assessment heuristics**:

* Confirm the live-streaming platform supports a live-caption track and that the production workflow assigns either a stenographer, re-speaker, or vetted automated service.
* Measure end-to-end caption latency against the procurement target (typically under 3 seconds) and accuracy during fast or technical speech.
* Verify the caption display does not occlude key visual content and remains visible on small viewports.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-2-5

**9.1.2.5 Audio description (prerecorded)**

Prerecorded video with synchronized audio shall provide an audio description track that narrates essential visual information not conveyed through the existing soundtrack.

**Applies to**: Prerecorded video.

**WCAG cross-reference**: [sc-1-2-5](../../wcag-22/references/guideline-1-2.md#sc-1-2-5).

**Assessment heuristics**:

* Verify each prerecorded video offers either an alternate "with audio description" version or an in-player audio-description toggle.
* Confirm descriptions cover essential setting, character actions, on-screen text, and visual cues, and that they fit within natural dialogue pauses without extending the video timeline.
* Capture the audio-description coverage policy (in-house, vendor, automated) in the conformance report.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-3-1

**9.1.3.1 Info and relationships**

Information, structure, and relationships conveyed visually (headings, lists, tables, form labels, regions, emphasis) shall also be exposed in the page's markup so assistive technology can present the same relationships. Use semantic HTML elements or correct ARIA roles rather than styling alone.

**Applies to**: Page structure.

**WCAG cross-reference**: [sc-1-3-1](../../wcag-22/references/guideline-1-3.md#sc-1-3-1).

**Assessment heuristics**:

* Validate the page outline (headings, landmarks, lists, tables, form groupings) against the visual design and reject any element that conveys structure only through styling.
* Confirm data tables identify header cells; complex tables additionally use `scope`, `headers`, or `id` associations.
* Verify form fields use `<label>` (or `aria-labelledby`/`aria-label`) so screen readers announce field purpose without relying on placeholder text.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-3-2

**9.1.3.2 Meaningful sequence**

Where the sequence in which content is presented affects meaning, the reading order in the DOM (or the source order used by assistive technology) shall match the intended sequence.

**Applies to**: Content order.

**WCAG cross-reference**: [sc-1-3-2](../../wcag-22/references/guideline-1-3.md#sc-1-3-2).

**Assessment heuristics**:

* Disable CSS and confirm the unstyled page still reads in a logical order that preserves meaning.
* Inspect any layout that relies on `order`, `float`, `position: absolute`, or `grid-area` reordering and confirm the DOM order matches the intended reading order.
* Verify screen-reader reading order with NVDA, VoiceOver, and JAWS on representative templates.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-3-3

**9.1.3.3 Sensory characteristics**

Instructions for understanding and operating content shall not rely solely on sensory characteristics such as shape, colour, size, visual location, orientation, or sound.

**Applies to**: Instructions.

**WCAG cross-reference**: [sc-1-3-3](../../wcag-22/references/guideline-1-3.md#sc-1-3-3).

**Assessment heuristics**:

* Search content for purely sensory references ("click the round button", "the menu on the right", "the green item", "after the beep") and require a non-sensory companion cue (label, name, position in list).
* Verify form-error guidance references field names or descriptive text rather than colour or shape only.
* Confirm onboarding and tutorial copy survives a screen-reader read-through without losing instructional meaning.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-3-4

**9.1.3.4 Orientation**

Content shall not restrict its view and operation to a single display orientation (portrait or landscape) unless a specific orientation is essential.

**Applies to**: Responsive pages.

**WCAG cross-reference**: [sc-1-3-4](../../wcag-22/references/guideline-1-3.md#sc-1-3-4).

**Assessment heuristics**:

* Rotate the device or emulator through portrait and landscape on representative pages and confirm the page remains usable in both orientations.
* Inspect the markup for `screen.orientation.lock()` calls or CSS that hides content based on orientation and require a documented essential-use justification.
* Confirm responsive breakpoints accommodate both orientations without requiring horizontal scrolling beyond the reflow allowance.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-3-5

**9.1.3.5 Identify input purpose**

Form fields that collect information about the user shall expose the field's purpose programmatically (typically through HTML `autocomplete` tokens) so user agents and assistive technology can pre-fill or relabel them.

**Applies to**: Form fields.

**WCAG cross-reference**: [sc-1-3-5](../../wcag-22/references/guideline-1-3.md#sc-1-3-5).

**Assessment heuristics**:

* Inventory all fields covered by WCAG's user-information list (name, email, address, phone, payment, etc.) and verify each carries the correct `autocomplete` token.
* Confirm autofill works with browser and password-manager extensions on representative forms.
* Reject fields that disable autocomplete without a documented security justification, since this directly breaks the criterion.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-1

**9.1.4.1 Use of color**

Colour shall not be the sole visual means of conveying information, indicating an action, prompting a response, or distinguishing a visual element.

**Applies to**: Visual design.

**WCAG cross-reference**: [sc-1-4-1](../../wcag-22/references/guideline-1-4.md#sc-1-4-1).

**Assessment heuristics**:

* Render representative screens in greyscale and confirm every status, link, validation cue, chart series, and required-field indicator remains distinguishable.
* Verify links inside body copy carry a non-colour distinguishing affordance (underline, weight, icon) in addition to colour.
* Confirm charts and data visualisations layer pattern, label, or shape on top of colour encoding.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-2

**9.1.4.2 Audio control**

Audio that plays automatically for more than three seconds shall provide a user-accessible mechanism to pause, stop, or independently control its volume, separate from the overall system volume.

**Applies to**: Sound and media.

**WCAG cross-reference**: [sc-1-4-2](../../wcag-22/references/guideline-1-4.md#sc-1-4-2).

**Assessment heuristics**:

* Inventory every page that emits audio on load and confirm either the audio is under three seconds, muted by default, or paired with a visible pause/stop control.
* Verify the control is reachable by keyboard and announced by screen readers.
* Confirm the volume control is independent of system volume so screen-reader users can lower the page audio without losing the assistive-technology track.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-3

**9.1.4.3 Contrast (minimum)**

Visual presentation of text and images of text shall meet a contrast ratio of at least 4.5:1 against the background, or 3:1 for large-scale text (typically 18pt regular or 14pt bold).

**Applies to**: Text and graphics.

**WCAG cross-reference**: [sc-1-4-3](../../wcag-22/references/guideline-1-4.md#sc-1-4-3).

**Assessment heuristics**:

* Run a contrast analyser across the design system tokens and every text-on-image, text-on-gradient, and disabled-state combination.
* Confirm hover, focus, and active states (and any seasonal or branded theming) still pass the threshold rather than only the default state.
* Capture the contrast-token matrix in the conformance report so future theme changes can be regression-tested.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-4

**9.1.4.4 Resize text**

Text shall be resizable up to 200% without loss of content or functionality and without requiring assistive technology (other than browser zoom).

**Applies to**: Text sizing.

**WCAG cross-reference**: [sc-1-4-4](../../wcag-22/references/guideline-1-4.md#sc-1-4-4).

**Assessment heuristics**:

* Zoom representative pages to 200% in the browser and confirm no text is clipped, overlapped, or pushed off-screen and that no interactive control becomes unreachable.
* Verify the design uses relative units (`rem`, `em`, `%`) rather than fixed `px` values for body text and form controls.
* Confirm components such as modals, sticky headers, and toasts continue to behave at 200% zoom.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-5

**9.1.4.5 Images of text**

Where text can be presented as text, images of text shall be avoided. Logos and decorative essential text are the only permitted exceptions.

**Applies to**: Text presentation.

**WCAG cross-reference**: [sc-1-4-5](../../wcag-22/references/guideline-1-4.md#sc-1-4-5).

**Assessment heuristics**:

* Scan the page for `<img>` elements that contain rendered text (banners, hero graphics, infographic labels) and replace with real text wherever the visual treatment does not require an image.
* Confirm any remaining text-in-image carries an alt attribute that exactly matches the depicted text.
* Verify localisation pipelines produce text rather than re-rendered image variants per locale.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-10

**9.1.4.10 Reflow**

Content shall be presentable without loss of information or functionality and without requiring scrolling in two dimensions at a viewport width equivalent to 320 CSS pixels (or height of 256 CSS pixels for content that scrolls horizontally as intended).

**Applies to**: Layout and scrolling.

**WCAG cross-reference**: [sc-1-4-10](../../wcag-22/references/guideline-1-4.md#sc-1-4-10).

**Assessment heuristics**:

* Resize the browser to a 320 CSS-pixel-wide viewport (or zoom to 400% on a 1280-pixel display) and confirm the page reflows to a single column without horizontal scrolling.
* Identify any element that requires two-dimensional scrolling (data tables, charts, code blocks, maps) and confirm it qualifies under the "essential by usage" exception.
* Verify fixed headers, footers, and side panels do not collapse content area below a usable size at the reflow viewport.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-11

**9.1.4.11 Non-text contrast**

Visual presentation of user-interface components (boundaries, focus indicators, states) and graphical objects required to understand content shall have a contrast ratio of at least 3:1 against adjacent colours.

**Applies to**: UI components and graphics.

**WCAG cross-reference**: [sc-1-4-11](../../wcag-22/references/guideline-1-4.md#sc-1-4-11).

**Assessment heuristics**:

* Audit the design system for control boundaries (buttons, inputs, checkboxes, focus rings) and confirm each state meets the 3:1 ratio.
* Confirm meaningful chart, infographic, and icon strokes pass the threshold against their background.
* Reject low-contrast "ghost" buttons and decorative focus indicators that fall below 3:1.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-12

**9.1.4.12 Text spacing**

When users override text spacing (line height to 1.5×, paragraph spacing to 2×, letter spacing to 0.12×, word spacing to 0.16× the font size), no content shall be lost and no functionality shall break.

**Applies to**: Content spacing.

**WCAG cross-reference**: [sc-1-4-12](../../wcag-22/references/guideline-1-4.md#sc-1-4-12).

**Assessment heuristics**:

* Apply a bookmarklet or user stylesheet that injects the four required spacing overrides and confirm representative pages still render without clipped or overlapping text.
* Verify fixed-height containers expand or scroll rather than truncate text when spacing increases.
* Confirm form controls, navigation, and modals retain readable layout under the overrides.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-1-4-13

**9.1.4.13 Content on hover or focus**

Additional content that appears on hover or keyboard focus (tooltips, popovers, custom menus) shall be dismissible, hoverable, and persistent until dismissed, focus moves away, or the information is no longer valid.

**Applies to**: Dynamic content.

**WCAG cross-reference**: [sc-1-4-13](../../wcag-22/references/guideline-1-4.md#sc-1-4-13).

**Assessment heuristics**:

* Inventory tooltips, popovers, and hover menus and confirm Esc dismisses them without moving focus.
* Verify the user can move the pointer onto the new content (to read or interact) without it disappearing.
* Confirm the new content remains visible until the user dismisses it, moves focus, or it becomes invalid; reject auto-hide timers under five seconds.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-1-1

**9.2.1.1 Keyboard**

All functionality of the content shall be operable through a keyboard interface without requiring specific timings for individual keystrokes, except where the underlying function requires input that depends on the path of the user's movement (drawing, gesture).

**Applies to**: Input methods.

**WCAG cross-reference**: [sc-2-1-1](../../wcag-22/references/guideline-2-1.md#sc-2-1-1).

**Assessment heuristics**:

* Unplug the mouse and complete every primary user journey using only the keyboard, including custom components, modals, drag-and-drop, and rich editors.
* Confirm mouse-only handlers (`onmousedown`, `onclick` without keyboard equivalents) have keyboard counterparts (`onkeydown`/`onkeyup` or native interactive elements).
* Document any path-dependent operation that legitimately resists keyboard access and confirm an alternative is offered.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-1-2

**9.2.1.2 No keyboard trap**

If keyboard focus can be moved to a component, focus shall also be removable from that component using only the keyboard, using standard exit keys (Tab/Shift+Tab or Esc) or a documented mechanism.

**Applies to**: Navigation.

**WCAG cross-reference**: [sc-2-1-2](../../wcag-22/references/guideline-2-1.md#sc-2-1-2).

**Assessment heuristics**:

* Tab through every page region (modals, embedded media, custom widgets, iframes) and confirm focus can leave each one without resorting to the mouse.
* Test embedded third-party content (video players, ad slots, payment iframes) for trapping behaviour and document mitigations.
* Confirm modal dialogs implement an Esc-to-close handler and restore focus to the triggering element.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-1-4

**9.2.1.4 Character key shortcuts**

If a keyboard shortcut is implemented using only letter, punctuation, number, or symbol characters, the user shall be able to turn the shortcut off, remap it, or restrict it to fire only when focus is on a relevant control.

**Applies to**: Keyboard bindings.

**WCAG cross-reference**: [sc-2-1-4](../../wcag-22/references/guideline-2-1.md#sc-2-1-4).

**Assessment heuristics**:

* Inventory all single-key shortcuts in the application and verify each is either off by default, remappable, or scoped to focused elements.
* Confirm a settings surface exists to disable or rebind shortcuts and that the setting persists across sessions.
* Test with speech-input users (Dragon, Voice Access) where stray dictation can otherwise trigger destructive shortcuts.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-2-1

**9.2.2.1 Timing adjustable**

For each time limit set by the content, the user shall be able to turn off, adjust, or extend the limit, with documented exceptions for real-time events, essential limits, and limits longer than 20 hours.

**Applies to**: Timed content.

**WCAG cross-reference**: [sc-2-2-1](../../wcag-22/references/guideline-2-2.md#sc-2-2-1).

**Assessment heuristics**:

* Inventory session-timeout, form-completion, quiz, and inactivity-warning timers and confirm each offers a turn-off, adjust, or extend mechanism.
* Verify users receive a warning before the timer expires with at least 20 seconds to extend.
* Document essential time limits (auctions, exam clocks) and confirm they are flagged in the conformance report.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-2-2

**9.2.2.2 Pause, stop, hide**

Moving, blinking, scrolling, or auto-updating content that starts automatically, lasts more than five seconds, and is presented alongside other content shall provide a mechanism for the user to pause, stop, or hide it.

**Applies to**: Animated content.

**WCAG cross-reference**: [sc-2-2-2](../../wcag-22/references/guideline-2-2.md#sc-2-2-2).

**Assessment heuristics**:

* Inventory carousels, marquees, animated banners, ticker feeds, and auto-refreshing widgets and confirm each exposes a pause/stop control.
* Verify the control is operable by keyboard and announced by screen readers.
* Confirm essential animations (loading spinners, video playback) are excluded only with documented justification.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-3-1

**9.2.3.1 Three flashes or below threshold**

Web pages shall not contain anything that flashes more than three times in any one-second period, or shall ensure the flashing area falls below the general and red-flash thresholds defined in WCAG.

**Applies to**: Animation safety.

**WCAG cross-reference**: [sc-2-3-1](../../wcag-22/references/guideline-2-3.md#sc-2-3-1).

**Assessment heuristics**:

* Run flashing content (animated GIFs, video segments, motion graphics) through PEAT or an equivalent analyser and document any failures.
* Confirm policy gates upload paths so user-generated video that fails the threshold is rejected or muted.
* Document any approved high-risk content behind an explicit warning and a click-through gate.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-4-1

**9.2.4.1 Bypass blocks**

A mechanism shall be provided to bypass blocks of content that are repeated on multiple web pages (typically a "skip to main content" link or properly structured landmark regions).

**Applies to**: Navigation aids.

**WCAG cross-reference**: [sc-2-4-1](../../wcag-22/references/guideline-2-4.md#sc-2-4-1).

**Assessment heuristics**:

* Confirm the page exposes either a visible skip link as the first focusable element or correct ARIA landmarks (`banner`, `navigation`, `main`, `contentinfo`).
* Verify the skip link is announced and focusable, even if visually hidden by default, and that activating it moves focus into the main region.
* Test landmark navigation in NVDA, VoiceOver, and JAWS to confirm regions are reachable.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-4-2

**9.2.4.2 Page titled**

Web pages shall have titles that describe their topic or purpose.

**Applies to**: Page identification.

**WCAG cross-reference**: [sc-2-4-2](../../wcag-22/references/guideline-2-4.md#sc-2-4-2).

**Assessment heuristics**:

* Crawl the site and confirm every page sets a `<title>` element that is unique, descriptive, and front-loaded with the most distinguishing information.
* Verify single-page-application route changes update the document title programmatically.
* Reject placeholder titles ("Untitled", "Document", template strings) in the production build.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-4-3

**9.2.4.3 Focus order**

When users navigate sequentially through content, focus shall move in an order that preserves meaning and operability.

**Applies to**: Keyboard navigation.

**WCAG cross-reference**: [sc-2-4-3](../../wcag-22/references/guideline-2-4.md#sc-2-4-3).

**Assessment heuristics**:

* Tab through every page region and confirm focus follows the visual reading order without unexpected jumps.
* Reject positive `tabindex` values that override natural document order except where rigorously justified.
* Confirm modals, drawers, and inline panels trap focus appropriately and restore focus to a logical location on close.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-4-4

**9.2.4.4 Link purpose (in context)**

The purpose of each link shall be determinable from the link text alone or from the link text together with its programmatically determined context (sentence, paragraph, list item, table cell, or section heading).

**Applies to**: Link text.

**WCAG cross-reference**: [sc-2-4-4](../../wcag-22/references/guideline-2-4.md#sc-2-4-4).

**Assessment heuristics**:

* Extract every link's text and immediate context and confirm the purpose is clear when read in isolation by a screen reader's links list.
* Replace generic "click here", "read more", and "learn more" text with descriptive equivalents or supplement with `aria-label`/`aria-labelledby`.
* Verify icon-only links carry an accessible name from `aria-label`, visually-hidden text, or the surrounding text.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-4-5

**9.2.4.5 Multiple ways**

More than one way shall be available to locate a web page within a set of web pages, except where the page is the result of, or a step in, a process.

**Applies to**: Navigation options.

**WCAG cross-reference**: [sc-2-4-5](../../wcag-22/references/guideline-2-4.md#sc-2-4-5).

**Assessment heuristics**:

* Confirm the site provides at least two of: a search, a sitemap, a table of contents, related-pages list, or a navigation menu that exposes every page.
* Verify the alternative navigation methods are themselves accessible (keyboard, screen reader) and reach the same destination pages.
* Document process-step pages (checkout, wizards) that are properly excluded.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-4-6

**9.2.4.6 Headings and labels**

Headings and form labels shall describe the topic or purpose of the section or field they introduce.

**Applies to**: Content structure.

**WCAG cross-reference**: [sc-2-4-6](../../wcag-22/references/guideline-2-4.md#sc-2-4-6).

**Assessment heuristics**:

* Read the heading outline of each page in isolation and confirm it summarises the page contents.
* Confirm every form field carries a unique, descriptive label that explains what to enter (not just a generic "Field 1" pattern).
* Reject duplicate or ambiguous labels and headings that obscure rather than describe the section.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-4-7

**9.2.4.7 Focus visible**

Any keyboard-operable user-interface component shall have a visible focus indicator when it receives focus.

**Applies to**: Focus indication.

**WCAG cross-reference**: [sc-2-4-7](../../wcag-22/references/guideline-2-4.md#sc-2-4-7).

**Assessment heuristics**:

* Tab through representative pages and confirm every interactive element shows a clearly visible focus indicator that is not removed by `outline: none` without a replacement.
* Verify focus indicators remain visible in dark mode, high-contrast mode, and against busy backgrounds.
* Confirm custom widgets (menubars, listboxes, comboboxes) render a focus ring on the active descendant.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-5-1

**9.2.5.1 Pointer gestures**

All functionality that uses multipoint or path-based gestures (pinch, two-finger swipe, drag-along-a-path) shall also be operable with a single pointer without a path-based gesture, unless such a gesture is essential.

**Applies to**: Gesture interactions.

**WCAG cross-reference**: [sc-2-5-1](../../wcag-22/references/guideline-2-5.md#sc-2-5-1).

**Assessment heuristics**:

* Inventory gestures (pinch-zoom on maps and images, swipe-to-delete on lists, drag-to-reorder, custom touch interactions) and verify each offers a single-point alternative (button, menu, keyboard control).
* Confirm the alternative is reachable on both touch and desktop and is announced to assistive technology.
* Document essential gestures (signature capture, drawing) that legitimately retain a path requirement.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-5-2

**9.2.5.2 Pointer cancellation**

For functionality operated with a single pointer, the down-event shall not execute the action; the action shall fire on the up-event, be abortable before up, or be reversible.

**Applies to**: Pointer activation.

**WCAG cross-reference**: [sc-2-5-2](../../wcag-22/references/guideline-2-5.md#sc-2-5-2).

**Assessment heuristics**:

* Confirm primary actions (form submit, navigation, destructive controls) fire on `click`/`pointerup` rather than `pointerdown`/`mousedown`.
* Verify that dragging off a button before release cancels the action.
* Document essential exceptions (instrument keys in a music app, hold-to-talk) and confirm they are flagged accordingly.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-5-3

**9.2.5.3 Label in name**

For user-interface components with labels that include visible text, the accessible name shall contain the visible text.

**Applies to**: Accessible names.

**WCAG cross-reference**: [sc-2-5-3](../../wcag-22/references/guideline-2-5.md#sc-2-5-3).

**Assessment heuristics**:

* Audit components with visible text labels and confirm the accessible name (computed via `aria-label`, `aria-labelledby`, or content) begins with or contains that visible text.
* Reject `aria-label` overrides that replace the visible text with a different string, since this breaks voice-input ("click Sign up").
* Validate with the browser accessibility tree inspector across a representative component sample.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-2-5-4

**9.2.5.4 Motion actuation**

Functionality that can be operated by device motion (shake, tilt) or user motion (waving in front of a camera) shall also be operable through standard UI controls, and the motion-actuation behaviour shall be disableable.

**Applies to**: Device-motion controls.

**WCAG cross-reference**: [sc-2-5-4](../../wcag-22/references/guideline-2-5.md#sc-2-5-4).

**Assessment heuristics**:

* Inventory motion-triggered features (shake-to-undo, tilt-to-pan, gesture-camera input) and confirm each offers a UI-based alternative.
* Verify a setting exists to disable motion actuation and that the setting persists.
* Confirm involuntary motion (tremor, transport) does not trigger destructive actions in default settings.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-1-1

**9.3.1.1 Language of page**

The default human language of each web page shall be programmatically determined (typically through the `lang` attribute on the root `<html>` element).

**Applies to**: Page language.

**WCAG cross-reference**: [sc-3-1-1](../../wcag-22/references/guideline-3-1.md#sc-3-1-1).

**Assessment heuristics**:

* Confirm every page sets `<html lang="…">` to a valid BCP 47 tag matching the rendered language.
* Verify localisation pipelines emit the language attribute per locale rather than serving a fixed default.
* Capture the language-attribute policy in the conformance report and gate it in CI.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-1-2

**9.3.1.2 Language of parts**

The human language of each passage or phrase whose language differs from the page default shall be programmatically determined.

**Applies to**: Content language.

**WCAG cross-reference**: [sc-3-1-2](../../wcag-22/references/guideline-3-1.md#sc-3-1-2).

**Assessment heuristics**:

* Audit content for embedded quotations, names, and phrases in a language other than the page default and confirm each carries a `lang` attribute on the enclosing element.
* Verify CMS authoring tools expose a language-attribute control to editors.
* Test with a screen reader configured for the page default and confirm it switches voice when reading the tagged phrase.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-2-1

**9.3.2.1 On focus**

When any user-interface component receives focus, it shall not initiate a change of context (new window, focus jump, form submission, major content change).

**Applies to**: Input behavior.

**WCAG cross-reference**: [sc-3-2-1](../../wcag-22/references/guideline-3-2.md#sc-3-2-1).

**Assessment heuristics**:

* Tab through every interactive control and confirm receiving focus does not trigger navigation, submission, or a popup.
* Reject autocomplete dropdowns that move focus or submit on focus rather than on user action.
* Confirm select elements do not navigate on focus change in custom widgets.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-2-2

**9.3.2.2 On input**

Changing the setting of a user-interface component shall not automatically cause a change of context unless the user has been warned before using the component.

**Applies to**: Input changes.

**WCAG cross-reference**: [sc-3-2-2](../../wcag-22/references/guideline-3-2.md#sc-3-2-2).

**Assessment heuristics**:

* Inventory controls that change context on input (select-to-navigate menus, auto-submit toggles, dynamic filter forms) and confirm either the behaviour is removed or an explicit warning precedes the control.
* Provide a submit button for forms that change context, rather than firing on input change.
* Confirm the warning is announced to assistive technology before the control receives focus.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-2-3

**9.3.2.3 Consistent navigation**

Navigational mechanisms that are repeated on multiple pages within a set shall appear in the same relative order each time they are presented.

**Applies to**: Navigation pattern.

**WCAG cross-reference**: [sc-3-2-3](../../wcag-22/references/guideline-3-2.md#sc-3-2-3).

**Assessment heuristics**:

* Compare the global header, footer, sidebar, and breadcrumb regions across a representative sample of pages and confirm element order is consistent.
* Verify user-initiated reordering (drag-to-customise) defaults to the shared baseline and persists per user only.
* Capture the navigation pattern in the design system and gate against drift in CI.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-2-4

**9.3.2.4 Consistent identification**

Components that have the same functionality across pages within a set shall be identified consistently (icon, label, accessible name).

**Applies to**: UI consistency.

**WCAG cross-reference**: [sc-3-2-4](../../wcag-22/references/guideline-3-2.md#sc-3-2-4).

**Assessment heuristics**:

* Inventory recurring controls (search button, print, share, help) and confirm each uses the same icon, label, and accessible name across pages.
* Reject inconsistent labelling like "Search" on one page and "Find" on another for the same component.
* Capture the labelling baseline in the design system content guide.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-3-1

**9.3.3.1 Error identification**

When an input error is automatically detected, the failing item shall be identified and the error described in text.

**Applies to**: Form errors.

**WCAG cross-reference**: [sc-3-3-1](../../wcag-22/references/guideline-3-3.md#sc-3-3-1).

**Assessment heuristics**:

* Trigger validation errors on representative forms and confirm each failing field is identified by name and the error is described in text (not just colour or icon).
* Verify error messages are associated with their inputs via `aria-describedby` or programmatic relationship so screen readers announce them.
* Confirm summary error messages link to the offending fields.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-3-2

**9.3.3.2 Labels or instructions**

Labels or instructions shall be provided when content requires user input.

**Applies to**: Form guidance.

**WCAG cross-reference**: [sc-3-3-2](../../wcag-22/references/guideline-3-3.md#sc-3-3-2).

**Assessment heuristics**:

* Confirm every form field carries a persistent visible label (not placeholder text alone) and supplementary instructions for any non-obvious format requirements.
* Verify required fields are identified both visually and programmatically (`aria-required`, `required`).
* Confirm format hints (date format, password rules) are visible before the user begins typing rather than only on error.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-3-3

**9.3.3.3 Error suggestion**

When an input error is automatically detected and suggestions for correction are known, the suggestions shall be provided to the user unless doing so would jeopardise security or the purpose of the content.

**Applies to**: Error recovery.

**WCAG cross-reference**: [sc-3-3-3](../../wcag-22/references/guideline-3-3.md#sc-3-3-3).

**Assessment heuristics**:

* Audit validation messages and confirm each one offers a concrete correction suggestion (expected format, allowed values, closest match) where suggestions are derivable.
* Reject vague "Invalid input" messages in favour of actionable guidance.
* Document security-sensitive fields (e.g. credentials) where suggestions are intentionally withheld.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-3-3-4

**9.3.3.4 Error prevention (legal, financial, data)**

For pages that cause legal commitments, financial transactions, modify or delete user-controlled data, or submit test responses, submissions shall be reversible, checked for input errors with a chance to correct, or confirmed before final submission.

**Applies to**: Critical input.

**WCAG cross-reference**: [sc-3-3-4](../../wcag-22/references/guideline-3-3.md#sc-3-3-4).

**Assessment heuristics**:

* Inventory checkout, contract-signing, data-deletion, and exam-submission flows and confirm each offers reversal, validation-with-correction, or an explicit confirmation step.
* Verify the confirmation surface displays the data that will be committed in a reviewable format.
* Confirm destructive actions outside these flows (account deletion, bulk operations) follow the same pattern.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-4-1-1

**9.4.1.1 Parsing**

In content implemented using markup languages, elements shall have complete start and end tags, shall be nested according to specification, shall not contain duplicate attributes, and any IDs shall be unique. (EN 301 549 V3.2.1 inherits this from WCAG 2.1; WCAG 2.2 has since deprecated it, but the criterion remains in force for EN 301 549 conformance.)

**Applies to**: Code validity.

**WCAG cross-reference**: [sc-4-1-1](../../wcag-22/references/guideline-4-1.md#sc-4-1-1).

**Assessment heuristics**:

* Run an HTML validator across representative pages and triage parse errors that would affect assistive-technology interpretation.
* Audit for duplicate `id` attributes that break label, `aria-describedby`, and `aria-labelledby` associations.
* Confirm dynamic content updates (SPA route changes, component re-renders) preserve unique IDs and valid nesting.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-4-1-2

**9.4.1.2 Name, role, value**

For all user-interface components, the name and role shall be programmatically determined; states, properties, and values that can be set by the user shall be programmatically settable; and notification of changes shall be available to assistive technology.

**Applies to**: Accessible components.

**WCAG cross-reference**: [sc-4-1-2](../../wcag-22/references/guideline-4-1.md#sc-4-1-2).

**Assessment heuristics**:

* Inspect the accessibility tree for every custom component and confirm it exposes a correct role, accessible name, and current state (expanded, selected, checked, pressed).
* Prefer native HTML elements over divs with ARIA where possible; verify ARIA widget patterns follow the ARIA Authoring Practices.
* Test components with NVDA, VoiceOver, and JAWS to confirm state changes are announced.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-9-4-1-3

**9.4.1.3 Status messages**

Status messages (success, error, progress, in-page notifications) shall be programmatically determined through role or property so assistive technology can present them without moving focus.

**Applies to**: Notifications.

**WCAG cross-reference**: [sc-4-1-3](../../wcag-22/references/guideline-4-1.md#sc-4-1-3).

**Assessment heuristics**:

* Inventory toasts, inline confirmations, progress indicators, and validation banners and confirm each uses `role="status"`, `role="alert"`, or an appropriate `aria-live` region.
* Verify the live region is present in the DOM before the message is injected so the announcement fires reliably.
* Confirm urgency and politeness levels (`aria-live="polite"` vs `assertive`) match the message importance.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
