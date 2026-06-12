---
title: "Guideline 2.4 — Navigable"
description: "Guideline 2.4 (Navigable) requires that users have ways to navigate, find content, and determine where they are within the experience, through bypass mechanisms, titles, focus order, link purpose, ..."
---

# Guideline 2.4 — Navigable

Guideline 2.4 (Navigable) requires that users have ways to navigate, find content, and determine where they are within the experience, through bypass mechanisms, titles, focus order, link purpose, headings, and visible focus indicators.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.4, <https://www.w3.org/TR/WCAG22/#navigable>.

## sc-2-4-1

**SC 2.4.1 Bypass Blocks (Level A)**

A mechanism is available to bypass blocks of content that are repeated on multiple pages.

**Assessment heuristics**:

* Confirm a skip-to-main-content link is the first focusable element on the page and becomes visible on focus.
* Confirm landmarks (`<main>`, `<nav>`, `<aside>`) are used so assistive technology users can jump between regions.

Source: <https://www.w3.org/TR/WCAG22/#bypass-blocks>

## sc-2-4-2

**SC 2.4.2 Page Titled (Level A)**

Pages have titles that describe their topic or purpose.

**Assessment heuristics**:

* Confirm `<title>` reflects the page topic and updates on client-side navigation in single-page applications.
* Confirm titles disambiguate similar pages (for example, "Cart - 3 items" rather than just "Cart").

Source: <https://www.w3.org/TR/WCAG22/#page-titled>

## sc-2-4-3

**SC 2.4.3 Focus Order (Level A)**

If content can be navigated sequentially and the order affects meaning or operation, focusable components receive focus in an order that preserves meaning and operability.

**Assessment heuristics**:

* Confirm Tab order follows the visual reading order and does not jump unexpectedly across the page.
* Confirm `tabindex` values greater than zero are avoided.
* Confirm modals move focus into the dialog when opened and back to the trigger when closed.

Source: <https://www.w3.org/TR/WCAG22/#focus-order>

## sc-2-4-4

**SC 2.4.4 Link Purpose (In Context) (Level A)**

The purpose of each link is determined from the link text alone or from the link text together with its programmatically determined link context.

**Assessment heuristics**:

* Confirm link text is meaningful on its own or with adjacent text (avoid "click here", "read more" alone).
* Confirm icon-only links carry an accessible name via `aria-label` or visually hidden text.

Source: <https://www.w3.org/TR/WCAG22/#link-purpose-in-context>

## sc-2-4-5

**SC 2.4.5 Multiple Ways (Level AA)**

More than one way is available to locate a page within a set of pages, except where the page is the result of, or a step in, a process.

**Assessment heuristics**:

* Confirm the site provides at least two of: site map, search, table of contents, navigation menu, or related-links list.

Source: <https://www.w3.org/TR/WCAG22/#multiple-ways>

## sc-2-4-6

**SC 2.4.6 Headings and Labels (Level AA)**

Headings and labels describe the topic or purpose of the section or control they identify.

**Assessment heuristics**:

* Confirm heading text concisely describes the section content.
* Confirm form labels describe the input rather than restating the placeholder.

Source: <https://www.w3.org/TR/WCAG22/#headings-and-labels>

## sc-2-4-7

**SC 2.4.7 Focus Visible (Level AA)**

Any keyboard-operable interface has a mode of operation where the keyboard focus indicator is visible.

**Assessment heuristics**:

* Confirm the default browser focus ring is preserved or replaced with a custom indicator of equal or greater visibility.
* Confirm focus indicators meet the SC 1.4.11 non-text contrast threshold against adjacent colours.

Source: <https://www.w3.org/TR/WCAG22/#focus-visible>

## sc-2-4-8

**SC 2.4.8 Location (Level AAA)**

Information about the user's location within a set of pages is available.

**Assessment heuristics**:

* Confirm breadcrumbs, current-page indicators in navigation, or site-map highlights are present.

Source: <https://www.w3.org/TR/WCAG22/#location>

## sc-2-4-9

**SC 2.4.9 Link Purpose (Link Only) (Level AAA)**

A mechanism is available to allow the purpose of each link to be identified from the link text alone, except where the purpose is ambiguous to users in general.

**Assessment heuristics**:

* Confirm link text is fully self-describing without surrounding context.

Source: <https://www.w3.org/TR/WCAG22/#link-purpose-link-only>

## sc-2-4-10

**SC 2.4.10 Section Headings (Level AAA)**

Section headings are used to organise content where applicable.

**Assessment heuristics**:

* Confirm long-form content uses headings at appropriate levels to segment topics.

Source: <https://www.w3.org/TR/WCAG22/#section-headings>

## sc-2-4-11

**SC 2.4.11 Focus Not Obscured (Minimum) (Level AA)**

When a user-interface component receives keyboard focus, the component is not entirely hidden by author-created content.

**Assessment heuristics**:

* Confirm sticky headers, footers, cookie banners, or chat widgets do not entirely cover the currently focused control.
* Confirm scrolling brings the focused control into a visible position when overlays are present.

Source: <https://www.w3.org/TR/WCAG22/#focus-not-obscured-minimum>

## sc-2-4-12

**SC 2.4.12 Focus Not Obscured (Enhanced) (Level AAA)**

When a user-interface component receives keyboard focus, no part of the component is hidden by author-created content.

**Assessment heuristics**:

* Confirm overlays leave the entire focused control visible, not just a portion.

Source: <https://www.w3.org/TR/WCAG22/#focus-not-obscured-enhanced>

## sc-2-4-13

**SC 2.4.13 Focus Appearance (Level AAA)**

The keyboard focus indicator meets defined minimum size, contrast, and area requirements (an outline at least 2 CSS pixels thick with 3:1 contrast against unfocused state, and no obscuring of the focused component).

**Assessment heuristics**:

* Confirm focus indicators are at least 2 CSS pixels thick on the perimeter or equivalent area.
* Confirm 3:1 contrast between focused and unfocused states.

Source: <https://www.w3.org/TR/WCAG22/#focus-appearance>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
