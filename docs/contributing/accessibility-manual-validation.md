---
title: HVE Core docs accessibility manual validation
description: Per-behavior manual validation steps for the HVE Core documentation site accessibility fixes, paired with the shared real screen reader testing procedure.
author: Microsoft
ms.date: 2026-08-09
ms.topic: how-to
sidebar_position: 2
keywords:
  - accessibility
  - manual validation
  - screen reader
  - WCAG 2.2
  - runbook
---

## Purpose

Use this runbook to manually validate the accessibility behavior of the HVE Core documentation site against WCAG 2.2 AA. It pairs with the shared [real screen reader testing runbook](../planning/runbooks/accessibility/real-screen-reader-testing): that runbook is the reusable procedure and evidence format (the how), while this runbook lists the specific surfaces, states, and expected behavior to confirm (the what).

Each item below is grouped into a validation workstream, names the WCAG success criteria it exercises, and gives the exact keyboard, screen reader, and zoom steps a tester runs. Record every result with the shared runbook's result vocabulary and evidence fields.

> [!IMPORTANT]
> **Human review required.** This runbook supports evidence collection, not conformance certification. A qualified accessibility engineer confirms each result before any closure or attestation.
>
> * [ ] Reviewed and validated by a qualified human reviewer

## Scope and environment

* Target surface: the HVE Core documentation site (landing page, documentation pages, search, navbar, sidebar, footer, and data tables).
* Assistive technology: NVDA on Windows with a supported browser. JAWS remains a human-led path per the shared runbook. VoiceOver is out of current scope.
* Recommended browser: Microsoft Edge for keyboard, zoom, and reflow checks.
* Local validation: build and serve the site locally, then browse the served URL. Text zoom and reflow checks use browser zoom and responsive viewport tooling.
* Record the NVDA version, browser and version, OS version, viewport or zoom level, and the exact target URL in every evidence note.

## Behavior traceability

Use the register below to connect each validated behavior to its WCAG success criterion, the workstream or workstreams that exercise it, the automation coverage status, and the manual result recorded for each workstream. Behaviors are named by what they verify so this guide stays readable without access to an issue tracker.

| Behavior                           | WCAG SC       | Workstream(s) | Automated lock status                                                                                                                     | Per-workstream manual result       |
|------------------------------------|---------------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------|
| Search keyboard reachability       | 2.1.1         | W1            | Automated: keyboard reachability lock                                                                                                     | Record per run                     |
| Search popup is not a focus trap   | 2.1.2         | W1            | Automated: Tab and Shift+Tab leave the widget without navigating                                                                          | Record per run                     |
| Focus order                        | 2.4.3         | W4            | Automated: focus-order lock                                                                                                               | Record per run                     |
| Sidebar category disclosure        | 4.1.2         | W4            | Automated: one native button per category header, no header link, `aria-expanded` tracks state, Enter and Space toggle without navigating | Record per run                     |
| Sidebar category landing reachable | 2.4.3         | W4            | Automated: every linked category exposes its own landing route as its first child link                                                    | Record per run                     |
| Search placeholder at zoom         | 1.4.4         | W3            | Automated: zoom matrix at 100-250 percent; Edge remains manual-authoritative                                                              | Record per run                     |
| Narrow-viewport brand overlap      | 1.4.10        | W3            | Automated: reflow lock plus narrow-viewport brand overlap lock                                                                            | Record per run                     |
| Narrow-viewport brand name         | 4.1.2         | W3            | Automated: brand link resolves by accessible name at 320 and 420 CSS px where the wordmark is visually clipped                            | Record per run                     |
| Table and structure semantics      | 1.3.1         | W5, W7        | Automated: table and structure lock                                                                                                       | Record per run for each workstream |
| Search clear button name           | 4.1.2         | W1, W5        | Automated: clear-button accessible name lock; spoken output remains manual                                                                | Record per run for each workstream |
| Search result count announced      | 4.1.3         | W2            | Automated: status region presence and text; spoken announcement is a manual boundary                                                      | Record per run                     |
| Heading outline                    | 1.3.1         | W6            | Automated: heading-outline lock                                                                                                           | Record per run                     |
| Header-cell association            | 1.3.1         | W5            | Automated: structure boundary; spoken association remains manual                                                                          | Record per run                     |
| Group label association            | 1.3.1         | W5            | Automated: structure boundary; spoken group label remains manual                                                                          | Record per run                     |
| Non-color link cue                 | 1.4.1         | W6            | Automated: every prose link carries a non-color cue                                                                                       | Record per run                     |
| Focus indicator thickness          | 2.4.7         | W6            | Automated: focus indicator at least 2 CSS px on every focusable                                                                           | Record per run                     |
| Category toggle focus indicator    | 2.4.7, 1.4.11 | W4, W6        | Automated: category toggle keeps a focus outline in normal and forced-colors modes; perceived contrast across themes remains manual       | Record per run                     |

> [!NOTE]
> An automated lock proves the deterministic part of a behavior, such as an accessible name being present or a control being reachable. It does not prove what a screen reader speaks. Every entry above still needs one human pass before closure.
>
> Two boundaries are worth stating explicitly, because an automated result can look broader than it is:
>
> * The automated zoom coverage runs in Chromium and decides reflow behavior under SC 1.4.10. It does not decide SC 1.4.4 Resize Text. Real Microsoft Edge at 150, 200, and 250 percent remains the authority for that criterion.
> * The automated focus and forced-colors checks decide whether an indicator is present and how thick it is. Whether it is perceivable against a given theme or high-contrast palette remains a human judgment.

## Closure verification pass

Use this section when confirming that a specific behavior can be closed. Each item names the surface, the exact steps, the pass condition, and what automation already covers so the manual pass targets the remaining uncertainty.

Run the site locally and browse the served URL. Record every result using the evidence template below.

### Search clear button has an accessible name

* Automation covers: the control resolves and exposes a non-empty accessible name.
* Manual gap: the spoken name and whether it is operable by keyboard alone.
* Steps:
  1. Open the landing page and focus the navbar search field.
  2. Type any query so the clear control appears.
  3. Press `Tab` and confirm focus reaches the clear control.
  4. With NVDA running, confirm it announces a meaningful name and a button role rather than an unlabeled control or punctuation.
  5. Press `Enter` or `Space` and confirm the query clears and focus remains predictable.
* Pass condition: the control is keyboard reachable, announces a meaningful name and role, and clears the query.

### Narrow viewport does not overlap the site brand

* Automation covers: no overlap and no horizontal scroll at 320 pixels.
* Manual gap: whether the brand still has an accessible name after being visually hidden.
* Steps:
  1. Set the viewport to 320 pixels wide and open the search field.
  2. Confirm the brand and the search field do not overlap and the page does not scroll horizontally.
  3. With NVDA, navigate to the site brand link and confirm it still announces the site name.
  4. Repeat at 420 pixels, which is the boundary where the rule changes.
* Pass condition: no overlap, no horizontal scroll, and the brand keeps a spoken name at both widths.

### Search placeholder survives text zoom

* Automation covers: a zoom matrix from 100 through 250 percent using scaled viewports with matching device scale factors, in Chromium.
* Manual gap: real browser zoom in Edge, which remains authoritative for this criterion.
* Steps:
  1. In Edge at a standard desktop width, set browser zoom to 150 percent.
  2. Confirm the search placeholder is not clipped and no control overlaps another.
  3. Repeat at 200 percent and 250 percent.
  4. Confirm the keyboard shortcut badge is hidden rather than overlapping the placeholder at narrower widths.
* Pass condition: the placeholder stays legible and controls stay separated at every zoom level.

### Search result count is announced

* Automation covers: the status region exists in the main content and its text matches the visible result count, including the no-match case.
* Manual gap: whether a screen reader actually speaks the update. Automated capture of spoken live-region output is not supported by the current harness, so this step is the only evidence.
* Steps:
  1. Start NVDA, then open the search results page for a query that returns matches.
  2. Edit the query and confirm NVDA speaks the updated count without moving focus.
  3. Change to a query with no matches and confirm NVDA speaks the no-results message.
* Pass condition: both the count and the no-results message are spoken.

### Search results are reachable by keyboard

* Automation covers: option traversal, the footer option being reachable, and DOM focus remaining on the input while arrow keys move the highlight through `aria-activedescendant`.
* Manual gap: spoken position information and whether the reading order matches the visual order.
* Steps:
  1. Open search and type a query returning several results.
  2. Press `ArrowDown` repeatedly and confirm the highlight advances one option at a time and reaches the final footer option.
  3. With NVDA, confirm each option and its position are announced and match what is visible.
  4. Confirm `Enter` activates the highlighted option and `Esc` closes the popup.
* Pass condition: every option is reachable and announced correctly, and arrow keys move the highlight without moving DOM focus off the input.

### Search popup does not trap the keyboard

* Automation covers: `Tab` from the open popup moves focus to a control outside the search widget, and the page does not navigate.
* Manual gap: whether a screen reader follows the move and announces the destination, and whether the destination is a sensible next stop rather than a technically-focusable oddity.
* Steps:
  1. Open search and type a query so the popup is open.
  2. Press `Tab` and confirm focus lands on a control outside the search widget, that the focus indicator is visible on it, and that the URL is unchanged.
  3. Confirm focus is not left on the search input and has not been dropped to the page body. A focus indicator that disappears entirely is the trap symptom.
  4. Reopen the popup and press `Shift+Tab`; confirm focus moves backward out of the widget under the same conditions.
  5. With NVDA running, repeat both directions and confirm it announces the destination control rather than falling silent.
* Pass condition: both `Tab` and `Shift+Tab` always leave the widget for a real control, focus is never stranded on the input or lost to the body, and the page never navigates.
* Why this matters: a keyboard-only or screen-reader user who cannot leave the search field has no pointer fallback. This is a hard WCAG 2.1.2 failure, not a degraded experience.

### Link cues and focus indicators

* Automation covers: every prose link carries a non-color cue, and every visible focusable draws an indicator of at least 2 CSS pixels.
* Manual gap: whether the indicator is visible on all four sides against real backgrounds, including cards and images.
* Steps:
  1. View a documentation page in grayscale and confirm links remain distinguishable from body text.
  2. Tab through the page and confirm a visible focus ring on every control, including cards and the skip link.
  3. Confirm the ring is not clipped by an adjacent element or the viewport edge.
  4. Repeat in forced-colors mode.
* Pass condition: color is never the only cue, and focus is visible on all sides in both modes.

### Table and group semantics

* Automation covers: header scope, accessible names, structural associations, and that scrollable table wrappers are groups rather than landmarks.
* Manual gap: what is spoken when navigating cells and footer groups.
* Steps:
  1. With NVDA, navigate to a documentation table and confirm the scrollable wrapper announces its name as a grouping. Tables are deliberately not landmarks, so do not expect them in the landmark list; a page with several tables would otherwise fill that list with identical entries.
  2. Move between cells and confirm the correct row and column headers are spoken with each cell.
  3. Navigate the footer and confirm each column announces its group title before its list.
* Pass condition: table names, header associations, and footer group labels are all spoken correctly, and no table appears as a landmark.

### Focus order and heading outline

* Automation covers: focus order after activation and a gap-free heading outline.
* Manual gap: whether the order is comprehensible, not merely correct.
* Steps:
  1. Activate a top navigation link and confirm focus lands on page content rather than returning to the skip link.
  2. Open the topics menu and confirm arrow, home, and end move within it and `Esc` returns to the toggle.
  3. With NVDA, review the heading outline and confirm it has no gaps and includes in-page and footer headings.
* Pass condition: focus lands where a user would expect, the menu follows the expected model, and the outline is complete.

## Evidence results template

Copy the template below for each workstream item. Capture the environment metadata, the observed output, and the result classification without writing back to any automation matrix.

```text
Workstream: W1-W7
Bug or behavior:
NVDA version:
Browser and version:
OS version:
Viewport or zoom:
Target URL:
Observed output:
Result: verified pass | verified fail | not verified | unsupported
Notes:
```

Use the four-value vocabulary exactly as shown above. Do not write manual results back to any automation matrix.

## Result vocabulary

Use the shared runbook's manual result vocabulary and keep results as evidence-only entries:

* verified pass
* verified fail
* not verified
* unsupported

Do not write manual results back to any automated matrix. A downstream human review decides whether a result influences coverage or release gating.

## Validation workstreams

### W1: Keyboard access to search results (WCAG 2.1.1, 4.1.2)

* Surface and state: landing page, search suggestions open.
* Expected behavior: keyboard focus stays on the search input while `aria-activedescendant` moves the highlight through options; the highlight reaches the "See all results" footer only after the last option; the announced position count matches the visible list; `Enter` navigates; `Esc` and `Shift+Tab` return sanely; `Tab` does not navigate the page away.
* Steps:
  1. Open search, type a query that returns several results.
  2. Press `ArrowDown` repeatedly and confirm the highlight moves one option at a time and reaches "See all results".
  3. Confirm `Enter` activates the highlighted item.
  4. Confirm `Shift+Tab` and `Esc` return focus predictably and that `Tab` does not change the page.
  5. Repeat with NVDA and confirm each option plus its "x of y" position is announced correctly.
* Pass criteria: the footer is reachable, focus never escapes the combobox, `Tab` does not navigate, and NVDA announces correct positions.

### W2: Search result count announcement on the search page (WCAG 4.1.3)

* Surface and state: the dedicated search results page with an active query.
* Expected behavior: a live status region in the main content announces the deterministic result count when the query changes, including the no-match case.
* Steps:
  1. With NVDA running, open the search results page for a query that returns matches.
  2. Edit the query and confirm NVDA announces the count (for example, "N documents found").
  3. Change to a query with no matches and confirm NVDA announces the no-results message.
* Pass criteria: a live region in main content announces both the match count and the no-match message.

### W3: Reflow at 320px and text resize to 200% (WCAG 1.4.10, 1.4.4)

* Surface and state: landing page, navbar search expanded.
* Expected behavior: at a 320 pixel width the expanded search re-lays out and does not overlap the site brand, with no horizontal scrolling; at 200 percent text zoom the search placeholder and controls are not clipped and images remain intact.
* Steps:
  1. Set a 320 pixel wide viewport, open search, and confirm no overlap with the brand and no horizontal scroll.
  2. In real Edge at a standard desktop width, apply 200 percent text zoom and confirm the placeholder is not truncated and controls do not overlap.
* Pass criteria: no overlap or horizontal scroll at 320 pixels; no truncation or overlap at 200 percent.

### W4: Focus order for navbar dropdown and docs sidebar (WCAG 2.4.3)

* Surface and state: navbar topics menu and documentation left sidebar.
* Expected behavior: activating a top navigation link moves focus to page content rather than back to the skip link; the topics control behaves as a menu button with focus entering the first item and arrow, home, and end cycling within it, and `Esc` returning to the toggle; each collapsible sidebar category header is a single native button that only expands or collapses, and category children are ordinary links in normal Tab order.
* Steps:
  1. Keyboard only, activate a top navigation link and confirm focus lands on page content.
  2. Open the topics menu, confirm focus enters the first item, arrow and home and end cycle, and `Esc` returns to the toggle.
  3. Tab through the sidebar and confirm each category header is one stop, that `Enter` and `Space` expand or collapse it without navigating, and that the first child of a category with a landing page links to that landing page.
* Pass criteria: post-activation focus lands on content, the menu follows the expected keyboard model, each category header is a single tab stop that only discloses, and no category header navigates.

> [!NOTE]
> The sidebar is a set of disclosure buttons, not a tree. It does not use a roving tabindex and does not respond to arrow, `Home`, or `End` keys. Site navigation does not require a composite tree widget, and the disclosure pattern needs only a native button plus `aria-expanded`. Do not record the absence of arrow-key navigation in the sidebar as a defect.

### W5: Screen reader announcements (WCAG 1.3.1, 4.1.2)

* Surface and state: search field clear button, footer column groups, and the search field heading and shortcut association.
* Expected behavior: the clear button announces an accessible name; each footer column announces its title before its list; the search field announces its associated heading and keyboard shortcut, and the association persists across open, close, and refocus.
* Steps:
  1. With NVDA, move to the clear button and confirm it announces a clear accessible name.
  2. Navigate the footer and confirm each column announces its title before "list with N items".
  3. Focus the search field, confirm the heading and shortcut are announced, then open, close, and refocus and confirm the association persists.
* Pass criteria: the clear button is named, footer groups announce their titles, and the search field association survives the open and close cycle.

### W6: Merged fixes to re-verify (WCAG 1.4.1, 2.4.7, 1.3.1)

* Surface and state: links, focusable controls including cards, and heading structure across pages.
* Expected behavior: links remain distinguishable without relying on color alone; the keyboard focus indicator is visible on all four sides for every focusable control including cards; the heading outline has no gaps and includes in-page and footer headings.
* Steps:
  1. In gray scale, confirm links are distinguishable from body text.
  2. Keyboard only, confirm a four-sided focus ring on every control including cards.
  3. With NVDA, review the heading outline and confirm it is gap free and includes in-page and footer headings.
* Pass criteria: color is not the sole link cue, focus is visible on all sides, and the heading outline is complete.

### W7: Accessible tables site-wide (WCAG 1.3.1)

* Surface and state: data tables across documentation pages.
* Expected behavior: every data table has header cells with scope, an accessible name, and correct header associations, and the build fails if any table lacks a header scope or a name.
* Steps:
  1. With NVDA, navigate to a documentation table and confirm it announces its name and header associations.
  2. Run the build and confirm the table accessibility gate passes.
* Pass criteria: tables announce their name and header associations, and the automated table gate passes.

## Regression coverage

Manual validation confirms behavior once; permanent regression coverage prevents recurrence. As each workstream passes, confirm a corresponding end-to-end specification exists under the site's end-to-end test suite and that it fails before the fix and passes after. Keyboard operability, live-region announcements, reflow and resize, focus order, and table structure each need explicit assertions because static rule engines do not cover them.

## Evidence and closure

* Capture the observed output, focus location, viewport or zoom level, and any unexpected behavior for each item.
* Record one of the four result classifications per item and store the evidence reference.
* A qualified human reviewer confirms the recorded results before any closure or public attestation.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
