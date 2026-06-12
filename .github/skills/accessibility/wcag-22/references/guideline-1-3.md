---
title: "Guideline 1.3 — Adaptable"
description: "Guideline 1.3 (Adaptable) requires that content can be presented in different ways without losing information or structure, so assistive technology can convey relationships, sequence, and meaning t..."
---

# Guideline 1.3 — Adaptable

Guideline 1.3 (Adaptable) requires that content can be presented in different ways without losing information or structure, so assistive technology can convey relationships, sequence, and meaning that sighted users perceive visually.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 1.3, <https://www.w3.org/TR/WCAG22/#adaptable>.

## sc-1-3-1

**SC 1.3.1 Info and Relationships (Level A)**

Information, structure, and relationships conveyed through presentation can be programmatically determined or are available in text.

**Assessment heuristics**:

* Confirm headings use semantic heading elements with a sensible nesting order rather than styled paragraphs.
* Confirm data tables use `<th>` with appropriate `scope` or `headers`/`id` association rather than visual layout alone.
* Confirm lists, fieldsets, and landmarks use their native semantic markup.
* Confirm form controls have programmatically associated labels (label-for, `aria-labelledby`, or wrapping label).
* Confirm visual groupings (boxes, columns, bold headings) carry equivalent programmatic structure.

Source: <https://www.w3.org/TR/WCAG22/#info-and-relationships>

## sc-1-3-2

**SC 1.3.2 Meaningful Sequence (Level A)**

When the sequence of content affects its meaning, the reading order is programmatically determinable.

**Assessment heuristics**:

* Confirm DOM order matches the visual reading order on left-to-right and right-to-left locales.
* Confirm CSS positioning (`float`, `flex-direction: row-reverse`, `order`) does not desynchronise visual order from DOM order in a way that changes meaning.
* Confirm tabular and multi-column layouts read in a logical sequence when CSS is disabled.

Source: <https://www.w3.org/TR/WCAG22/#meaningful-sequence>

## sc-1-3-3

**SC 1.3.3 Sensory Characteristics (Level A)**

Instructions do not rely solely on sensory characteristics such as shape, colour, size, visual location, orientation, or sound.

**Assessment heuristics**:

* Confirm instructions like "click the red button" are accompanied by a text label ("click Submit").
* Confirm instructions that reference shape ("the round icon") add a non-sensory identifier.
* Confirm spatial instructions ("the menu on the right") include an alternative identifier.

Source: <https://www.w3.org/TR/WCAG22/#sensory-characteristics>

## sc-1-3-4

**SC 1.3.4 Orientation (Level AA)**

Content does not restrict its view to a single display orientation (portrait or landscape) unless a specific orientation is essential.

**Assessment heuristics**:

* Confirm the app, page, or media does not lock to one orientation through CSS, `screen.orientation.lock()`, or platform manifest entries except where essential (for example, a piano keyboard).
* Confirm orientation changes do not lose user input or context.

Source: <https://www.w3.org/TR/WCAG22/#orientation>

## sc-1-3-5

**SC 1.3.5 Identify Input Purpose (Level AA)**

The purpose of each input field that collects information about the user can be programmatically determined when the field corresponds to one of the WCAG-defined input purposes.

**Assessment heuristics**:

* Confirm fields collecting personal data (name, email, phone, address, payment) use the `autocomplete` attribute with the appropriate token.
* Confirm `autocomplete` values match the WCAG input-purpose vocabulary.
* Confirm autofill works as the user expects with the browser's stored data.

Source: <https://www.w3.org/TR/WCAG22/#identify-input-purpose>

## sc-1-3-6

**SC 1.3.6 Identify Purpose (Level AAA)**

The purpose of user-interface components, icons, and regions can be programmatically determined (for example, through ARIA landmark roles, `aria-label`, or microdata).

**Assessment heuristics**:

* Confirm landmarks (`<main>`, `<nav>`, `<aside>`, `<header>`, `<footer>` or equivalent ARIA roles) cover the page.
* Confirm icons that act as controls expose a programmatic name and role.
* Confirm symbolic UI controls (icons) carry consistent and machine-readable purpose metadata.

Source: <https://www.w3.org/TR/WCAG22/#identify-purpose>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
