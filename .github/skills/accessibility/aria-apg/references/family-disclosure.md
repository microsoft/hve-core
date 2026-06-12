---
title: "ARIA APG family — Disclosure"
description: "The Disclosure family covers widgets whose primary behaviour is showing or hiding a region of related content."
---

# ARIA APG family — Disclosure

The Disclosure family covers widgets whose primary behaviour is showing or hiding a region of related content. APG groups the simple show/hide disclosure together with composite patterns built on the same expand-and-collapse mechanic: accordions (a vertical stack of disclosures), carousels (a rotating disclosure of one panel at a time), and disclosure navigation menus (a navigation menu whose submenus appear via the disclosure pattern rather than the menu pattern). The hybrid disclosure-navigation variant combines a link as the top-level item with a separate disclosure button for the submenu.

Source: W3C WAI-ARIA Authoring Practices Guide, Disclosure and related patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/>.

## pattern-accordion

**Accordion** is a vertical stack of disclosure controls. Each header is a button that expands or collapses an associated region; accordions may permit only one panel open at a time (single-expand) or any combination of panels open at the same time (multi-expand).

**Required keyboard**

* Tab moves focus to the next header in the accordion, then out of the accordion.
* Enter or Space on a header toggles the expanded state of its panel.
* Down arrow (optional) moves focus to the next accordion header (wrapping to the first); Up arrow (optional) moves focus to the previous header (wrapping to the last).
* Home (optional) moves focus to the first header; End (optional) moves focus to the last header.

**Required ARIA**

* Each header uses a `button` (or `role="button"`) with `aria-expanded="true"` or `aria-expanded="false"` and `aria-controls` pointing at the `id` of its panel.
* Each panel uses `role="region"` (or a semantically equivalent landmark) with `aria-labelledby` pointing at its header's `id`.
* The hidden panel is fully removed from the accessibility tree (via `hidden` or `display: none`) when collapsed.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/accordion/>

## pattern-disclosure-show-hide

**Disclosure (Show/Hide)** is the minimal pattern: a single button that toggles the visibility of one region of content. The pattern is the building block for more complex disclosures (accordions, navigation menus, expandable filters).

**Required keyboard**

* Tab moves focus to and away from the disclosure button.
* Enter or Space toggles the expanded state of the controlled region.

**Required ARIA**

* The trigger uses a `button` (or `role="button"`) with `aria-expanded="true"` or `aria-expanded="false"`.
* `aria-controls` on the button (optional but recommended) points at the `id` of the controlled region.
* The region is fully removed from the accessibility tree when collapsed.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/>

## pattern-carousel-auto-rotating

**Carousel (Auto-Rotating)** is a carousel that advances through its slides automatically on a timer. APG requires an obvious way for users to pause and resume rotation so that the auto-advance does not interfere with reading or interacting with slide content. The pattern emphasises pause-on-hover and pause-on-focus behaviour in addition to the explicit pause button.

**Required keyboard**

* Tab moves focus to the carousel controls (pause button, previous, next, and slide picker).
* Space or Enter on the pause button toggles auto-rotation; while paused, the carousel does not advance.
* Left and Right arrows on the previous and next buttons advance to the previous or next slide.
* Focus entering any descendant of the carousel pauses auto-rotation; focus leaving the carousel resumes it (when previously rotating).

**Required ARIA**

* The container uses `role="region"` (or `role="group"`) with `aria-roledescription="carousel"` and an `aria-label` or `aria-labelledby` naming the carousel.
* Each slide container uses `aria-roledescription="slide"` and an `aria-label` or `aria-labelledby` identifying the slide.
* The live region wrapping the slide track uses `aria-live="off"` while auto-rotating and `aria-live="polite"` while paused, so that announcement does not collide with the auto-advance.
* The pause button uses `aria-label` describing the current action ("Stop slide rotation" or "Start slide rotation").
* `aria-controls` on the previous, next, and slide-picker controls points at the slide track.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/carousel/examples/carousel-1-prev-next/>

## pattern-carousel-tabbed

**Carousel (Tabbed)** is a carousel whose slide picker takes the form of a tablist: each tab represents one slide, and activating a tab displays its slide as the carousel's current panel. The pattern reuses the Tabs keyboard contract for slide navigation; the previous and next buttons are optional.

**Required keyboard**

* Tab moves focus into the tablist (and from there into the rotation controls, when present).
* Left and Right arrows move focus between tabs in the tablist; activation may be manual or automatic per `pattern-tabs-manual-activation` and `pattern-tabs-automatic-activation`.
* Enter or Space activates the focused tab and displays the matching slide (when activation is manual).
* Home and End move focus to the first or last tab.

**Required ARIA**

* The container uses `role="region"` (or `role="group"`) with `aria-roledescription="carousel"` and an accessible name.
* The slide picker uses `role="tablist"`, with each picker control using `role="tab"` and `aria-controls` pointing at its slide.
* Each slide uses `role="tabpanel"` with `aria-labelledby` pointing at its owning tab.
* The active tab uses `aria-selected="true"`; other tabs use `aria-selected="false"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/carousel/examples/carousel-2-tablist/>

## pattern-disclosure-navigation

**Disclosure Navigation** is a navigation menu whose submenus open via the disclosure pattern rather than the menu pattern. Top-level items are buttons that expand vertical lists of links; the keyboard contract differs from `pattern-menubar-navigation` because submenus do not use roving tabindex and arrow keys do not move focus between top-level items.

**Required keyboard**

* Tab moves focus through each top-level disclosure button and (when open) through the links in the open submenu.
* Enter or Space on a top-level button toggles the expansion of its submenu.
* Escape (optional) closes the open submenu and returns focus to its trigger button.
* Tab away from the last visible link closes any open submenu.

**Required ARIA**

* The outer container uses a `nav` element (or `role="navigation"`) with an accessible name.
* Each top-level item uses a `button` (or `role="button"`) with `aria-expanded` and `aria-controls` pointing at its submenu container.
* Submenu items are native `<a>` links inside a `<ul>` or equivalent list container.
* Closed submenus are hidden via `hidden` or `display: none` so that they are removed from the accessibility tree.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/>

## pattern-disclosure-navigation-hybrid

**Disclosure Navigation Hybrid** is the disclosure-navigation pattern in which the top-level item is itself a link to a destination, and a separate disclosure button sits next to it to expand the submenu. The hybrid pattern suits sites where the top-level navigation item must be directly clickable as a landing page, but the user must also be able to expand the submenu without leaving the current page.

**Required keyboard**

* Tab moves focus to the top-level link, then to its adjacent disclosure button, then to the submenu links when the submenu is open, then on to the next top-level link.
* Enter or Space on the top-level link follows the link (standard `<a>` behaviour).
* Enter or Space on the disclosure button toggles the submenu.
* Arrow keys (optional) on the disclosure button or in the submenu may move focus between submenu items.
* Escape (optional) closes the open submenu and returns focus to the disclosure button.

**Required ARIA**

* The outer container uses `nav` (or `role="navigation"`) with an accessible name.
* The top-level link is a native `<a>` element.
* The adjacent disclosure button uses `aria-expanded` and `aria-controls` pointing at its submenu container, plus an `aria-label` (such as "Show submenu for Products") because the visible label is typically an icon.
* `aria-haspopup="true"` (optional) on the disclosure button signals that activation reveals a popup region.
* Submenu items are native `<a>` links inside a list container.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation-hybrid/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
