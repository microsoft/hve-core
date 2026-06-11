---
title: "Guideline 3.1 — Readable"
description: "Guideline 3.1 (Readable) requires that text content be readable and understandable, including identifying the language of the page and unusual content, and providing reading-level support where nee..."
---

# Guideline 3.1 — Readable

Guideline 3.1 (Readable) requires that text content be readable and understandable, including identifying the language of the page and unusual content, and providing reading-level support where needed.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 3.1, <https://www.w3.org/TR/WCAG22/#readable>.

## sc-3-1-1

**SC 3.1.1 Language of Page (Level A)**

The default human language of each web page can be programmatically determined.

**Assessment heuristics**:

* Confirm the root `<html>` element carries a `lang` attribute with a valid BCP 47 language tag.
* Confirm single-page applications set the language attribute to reflect the current content language when locale changes.

Source: <https://www.w3.org/TR/WCAG22/#language-of-page>

## sc-3-1-2

**SC 3.1.2 Language of Parts (Level AA)**

The human language of each passage or phrase in the content can be programmatically determined, except for proper names, technical terms, words of indeterminate language, and words or phrases that have become part of the surrounding text's vernacular.

**Assessment heuristics**:

* Confirm passages in a different language carry a `lang` attribute on the enclosing element.
* Confirm inline language switches (quotations, terms) use a `<span lang="...">`.

Source: <https://www.w3.org/TR/WCAG22/#language-of-parts>

## sc-3-1-3

**SC 3.1.3 Unusual Words (Level AAA)**

A mechanism is available for identifying specific definitions of words or phrases used in an unusual or restricted way, including idioms and jargon.

**Assessment heuristics**:

* Confirm jargon and idioms link to a glossary entry or expose a tooltip-style definition.

Source: <https://www.w3.org/TR/WCAG22/#unusual-words>

## sc-3-1-4

**SC 3.1.4 Abbreviations (Level AAA)**

A mechanism for identifying the expanded form or meaning of abbreviations is available.

**Assessment heuristics**:

* Confirm abbreviations are expanded on first use or exposed via `<abbr title>` or a glossary.

Source: <https://www.w3.org/TR/WCAG22/#abbreviations>

## sc-3-1-5

**SC 3.1.5 Reading Level (Level AAA)**

When text requires a reading ability more advanced than the lower secondary education level, supplemental content or a simpler version is available.

**Assessment heuristics**:

* Confirm long-form content has a plain-language summary or a simpler variant.

Source: <https://www.w3.org/TR/WCAG22/#reading-level>

## sc-3-1-6

**SC 3.1.6 Pronunciation (Level AAA)**

A mechanism is available for identifying specific pronunciation of words where pronunciation is essential to understanding meaning.

**Assessment heuristics**:

* Confirm homographs or pronunciation-sensitive terms include pronunciation hints (audio, IPA, or ruby annotation).

Source: <https://www.w3.org/TR/WCAG22/#pronunciation>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
