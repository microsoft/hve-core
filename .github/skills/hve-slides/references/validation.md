---
description: 'Proportionate source, browser and sharing validation for HVE HTML presentations.'
---

# Validation

## Choose the Evidence Before Editing

Name the changed behavior and its smallest rejecting check. Use existing package tests and
browser tooling; add a test only for a new or changed contract. A sentence correction does
not need a fresh framework audit. A global style change needs broader visual coverage than
a local wording change.

For a scoped update, inspect the changed slides/states and representative shared-component
consumers. For a new deck, global CSS change or major restructuring, cover all slides and
every materially distinct example state. Reuse unaffected evidence only when its source
revision and scope still apply.

## Source and Build Checks

* Check syntax, required mounts, unique slide IDs, valid citation keys and supported demo
  kinds. Keep startup errors visible; missing required source must not produce a blank deck.
* Exercise finite next/back/reset behavior, independent demo state, question/answer pairing,
  and source/diagram or diff/count parity where those features exist.
* Use the selected deck's build/tests and inspect their output. Keep commands scoped to its
  package; do not launch adjacent CI lanes or tools described in example content.
* Verify generated files match current source, declared runtime assets are local or embedded,
  and license notices survive packaging.
* Update directly related README commands and counts. Prefer stable title/ID references to
  slide numbers when describing features likely to move.

A test can report that it rebuilt output; it cannot establish browser execution. Mechanical
checks and screenshot inspection answer different questions.

## Generated HTML and CodeQL

Run `npm run slides:check` before changing or publishing the generated HTML. It rebuilds
ignored intermediate assets, compares every bundle with its current source, and fails
on missing, stale, or orphaned HTML without rewriting the committed bundles. Regenerate
with `npm run slides:build` when the source changes.

CodeQL analyzes generated HTML in its own category. The authored-source categories ignore
`docs/slides/*.html` so embedded third-party code does not mix with first-party results.
A separate job scans the committed bundles with `.github/codeql/generated-slides.yml` under
`/language:javascript-typescript/generated-slides`, which covers the inlined, patched
reveal.js that recipients actually run. Both analyses run only after the source-to-bundle
check passes in a separate job, so generated intermediates do not enter the scan workspace.
Fix a generated-category finding in the deck source or the bundler, never by hand-editing
the bundle, dismissing the alert, or excluding the bundles from analysis. The generated-slides
category is expected to report zero findings; the CodeQL threshold gate fails the job when it
does not. Keep dependency audits and notice checks.

Pull request validation runs a deck's Node tests whenever a file in that deck changes, and
runs the starter's tests with this skill's tests whenever a skill file changes. Dependabot
proposes reveal.js updates for every deck and for the starter. A reveal.js update fails
`npm run slides:check` and `npm run slides:build` until the bundler's patch anchors and
supported version are refreshed as described in [bundling.md](bundling.md), and the
regenerated bundles are committed.

The starter and HVE Updates disable reveal.js `postMessage` commands and events because
they do not need cross-window control. Presenter buttons and local keyboard navigation
remain the supported controls.

## Browser Workflow

Use the host's permitted browser automation or browser canvas. A canvas opening alone is
not execution evidence. Do not use computer-use. If configured browser tooling is missing,
inspect an already available permitted alternative; do not install a browser or start a
service without the required separate permission.

Keep inspection batched:

1. Plan the relevant slide IDs, demo states, viewports and expected outcomes before opening
   a browser. Capture screenshots and computed geometry/contrast information together where
   possible. Use the existing build rather than creating a second preview implementation.
2. Inspect the rendered result at desktop presentation sizes. For the reference layout, use
   1600 by 900 and 1280 by 720; for a new layout, retain those targets or record an approved
   alternative. Check 320px and 390px viewports for readable content and usable controls,
   including every walkthrough state. Verify the unscaled reading layout, 200% browser
   zoom and text-spacing overrides (1.5 line height, 2em paragraph spacing, .12em letter
   spacing and .16em word spacing). Do not treat viewport resizing alone as zoom evidence.
3. Read representative full-size frames and contact sheets for whole-deck composition.
   Compare text baselines, node/edge alignment, content density and bottom-control clearance.
   Compare the bottom chrome with the starter build or `slides/rpi-with-hve` at the same
   viewport: bar height and tone, the deck mark and chapter, the footer divider, and step
   controls inside the walkthrough frame. Check the bar on every slide, because each chapter
   label changes its width, and confirm the bar's contents stay inside it with reading view
   off at the compact and stacked widths. In reading view, presenter and walkthrough buttons
   should be at least 44 CSS pixels tall. For every walkthrough step, confirm from geometry
   that content ends above the frame footer and that the frame body does not scroll.
   Viewer overlays such as SharePoint's Copilot button do not appear in a local browser, so
   confirm from geometry that the chapter label and slide navigation stay inside the bar inset.
   Computed overflow alone misses obscured elements, wrapping and poor visual hierarchy.
4. Gather all material findings, apply one compatible correction batch, then verify the
   affected final states. Run another pass only for a remaining defect, new evidence or
   changed scope; do not loop through cosmetic alternatives without a reason.

When a design hook is active, consume its findings instead of launching a duplicate detector.
Classify false positives narrowly against the actual brief. A clean detector is not proof
of good design; preserve user-approved screenshot fidelity and literal technical distinctions.

## Interaction Checks

Use actual browser inputs, not only calls to internal transition functions.

* Slide keys/buttons, first/last boundaries, slide index, hash navigation and reload work.
* Each walkthrough moves forward/back, reaches its endpoints and resets independently.
* Local toggles and reconstructed walkthrough buttons perform only their declared local
  behavior; display-only chrome does not become a dead keyboard stop or execute real tools.
* Left / Right and Page Up / Page Down still change slides after a presenter button or
  link is clicked. Text entry, dialogs, components that claim those keys and modifier
  shortcuts keep them, as does selected text unless a button or link has focus. Focused
  controls keep Space, Enter and character keys.
* Dialog Tab/Shift+Tab, Escape, focus return and reopening work. Scrolling one dialog must
  not hide the top of the next view. Close controls remain reachable on narrow screens.
* Optional motion settles, reduced motion overrides it, and leaving a slide does not leave
  an unwanted live process or interaction running.
* Labels, selected-state text, SVG alternatives, live announcements and visible focus are
  present where relevant. Check contrast on actual backgrounds, including code and hints.
* Read the browser console and runtime requests. Distinguish local/data resources from
  network dependencies. Do not claim offline behavior from a cached online run.

### Accessibility evidence

Use the `accessibility` skill's method-adequacy guidance when available. Record the tested
HTML revision, slide/step, viewport or zoom, method, expected result and observed result.

* Run axe or an equivalent static scanner on the gallery, slides and distinct dialog/demo
  states. Investigate contrast findings on the actual backgrounds and scaled text sizes.
* Drive Tab, Shift+Tab, Enter, Space and Escape. Verify skip destinations, first/last
  boundaries, index selection, dialog reopening, hidden-slide focus and component replacement.
  Press character shortcuts both on and outside the focused presentation surface.
* Inspect computed accessible names, roles, heading order, diagram equivalents and live
  regions. Check that inactive slides and decorative chrome are absent and that slide/step
  changes have one concise announcement. A manual screen-reader pass remains separate
  from an accessibility-tree assertion; report it as unperformed when unavailable.
* Inspect screenshots and geometry in both presentation and reading modes. Check clipping,
  overlap, text spacing, keyboard focus clearance and target size, not only document width.
  An exception for a genuinely two-dimensional diagram does not exempt its surrounding text.
* Test the Docusaurus gallery in light and dark themes, including mobile navigation,
  skip-to-content, descriptive open/download links and browser Back from a deck. Recheck
  the regenerated standalone file, not just source or an older staged site bundle.

Static scans can decide some structural defects; they do not decide keyboard behavior,
announcement correctness or adaptive rendering. Preserve those evidence gaps in the handoff.
Use the [WCAG resize-text](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html),
[reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html),
[text-spacing](https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html) and
[character-shortcut](https://www.w3.org/WAI/WCAG22/Understanding/character-key-shortcuts.html)
guidance when classifying findings.

The [ARIA dialog pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) and
[reduced-motion guidance](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html)
inform these checks. They do not make a scoped browser pass an accessibility certification.

Use four evidence tiers and report each independently:

1. Source evidence checks authored IDs, notes, citations, media declarations, and finite state transitions.
2. Folder-build evidence checks generated assets, local dependencies, and source-to-build parity.
3. Standalone/served evidence checks committed, staged, and served bytes plus browser behavior across declared states.
4. Representative real-AT evidence samples selected transitions and content classes after an integrity gate; it never substitutes for deterministic all-slide coverage or qualified human review.

For generated parity, bind the deck metadata, source entry, folder build, committed standalone bundle, staged site copy, served copy, runtime state inventory, and representative-AT selection. A digest mismatch is a conflict or incomplete evidence state, not an acceptable packaging difference. Keep presenter notes out of ordinary evidence even though recipients of the standalone file can read them.

## Single-File Check

When delivering one HTML file, copy only that file to an isolated temporary directory,
optionally rename it, disable network access in the browser context and open it. Exercise
the relevant interactions and inspect attempted requests. Compare representative rendered
states against the folder build; neither version may rely on hidden sibling assets.

Preserve the library notice and confirm notes are intentionally shareable. Delete only
the temporary test files/directory created for this check. Do not remove the user's source,
working tree or general evidence root.

## Final Handoff and Limits

Return the actual entry file and exact build/bundle command. Name required checks not performed
and the smallest action that would allow them to run. Distinguish:

* Source updated, build not yet produced
* Folder build verified
* Single-file build verified in isolation
* Scripted or recorded example versus actual execution

Do not label a deck ready for live presenting when required interactions are untested.
Physical projector readability, real assistive-technology use, external installation and
published-host behavior require their own evidence. Acknowledge those limits without
inventing extra work the user did not request.
