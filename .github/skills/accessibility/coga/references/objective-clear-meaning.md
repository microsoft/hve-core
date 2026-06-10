---
title: "Objective 3 - Use Clear and Understandable Content"
description: "Objective 3 covers patterns that make written content readable, scannable, and unambiguous."
---

# Objective 3 - Use Clear and Understandable Content

Objective 3 covers patterns that make written content readable, scannable, and unambiguous. The user need is "Clear Meaning": users with cognitive, learning, and language-related disabilities benefit from plain language, familiar vocabulary, simple sentence structure, clear formatting, generous whitespace, and alternative modalities for content that is hard to convey in text alone.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 3, <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-use-clear-and-understandable-language

**Control 3.1 Use Clear and Understandable Language**

Content must be written at a reading level appropriate to the audience. Technical jargon, marketing prose, and formal register exclude many readers. Plain language increases comprehension for all users and is essential for users with cognitive and language-related disabilities.

**Design patterns**:

* Write at a reading level appropriate to the audience.
* Avoid jargon unless the audience uses it; define technical terms inline.
* Use familiar, everyday vocabulary.
* Prefer concrete examples over abstract descriptions.

**Assessment heuristics**:

* Confirm the reading level matches the intended audience using a readability metric.
* Confirm jargon is either defined inline or linked to a glossary.
* Confirm examples accompany abstract concepts.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-use-familiar-words

**Control 3.2 Use Familiar Words**

Word choice affects comprehension as much as sentence structure. Using familiar synonyms in place of formal or technical terms expands the audience that can read the content without external aids.

**Design patterns**:

* Prefer common words over rare ones (for example, "use" instead of "utilise").
* Maintain a glossary for terms that must be technical.
* Use the same word for the same concept throughout a document.
* Test vocabulary with members of the target audience.

**Assessment heuristics**:

* Confirm uncommon words are linked to or defined alongside a glossary.
* Confirm a single term is used consistently for a single concept.
* Confirm the page does not require an external dictionary to understand its core content.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-use-simple-sentence-structure

**Control 3.3 Use Simple Sentence Structure**

Long sentences with embedded clauses force readers to hold multiple ideas in working memory. Short sentences in active voice, with one idea per sentence, dramatically improve comprehension.

**Design patterns**:

* Keep sentences short; aim for fewer than 20 words.
* Use active voice rather than passive.
* Express one idea per sentence.
* Avoid nested clauses, parenthetical asides, and complex conditionals.

**Assessment heuristics**:

* Confirm sentence length stays within plain-language guidance.
* Confirm passive voice is used only when the actor is unknown or irrelevant.
* Confirm sentences do not embed multiple conditions or qualifiers.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-use-headings-and-sections

**Control 3.4 Use Headings and Sections**

Headings let users scan a page and jump to the section they need. Without headings, users must read every paragraph to find what they want. Hierarchical headings convey structure to both sighted readers and assistive technology users.

**Design patterns**:

* Divide long content into named sections with headings.
* Use hierarchical heading levels (`<h1>` through `<h6>`) that reflect content structure.
* Keep heading text concise and descriptive.
* Provide a table of contents for long documents.

**Assessment heuristics**:

* Confirm pages have a single `<h1>` and a logical heading hierarchy.
* Confirm heading text accurately describes the section beneath it.
* Confirm long documents include a navigable table of contents.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-use-lists

**Control 3.5 Use Lists**

Enumerable content is easier to scan and remember when presented as a list rather than as prose. Numbered lists imply order; bulleted lists imply a collection.

**Design patterns**:

* Present sets of items, steps, or options as lists.
* Use numbered lists for ordered sequences and bulleted lists for unordered collections.
* Keep list items short and parallel in structure.
* Avoid burying enumerable content in prose paragraphs.

**Assessment heuristics**:

* Confirm enumerable content is marked up as `<ul>` or `<ol>` rather than as run-on prose.
* Confirm list items follow a consistent grammatical structure.
* Confirm ordered processes use numbered lists rather than bullets.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-keep-text-succinct

**Control 3.6 Keep Text Succinct**

Long paragraphs and verbose prose impose a cognitive cost. Trim content to essentials, use summaries for long pages, and let users drill into detail only if they want it.

**Design patterns**:

* Trim filler, redundancy, and marketing language.
* Place a summary at the top of long pages.
* Provide an expand-on-demand mechanism for optional detail.
* Prefer concise prose over exhaustive elaboration.

**Assessment heuristics**:

* Confirm long pages open with a brief summary of the key points.
* Confirm content uses progressive disclosure for optional detail.
* Confirm paragraphs are short, typically three to five sentences or fewer.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-use-clear-unambiguous-formatting-and-punctuation

**Control 3.7 Use Clear, Unambiguous Formatting and Punctuation**

Inconsistent or unusual formatting introduces ambiguity. All-caps text is harder to read, italics reduce legibility, and idiosyncratic punctuation can confuse screen readers. Standard, conservative formatting supports comprehension.

**Design patterns**:

* Use sentence case for body text and headings.
* Avoid setting body text in all caps or italics.
* Use standard punctuation; avoid stylised dashes and quotation marks where simpler equivalents work.
* Apply formatting consistently across the document.

**Assessment heuristics**:

* Confirm body text and headings use sentence case.
* Confirm all caps is reserved for short labels (such as acronyms).
* Confirm punctuation rendering is consistent and predictable.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-separate-each-instruction

**Control 3.8 Separate Each Instruction**

When multiple instructions are merged into a single sentence or paragraph, users struggle to identify or sequence the actions. Each instruction must stand on its own line or numbered step.

**Design patterns**:

* Present each instruction on its own line or numbered step.
* Use one verb per step.
* Avoid combining setup, action, and follow-up in a single sentence.
* Number steps when order matters.

**Assessment heuristics**:

* Confirm instructions are presented as discrete steps rather than embedded in prose.
* Confirm each step contains a single action.
* Confirm steps are numbered when sequence is important.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-use-white-spacing

**Control 3.9 Use White Spacing**

Whitespace is not wasted space. Generous margins, line height, and spacing between sections help users locate content, parse structure, and rest their eyes. Dense layouts overwhelm readers who already struggle with visual processing.

**Design patterns**:

* Apply generous line height (typically 1.5 or greater for body text).
* Leave generous spacing between sections and around interactive elements.
* Use margins to separate content blocks visually.
* Avoid full-width prose; constrain text columns to comfortable reading widths.

**Assessment heuristics**:

* Confirm body text has a line height of at least 1.5.
* Confirm text columns stay within a comfortable reading width (typically 60 to 80 characters).
* Confirm sections are visually separated by whitespace rather than only by borders.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-ensure-foreground-content-is-not-obscured-by-background

**Control 3.10 Ensure Foreground Content is not Obscured by Background**

Text placed over photographs, gradients, or busy patterns is hard to read even at high contrast ratios. Backgrounds must not compete with foreground content.

**Design patterns**:

* Place body text on plain or near-plain backgrounds.
* When text overlays images, apply an overlay or shadow to ensure consistent contrast.
* Avoid placing text over animated or rotating backgrounds.
* Test foreground readability at the worst-case point of the background.

**Assessment heuristics**:

* Confirm text contrast meets WCAG 2.2 SC 1.4.3 across the full surface of the background.
* Confirm overlays are applied where text sits on imagery.
* Confirm text does not overlap with animated backgrounds.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-explain-implied-content

**Control 3.11 Explain Implied Content**

Idioms, abbreviations, cultural references, and metaphors exclude readers who do not share the relevant background. Spelling out the meaning the first time a reference appears keeps the content accessible.

**Design patterns**:

* Expand abbreviations on first use.
* Replace idioms with plain language or explain them inline.
* Avoid culture-specific references unless the audience is known to share the culture.
* Provide definitions or links for specialised terminology.

**Assessment heuristics**:

* Confirm abbreviations have an explicit expansion on first use.
* Confirm idiomatic language is replaced or annotated.
* Confirm cultural references are explained when used.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-provide-alternatives-for-numerical-concepts

**Control 3.12 Provide Alternatives for Numerical Concepts**

Numbers, percentages, and statistics are abstract. Many users struggle to interpret them without context. Visualisations, plain-language equivalents, and concrete comparisons make numeric information meaningful.

**Design patterns**:

* Pair numbers with plain-language equivalents (for example, "1 in 4" alongside "25 percent").
* Provide visualisations (charts, infographics) alongside numeric tables.
* Use comparisons to convey scale ("about the size of a soccer field").
* Avoid relying solely on percentages or large numbers without context.

**Assessment heuristics**:

* Confirm key statistics have a plain-language or visual equivalent.
* Confirm percentages are accompanied by absolute counts when feasible.
* Confirm comparisons are provided to convey scale.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

## control-support-different-modalities

**Control 3.13 Support Different Modalities**

Some users read text well; some understand pictures better; some prefer audio or video. Content delivered through multiple modalities reaches more users without requiring them to adapt.

**Design patterns**:

* Provide images, diagrams, or video alongside written instructions.
* Provide audio narration alongside text where feasible.
* Ensure each modality is independently comprehensible.
* Avoid requiring users to consume content in a specific modality.

**Assessment heuristics**:

* Confirm critical content is reachable via at least two modalities (text plus image, text plus audio, or video plus transcript).
* Confirm each modality conveys the full message rather than partial information.
* Confirm modality alternatives are equally discoverable.

Source: <https://www.w3.org/TR/coga-usable/#objective-3>.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
