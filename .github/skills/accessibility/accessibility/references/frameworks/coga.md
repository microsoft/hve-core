---
title: COGA framework reference
description: Making Content Usable for People with Cognitive and Learning Disabilities (COGA) design patterns used as an accessibility assessment knowledge base
---

# COGA framework reference

This `SKILL.md` is the entrypoint for the **Making Content Usable for People with Cognitive and Learning Disabilities (COGA)** framework skill used by the Accessibility Planner and the Accessibility Skill Assessor subagent.

COGA is a Working Group Note published by the W3C Cognitive Accessibility Task Force. Unlike the normative WCAG 2.2 success criteria, COGA provides informative design guidance: 53 design patterns are organised into eight user-need objectives that together cover the accessibility needs of people with cognitive, learning, neurological, and age-related impairments. Each pattern describes a user need, suggested design approaches, and evaluation considerations. COGA patterns frequently complement WCAG 2.2 criteria, since several user needs (consistent navigation, clear labels, error prevention, focus support) are partially expressed across both standards.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, <https://www.w3.org/TR/coga-usable/>.

## Licensing posture

COGA is published under the W3C Document License as a Working Group Note. This skill paraphrases pattern intent rather than reproducing the source verbatim, in line with the paraphrase-preferred posture defined in [accessibility-license-posture.instructions.md](../../../../../instructions/accessibility/accessibility-license-posture.instructions.md). Every per-objective reference file cites the canonical W3C URL anchor for each pattern, and any future verbatim quotation must carry the W3C copyright attribution line specified in that instruction file.

## Pattern roll-up

The table below lists every COGA pattern grouped by objective. The `Reference` column links into the per-objective reference file using an anchor that matches the section header for that pattern. Total: 53 patterns across 8 objectives.

| #    | Pattern                                                                         | User need        | Design patterns                                                        | Assessment heuristics                                                            | Reference                                                                                                                                                                                                          |
|------|---------------------------------------------------------------------------------|------------------|------------------------------------------------------------------------|----------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1.1  | Make the Purpose of Your Page Clear                                             | Clear Purpose    | Descriptive titles, headers, signposts, top-of-page summary            | Confirm purpose is visible without scrolling; titles match the task              | [objective-clear-purpose.md#control-make-the-purpose-of-your-page-clear](#control-make-the-purpose-of-your-page-clear)                                                                                             |
| 1.2  | Use a Familiar Hierarchy and Design                                             | Clear Operation  | Conventional layout, predictable patterns, standard navigation         | Confirm controls live where users expect; avoid novel patterns                   | [objective-clear-purpose.md#control-use-a-familiar-hierarchy-and-design](#control-use-a-familiar-hierarchy-and-design)                                                                                             |
| 1.3  | Use a Consistent Visual Design                                                  | Clear Operation  | Consistent layout, colours, typography, control placement              | Confirm same controls render identically across pages                            | [objective-clear-purpose.md#control-use-a-consistent-visual-design](#control-use-a-consistent-visual-design)                                                                                                       |
| 1.4  | Make Each Step Clear                                                            | Clear Operation  | One concept per step, step indicators, progress feedback               | Confirm each step has a clear heading and progress is visible                    | [objective-clear-purpose.md#control-make-each-step-clear](#control-make-each-step-clear)                                                                                                                           |
| 1.5  | Clearly Identify Controls and Their Use                                         | Clear Operation  | Conventional control shapes, visible focus, descriptive labels         | Confirm interactive elements look interactive; labels describe outcome           | [objective-clear-purpose.md#control-clearly-identify-controls-and-their-use](#control-clearly-identify-controls-and-their-use)                                                                                     |
| 1.6  | Make the Relationship Clear Between Controls and the Content They Affect        | Clear Operation  | Proximity, grouping, visible references, `aria-controls`               | Confirm users can predict what a control will change                             | [objective-clear-purpose.md#control-make-the-relationship-clear-between-controls-and-the-content-they-affect](#control-make-the-relationship-clear-between-controls-and-the-content-they-affect)                   |
| 1.7  | Use Icons that Help the User                                                    | Use Symbols      | Familiar icons, paired text labels, consistent meaning                 | Confirm icons have text labels and follow industry conventions                   | [objective-clear-purpose.md#control-use-icons-that-help-the-user](#control-use-icons-that-help-the-user)                                                                                                           |
| 2.1  | Make it Easy to Find the Most Important Tasks and Features of the Site          | Findability      | Prominent placement, above-the-fold key actions, clear entry points    | Confirm primary tasks appear without scrolling on common viewports               | [objective-find-help.md#control-make-it-easy-to-find-the-most-important-tasks-and-features-of-the-site](#control-make-it-easy-to-find-the-most-important-tasks-and-features-of-the-site)                           |
| 2.2  | Make the Site Hierarchy Easy to Understand and Navigate                         | Findability      | Logical groupings, predictable menus, breadcrumbs                      | Confirm sitemap depth is shallow; navigation paths are stable                    | [objective-find-help.md#control-make-the-site-hierarchy-easy-to-understand-and-navigate](#control-make-the-site-hierarchy-easy-to-understand-and-navigate)                                                         |
| 2.3  | Use a Clear and Understandable Page Structure                                   | Findability      | Distinct page regions, headings, whitespace, dividers                  | Confirm regions are visually distinct and use landmark roles                     | [objective-find-help.md#control-use-a-clear-and-understandable-page-structure](#control-use-a-clear-and-understandable-page-structure)                                                                             |
| 2.4  | Make it Easy to Find the Most Important Actions and Information on the Page     | Findability      | Prominent CTAs, summary at top, key info above the fold                | Confirm primary actions are visually emphasised and reachable quickly            | [objective-find-help.md#control-make-it-easy-to-find-the-most-important-actions-and-information-on-the-page](#control-make-it-easy-to-find-the-most-important-actions-and-information-on-the-page)                 |
| 2.5  | Break Media into Chunks                                                         | Findability      | Segmented video, chapter markers, summaries                            | Confirm long media has chapter navigation or transcripts with anchors            | [objective-find-help.md#control-break-media-into-chunks](#control-break-media-into-chunks)                                                                                                                         |
| 2.6  | Provide Search                                                                  | Findability      | Site search, spell-check, suggestions, recent queries                  | Confirm search exists and tolerates typos and synonyms                           | [objective-find-help.md#control-provide-search](#control-provide-search)                                                                                                                                           |
| 3.1  | Use Clear and Understandable Language                                           | Clear Meaning    | Plain language, defined terms, simple vocabulary                       | Confirm reading level matches audience; jargon is defined inline                 | [objective-clear-meaning.md#control-use-clear-and-understandable-language](#control-use-clear-and-understandable-language)                                                                                         |
| 3.2  | Use Familiar Words                                                              | Clear Meaning    | Common words, audience-appropriate vocabulary                          | Confirm uncommon words have a glossary entry or definition                       | [objective-clear-meaning.md#control-use-familiar-words](#control-use-familiar-words)                                                                                                                               |
| 3.3  | Use Simple Sentence Structure                                                   | Clear Meaning    | Short sentences, active voice, one idea per sentence                   | Confirm sentences are short and avoid embedded clauses                           | [objective-clear-meaning.md#control-use-simple-sentence-structure](#control-use-simple-sentence-structure)                                                                                                         |
| 3.4  | Use Headings and Sections                                                       | Clear Meaning    | Hierarchical headings, scannable sections                              | Confirm headings are nested correctly and convey topic                           | [objective-clear-meaning.md#control-use-headings-and-sections](#control-use-headings-and-sections)                                                                                                                 |
| 3.5  | Use Lists                                                                       | Clear Meaning    | Bulleted or numbered lists, short list items                           | Confirm enumerable content is presented as a list rather than prose              | [objective-clear-meaning.md#control-use-lists](#control-use-lists)                                                                                                                                                 |
| 3.6  | Keep Text Succinct                                                              | Clear Meaning    | Short paragraphs, summaries, removal of filler                         | Confirm content is trimmed to essentials; long pages have summaries              | [objective-clear-meaning.md#control-keep-text-succinct](#control-keep-text-succinct)                                                                                                                               |
| 3.7  | Use Clear, Unambiguous Formatting and Punctuation                               | Clear Meaning    | Standard punctuation, avoid all-caps, avoid italics for emphasis       | Confirm formatting is consistent and avoids cognitive ambiguity                  | [objective-clear-meaning.md#control-use-clear-unambiguous-formatting-and-punctuation](#control-use-clear-unambiguous-formatting-and-punctuation)                                                                   |
| 3.8  | Separate Each Instruction                                                       | Clear Meaning    | One instruction per line, numbered steps, clear separation             | Confirm multi-step tasks are split into discrete numbered steps                  | [objective-clear-meaning.md#control-separate-each-instruction](#control-separate-each-instruction)                                                                                                                 |
| 3.9  | Use White Spacing                                                               | Clear Meaning    | Generous margins, line height, spacing between blocks                  | Confirm density is low enough that elements do not crowd each other              | [objective-clear-meaning.md#control-use-white-spacing](#control-use-white-spacing)                                                                                                                                 |
| 3.10 | Ensure Foreground Content is not Obscured by Background                         | Clear Meaning    | High contrast, no busy backgrounds behind text                         | Confirm text contrast meets WCAG and backgrounds do not interfere                | [objective-clear-meaning.md#control-ensure-foreground-content-is-not-obscured-by-background](#control-ensure-foreground-content-is-not-obscured-by-background)                                                     |
| 3.11 | Explain Implied Content                                                         | Clear Meaning    | Spell out idioms, expand abbreviations, define references              | Confirm content does not assume cultural or contextual knowledge                 | [objective-clear-meaning.md#control-explain-implied-content](#control-explain-implied-content)                                                                                                                     |
| 3.12 | Provide Alternatives for Numerical Concepts                                     | Clear Meaning    | Visualisations, comparisons, plain-language equivalents                | Confirm numbers and percentages have non-numeric alternatives                    | [objective-clear-meaning.md#control-provide-alternatives-for-numerical-concepts](#control-provide-alternatives-for-numerical-concepts)                                                                             |
| 3.13 | Support Different Modalities                                                    | Clear Meaning    | Text, image, audio, video alternatives                                 | Confirm critical content is reachable via at least two modalities                | [objective-clear-meaning.md#control-support-different-modalities](#control-support-different-modalities)                                                                                                           |
| 4.1  | Ensure Controls and Content Do Not Move Unexpectedly                            | Error Prevention | Stable layouts, no auto-shifts, predictable insertions                 | Confirm targets remain stable while users interact with the page                 | [objective-error-prevention-recovery.md#control-ensure-controls-and-content-do-not-move-unexpectedly](#control-ensure-controls-and-content-do-not-move-unexpectedly)                                               |
| 4.2  | Let Users Go Back                                                               | Error Prevention | Back button works, undo for actions, no trap pages                     | Confirm browser back and explicit back navigation always work                    | [objective-error-prevention-recovery.md#control-let-users-go-back](#control-let-users-go-back)                                                                                                                     |
| 4.3  | Notify Users of Fees and Charges at the Start of a Task                         | Error Prevention | Upfront pricing disclosure, hidden-fee avoidance                       | Confirm all costs are disclosed before any commitment is made                    | [objective-error-prevention-recovery.md#control-notify-users-of-fees-and-charges-at-the-start-of-a-task](#control-notify-users-of-fees-and-charges-at-the-start-of-a-task)                                         |
| 4.4  | Design Forms to Prevent Mistakes                                                | Error Prevention | Minimal fields, clear labels, format examples, inline validation       | Confirm forms reduce required input and validate as users type                   | [objective-error-prevention-recovery.md#control-design-forms-to-prevent-mistakes](#control-design-forms-to-prevent-mistakes)                                                                                       |
| 4.5  | Make it Easy to Undo Form Errors                                                | Error Prevention | Saved drafts, retained input on error, undo affordances                | Confirm partial form data persists after a validation failure                    | [objective-error-prevention-recovery.md#control-make-it-easy-to-undo-form-errors](#control-make-it-easy-to-undo-form-errors)                                                                                       |
| 4.6  | Use Clear Visible Labels                                                        | Error Prevention | Persistent visible labels, no placeholder-only labels                  | Confirm labels remain visible after the user types                               | [objective-error-prevention-recovery.md#control-use-clear-visible-labels](#control-use-clear-visible-labels)                                                                                                       |
| 4.7  | Use Clear Step-by-step Instructions                                             | Error Prevention | Numbered steps, one action per step, examples                          | Confirm multi-step flows have explicit step indicators and examples              | [objective-error-prevention-recovery.md#control-use-clear-step-by-step-instructions](#control-use-clear-step-by-step-instructions)                                                                                 |
| 4.8  | Accept Different Input Formats                                                  | Error Prevention | Flexible date, phone, address parsing                                  | Confirm common input formats are accepted without strict masks                   | [objective-error-prevention-recovery.md#control-accept-different-input-formats](#control-accept-different-input-formats)                                                                                           |
| 4.9  | Avoid Data Loss and Timeouts                                                    | Error Prevention | No arbitrary timeouts, autosave, timeout warnings                      | Confirm no required rapid response; timeouts are warned and extendable           | [objective-error-prevention-recovery.md#control-avoid-data-loss-and-timeouts](#control-avoid-data-loss-and-timeouts)                                                                                               |
| 4.10 | Provide Feedback                                                                | Error Prevention | Confirmation messages, status updates, undo prompts                    | Confirm every user action produces visible or audible feedback                   | [objective-error-prevention-recovery.md#control-provide-feedback](#control-provide-feedback)                                                                                                                       |
| 4.11 | Help the User Stay Safe                                                         | Error Prevention | Warnings before risky actions, confirmation prompts                    | Confirm destructive or costly actions require confirmation and are reversible    | [objective-error-prevention-recovery.md#control-help-the-user-stay-safe](#control-help-the-user-stay-safe)                                                                                                         |
| 4.12 | Use Familiar Metrics and Units                                                  | Error Prevention | Locale-appropriate units, conversions, plain labels                    | Confirm units match user locale or provide conversions                           | [objective-error-prevention-recovery.md#control-use-familiar-metrics-and-units](#control-use-familiar-metrics-and-units)                                                                                           |
| 5.1  | Help Users Focus                                                                | Focus            | Minimise distractions, prioritise one task at a time                   | Confirm pages do not present competing concurrent demands on attention           | [objective-supports-attention.md#control-help-users-focus](#control-help-users-focus)                                                                                                                              |
| 5.2  | Make Short Critical Paths                                                       | Focus            | Few steps to complete core tasks, streamlined flows                    | Confirm primary tasks complete in the smallest practical number of steps         | [objective-supports-attention.md#control-make-short-critical-paths](#control-make-short-critical-paths)                                                                                                            |
| 5.3  | Avoid Too Much Content                                                          | Focus            | Limit on-screen items, three to six functions, brief content           | Confirm visible content is bounded and avoids dense paragraphs                   | [objective-supports-attention.md#control-avoid-too-much-content](#control-avoid-too-much-content)                                                                                                                  |
| 6.1  | Ensure Processes Do Not Rely on Memory                                          | Memory           | Persistent information, repeated context across steps                  | Confirm users do not need to recall data from prior screens                      | [objective-minimise-memory-load.md#control-ensure-processes-do-not-rely-on-memory](#control-ensure-processes-do-not-rely-on-memory)                                                                                |
| 6.2  | Let Users Avoid Navigating Voice Menus                                          | Memory           | Text alternative to voice IVR, skip-prompts, quick keys                | Confirm voice or phone flows have text equivalents or shortcuts                  | [objective-minimise-memory-load.md#control-let-users-avoid-navigating-voice-menus](#control-let-users-avoid-navigating-voice-menus)                                                                                |
| 6.3  | Do Not Rely on User Calculations or Memorising Information                      | Memory           | Provide calculated values, avoid memorisation for security             | Confirm calculations are done for the user; auth does not require recall puzzles | [objective-minimise-memory-load.md#control-do-not-rely-on-user-calculations-or-memorising-information](#control-do-not-rely-on-user-calculations-or-memorising-information)                                        |
| 7.1  | Clearly State the Results and Disadvantages of Actions, Options, and Selections | Help             | Outcome descriptions, warnings about consequences                      | Confirm each choice explains what it does and what changes                       | [objective-feedback-confirmation.md#control-clearly-state-the-results-and-disadvantages-of-actions-options-and-selections](#control-clearly-state-the-results-and-disadvantages-of-actions-options-and-selections) |
| 7.2  | Provide Help for Forms and Non-standard Controls                                | Help             | Inline help, examples, password rules, control-specific docs           | Confirm complex inputs have inline accessible help                               | [objective-feedback-confirmation.md#control-provide-help-for-forms-and-non-standard-controls](#control-provide-help-for-forms-and-non-standard-controls)                                                           |
| 7.3  | Make It Easy to Find Help and Give Feedback                                     | Help             | Persistent help link, multiple support channels                        | Confirm help is reachable from every page and offers multiple channels           | [objective-feedback-confirmation.md#control-make-it-easy-to-find-help-and-give-feedback](#control-make-it-easy-to-find-help-and-give-feedback)                                                                     |
| 7.4  | Provide Help with Directions                                                    | Help             | Step-by-step guidance, wayfinding, tooltips                            | Confirm tasks include clear contextual directions and visual aids                | [objective-feedback-confirmation.md#control-provide-help-with-directions](#control-provide-help-with-directions)                                                                                                   |
| 7.5  | Provide Reminders                                                               | Help             | Reminders for recurring tasks, confirmation of important actions       | Confirm scheduled or repeated tasks support reminder hooks                       | [objective-feedback-confirmation.md#control-provide-reminders](#control-provide-reminders)                                                                                                                         |
| 8.1  | Let Users Control When the Content Moves or Changes                             | Adapt            | User-initiated motion, pause controls, no auto-launching pop-ups       | Confirm animation and auto-rotation have user-accessible controls                | [objective-user-control.md#control-let-users-control-when-the-content-moves-or-changes](#control-let-users-control-when-the-content-moves-or-changes)                                                              |
| 8.2  | Enable APIs and Extensions                                                      | Adapt            | Compatible with assistive add-ons, password managers, simplifiers      | Confirm pages do not block accessibility-enhancing browser extensions            | [objective-user-control.md#control-enable-apis-and-extensions](#control-enable-apis-and-extensions)                                                                                                                |
| 8.3  | Support Simplification                                                          | Adapt            | Simplified-view toggle, three to six core functions in simplified mode | Confirm a low-complexity alternative view is available where practical           | [objective-user-control.md#control-support-simplification](#control-support-simplification)                                                                                                                        |
| 8.4  | Support a Personalised and Familiar Interface                                   | Adapt            | Customisable layout, colours, terminology, system-preference respect   | Confirm user preferences are honoured and persisted across visits                | [objective-user-control.md#control-support-a-personalised-and-familiar-interface](#control-support-a-personalised-and-familiar-interface)                                                                          |

## Assessment heuristics

Per-pattern assessment heuristics, design pattern detail, and scope notes live inside the per-objective reference files in `references/`. The Accessibility Skill Assessor subagent consumes the appropriate `objective-<slug>.md#control-<pattern-slug>` section when evaluating a finding against a specific COGA pattern.

Cross-skill use is the common case: a COGA finding usually cites both the pattern reference here and the most closely related WCAG 2.2 success criterion in [`wcag-22`](wcag-22.md). For example, a page that auto-rotates a carousel without a pause control is cited against `objective-user-control.md#control-let-users-control-when-the-content-moves-or-changes` (for the COGA user-control pattern) and `../wcag-22/references/guideline-2-2.md#sc-2-2-2` (for the WCAG 2.2.2 Pause, Stop, Hide requirement).

## Skill layout

* `SKILL.md` — this file (skill entrypoint and 53-row roll-up table).
* `references/` — one markdown file per COGA objective. Each file contains a paraphrased description of every pattern within the objective, a `Design patterns` list of implementation approaches, an `Assessment heuristics` list for evaluation, and a canonical W3C source URL anchor.

## Objective 3 - Use Clear and Understandable Content

Objective 3 covers patterns that make written content readable, scannable, and unambiguous. The user need is "Clear Meaning": users with cognitive, learning, and language-related disabilities benefit from plain language, familiar vocabulary, simple sentence structure, clear formatting, generous whitespace, and alternative modalities for content that is hard to convey in text alone.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 3, <https://www.w3.org/TR/coga-usable/#objective-3>.

### control-use-clear-and-understandable-language

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

### control-use-familiar-words

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

### control-use-simple-sentence-structure

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

### control-use-headings-and-sections

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

### control-use-lists

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

### control-keep-text-succinct

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

### control-use-clear-unambiguous-formatting-and-punctuation

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

### control-separate-each-instruction

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

### control-use-white-spacing

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

### control-ensure-foreground-content-is-not-obscured-by-background

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

### control-explain-implied-content

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

### control-provide-alternatives-for-numerical-concepts

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

### control-support-different-modalities

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

## Objective 1 - Help Users Understand What Things Are and How to Use Them

Objective 1 covers patterns that make the purpose of a page, the role of each control, and the relationship between controls and their effects immediately clear. The user need is "Clear Purpose" and "Clear Operation": users with cognitive and learning disabilities benefit when sites use predictable, consistent layouts, conventional control shapes, and familiar iconography so that recognition replaces the need for problem-solving.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 1, <https://www.w3.org/TR/coga-usable/#objective-1>.

### control-make-the-purpose-of-your-page-clear

**Control 1.1 Make the Purpose of Your Page Clear**

The user must be able to tell within a few seconds what a page is for and what tasks it supports. Pages that bury their purpose in marketing copy or assume context from prior navigation exclude users who land on the page directly, who navigate with assistive technology, or who struggle with extended reading. A short, plain-language purpose statement near the top of the page makes the page self-describing.

**Design patterns**:

* Provide a descriptive page title that matches the user's task vocabulary.
* Place a short purpose statement or summary near the top of the page.
* Use prominent, descriptive headings that signpost the main sections.
* Avoid splash screens, marketing carousels, or pre-content overlays that delay the user.

**Assessment heuristics**:

* Confirm the page purpose is visible without scrolling on common viewports.
* Confirm the `<title>` element matches the visible top-of-page heading or summary.
* Confirm landmark structure (`<main>`, `<nav>`, `<header>`) is present so assistive technology users can skip directly to the primary content.

Source: <https://www.w3.org/TR/coga-usable/#objective-1>.

### control-use-a-familiar-hierarchy-and-design

**Control 1.2 Use a Familiar Hierarchy and Design**

Users with cognitive disabilities rely on prior experience to navigate. When a site uses a layout that diverges from established conventions, every interaction becomes a learning task. Conventional placement of navigation, search, account controls, and footer information lets users transfer skills learned elsewhere.

**Design patterns**:

* Place primary navigation at the top or left of the page.
* Place search in a conventional location such as the top right.
* Place account, login, and shopping cart controls where users expect to find them on similar sites.
* Avoid inventing new interaction patterns when an established pattern would serve.

**Assessment heuristics**:

* Compare the page layout against three to five comparable sites in the same domain and confirm key controls live in conventional positions.
* Confirm primary navigation appears in the same location on every page in the site.
* Confirm novel patterns are accompanied by inline guidance the first time they appear.

Source: <https://www.w3.org/TR/coga-usable/#objective-1>.

### control-use-a-consistent-visual-design

**Control 1.3 Use a Consistent Visual Design**

Visual consistency reduces cognitive load by letting users recognise rather than relearn each control. When the same action looks different across pages, users must re-evaluate every interaction. Consistent colour, typography, iconography, and control shapes turn the interface into a learnable system.

**Design patterns**:

* Define a small palette and apply it consistently across pages.
* Use the same shape, size, and styling for the same control across the site.
* Reserve specific colours for specific meanings (for example, red for destructive actions) and apply them consistently.
* Maintain a consistent typographic hierarchy.

**Assessment heuristics**:

* Confirm the same button type (primary, secondary, destructive) renders identically across pages.
* Confirm icons used in multiple places carry the same meaning everywhere.
* Confirm typography hierarchy is consistent across templates.

Source: <https://www.w3.org/TR/coga-usable/#objective-1>.

### control-make-each-step-clear

**Control 1.4 Make Each Step Clear**

Multi-step processes overwhelm users when several decisions are presented at once or when it is not obvious where the user currently sits in the flow. Each step must have a clear heading describing the current task, must avoid mixing unrelated decisions, and must indicate progress so the user can pace themselves.

**Design patterns**:

* Break long tasks into single-concept steps with clear headings.
* Include a progress indicator that shows current step and total steps.
* Place a brief summary of completed steps so users can review without going back.
* Avoid combining unrelated decisions in a single step.

**Assessment heuristics**:

* Confirm each step has a heading naming the current task.
* Confirm a progress indicator is visible on every step.
* Confirm users can review previous steps without losing their place.

Source: <https://www.w3.org/TR/coga-usable/#objective-1>.

### control-clearly-identify-controls-and-their-use

**Control 1.5 Clearly Identify Controls and Their Use**

Controls must look like controls. A flat, decorative design where buttons are indistinguishable from text or where links are hidden in body copy increases the time and effort required to find interactive elements. Visual affordances, descriptive labels, and clear focus indicators help users locate and operate controls.

**Design patterns**:

* Style buttons and links so they are visually distinct from non-interactive text.
* Use descriptive labels that say what the control does rather than generic verbs such as "click here".
* Provide a strong visible focus indicator.
* Avoid relying on hover-only affordances since touch users cannot hover.

**Assessment heuristics**:

* Confirm interactive elements have visual cues (colour, underline, button shape) distinguishing them from static content.
* Confirm control labels describe the outcome of activation.
* Confirm focus indicators are visible and meet the non-text contrast threshold.

Source: <https://www.w3.org/TR/coga-usable/#objective-1>.

### control-make-the-relationship-clear-between-controls-and-the-content-they-affect

**Control 1.6 Make the Relationship Clear Between Controls and the Content They Affect**

When activating a control changes something on the page, the user must be able to predict and locate the change. Hidden side effects, distant updates, or unclear bindings between filters and results disorient users and risk leaving important changes unnoticed.

**Design patterns**:

* Place controls adjacent to the content they affect.
* Use visible grouping (cards, borders, whitespace) to associate controls with their targets.
* Use `aria-controls` and live regions to convey relationships and updates programmatically.
* Provide a visible confirmation when a control changes distant content.

**Assessment heuristics**:

* Confirm the user can predict, from looking at the control, which area of the page it will change.
* Confirm filter controls update results immediately and visibly, with a textual or aria-live confirmation.
* Confirm controls that affect distant content (such as a filter that updates a list below the fold) provide an announcement or scroll cue.

Source: <https://www.w3.org/TR/coga-usable/#objective-1>.

### control-use-icons-that-help-the-user

**Control 1.7 Use Icons that Help the User**

Icons help recognition only when they are familiar and consistently meaningful. Novel or culturally specific icons exclude users who do not share the reference. Icons paired with text labels combine the speed of recognition with the precision of text.

**Design patterns**:

* Use widely understood, conventional icons (for example, magnifying glass for search, gear for settings).
* Pair every icon with a text label unless the icon is universally recognised.
* Apply consistent meaning to each icon across the site.
* Avoid using icons as the sole indicator of state or action.

**Assessment heuristics**:

* Confirm each icon either has a visible text label or, where space is constrained, an accessible name via `aria-label` or visually hidden text.
* Confirm icon meaning is consistent across the site.
* Confirm uncommon icons are accompanied by inline text the first time they appear.

Source: <https://www.w3.org/TR/coga-usable/#objective-1>.

## Objective 4 - Help Users Avoid Mistakes and Know How to Correct Them

Objective 4 covers patterns that prevent errors before they occur and that help users recover quickly when errors do occur. The user need is "Error Prevention": users with cognitive and learning disabilities are disproportionately affected by error-prone interfaces, unforgiving forms, time pressure, hidden costs, and unexpected layout shifts. Designs that anticipate mistakes and offer painless recovery support all users.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 4, <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-ensure-controls-and-content-do-not-move-unexpectedly

**Control 4.1 Ensure Controls and Content Do Not Move Unexpectedly**

Layout shifts caused by deferred content loading, rotating banners, or pop-ups disorient users and cause mis-clicks. Targets must remain stable while users interact with the page.

**Design patterns**:

* Reserve space for asynchronous content so the layout does not shift when it loads.
* Avoid auto-rotating content in primary interaction areas.
* Avoid inserting content above the current scroll position after the page has loaded.
* Provide user controls (pause, dismiss) for any non-essential motion.

**Assessment heuristics**:

* Confirm Cumulative Layout Shift remains low during page load and interaction.
* Confirm content inserted asynchronously appears in reserved space.
* Confirm rotating or moving content does not interfere with users while they are interacting nearby.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-let-users-go-back

**Control 4.2 Let Users Go Back**

Users must be able to back out of any step without losing data or being trapped. Browser back, in-app back buttons, and undo affordances must all work reliably.

**Design patterns**:

* Make the browser back button work without losing state.
* Provide in-app back buttons on multi-step flows.
* Provide undo for destructive actions.
* Avoid pages that trap the user with no way out.

**Assessment heuristics**:

* Confirm the browser back button works on every page and preserves user input.
* Confirm multi-step flows include an explicit back affordance.
* Confirm destructive actions are reversible or require confirmation.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-notify-users-of-fees-and-charges-at-the-start-of-a-task

**Control 4.3 Notify Users of Fees and Charges at the Start of a Task**

Hidden fees, late-stage upsells, and surprise charges at checkout exploit users who have already invested effort and feel committed. All costs must be disclosed at the start so users can make an informed decision.

**Design patterns**:

* Disclose all fees, taxes, and charges at the start of a task.
* Show running totals throughout the flow.
* Avoid revealing additional charges only at the final confirmation step.
* Be explicit about subscriptions, renewals, and cancellation terms.

**Assessment heuristics**:

* Confirm the total price is visible before the user begins committing actions.
* Confirm any fee added late in the flow is highlighted and explained.
* Confirm subscription terms (price, frequency, cancellation) are visible before sign-up.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-design-forms-to-prevent-mistakes

**Control 4.4 Design Forms to Prevent Mistakes**

Forms are a common source of frustration. Reducing the number of required fields, providing clear labels and format examples, and validating input inline prevents most mistakes before they happen.

**Design patterns**:

* Ask only for information that is strictly required.
* Provide clear, persistent labels for every field.
* Show format examples alongside fields that require specific formats.
* Validate input inline as the user types or moves between fields.

**Assessment heuristics**:

* Confirm forms ask only for necessary fields.
* Confirm format examples appear next to fields with specific format requirements.
* Confirm validation provides actionable, polite messages.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-make-it-easy-to-undo-form-errors

**Control 4.5 Make it Easy to Undo Form Errors**

When a form fails validation, the user's input must be preserved. Forcing the user to re-enter data after a validation failure compounds frustration and increases the chance of further errors.

**Design patterns**:

* Preserve all user input across validation failures.
* Highlight errors precisely without clearing valid fields.
* Provide clear instructions for fixing each error.
* Offer autosave for long forms.

**Assessment heuristics**:

* Confirm partial form data persists after a validation failure.
* Confirm error messages identify the field, the problem, and the fix.
* Confirm long forms autosave or offer a manual save option.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-use-clear-visible-labels

**Control 4.6 Use Clear Visible Labels**

Placeholder text is not a label. Once the user begins typing, placeholder labels disappear, leaving the user with no reminder of what the field expects. Persistent visible labels are essential.

**Design patterns**:

* Provide persistent visible labels above or beside each form field.
* Avoid using placeholder text as the only label.
* Use clear, plain-language labels that say what the field expects.
* Keep the label visible after the user enters data.

**Assessment heuristics**:

* Confirm every form field has a persistent visible label.
* Confirm labels remain visible after the user enters data.
* Confirm labels describe the expected input rather than restating the placeholder.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-use-clear-step-by-step-instructions

**Control 4.7 Use Clear Step-by-step Instructions**

Multi-step instructions must be presented as discrete numbered steps with concrete examples. Burying steps in paragraphs forces users to parse the prose to extract the sequence.

**Design patterns**:

* Present multi-step tasks as numbered steps.
* Provide a concrete example for each step where helpful.
* Show progress through the steps.
* Avoid combining multiple actions in a single step.

**Assessment heuristics**:

* Confirm multi-step processes use numbered steps rather than prose.
* Confirm each step contains a single action and an optional example.
* Confirm a progress indicator shows current step and total steps.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-accept-different-input-formats

**Control 4.8 Accept Different Input Formats**

Strict input masks reject valid data formatted differently from what the form expects. Phone numbers, dates, addresses, and credit card numbers should be accepted in any common format and normalised behind the scenes.

**Design patterns**:

* Accept multiple common formats for phone numbers, dates, currency, and addresses.
* Strip non-numeric characters from numeric fields before validating.
* Avoid input masks that reject valid characters.
* Normalise data server-side rather than rejecting it client-side.

**Assessment heuristics**:

* Confirm phone, date, and credit card fields accept common formatting variants.
* Confirm whitespace and punctuation are stripped rather than rejected.
* Confirm rejection messages identify the actual issue, not the format mismatch.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-avoid-data-loss-and-timeouts

**Control 4.9 Avoid Data Loss and Timeouts**

Timeouts that discard user input penalise users who take longer to read, type, or decide. Where security or technical constraints require a timeout, the user must be warned and given the chance to extend it.

**Design patterns**:

* Avoid arbitrary timeouts on forms or session.
* Autosave user input continuously.
* Warn the user before a timeout expires and offer an extension.
* Preserve user input even if a session expires.

**Assessment heuristics**:

* Confirm forms do not impose time limits unless strictly required.
* Confirm timeout warnings appear with sufficient time for the user to respond.
* Confirm user input is preserved across session timeouts where possible.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-provide-feedback

**Control 4.10 Provide Feedback**

Every user action must produce immediate visible or audible feedback. Silent interfaces leave users unsure whether their action succeeded, prompting repeated attempts and accidental duplicates.

**Design patterns**:

* Provide a visible response to every user action.
* Use live regions to announce status changes to assistive technology.
* Confirm completion of long-running actions.
* Distinguish success, warning, and error feedback by colour, icon, and text.

**Assessment heuristics**:

* Confirm every interactive control produces visible or audible feedback within 100 milliseconds of activation.
* Confirm status changes are announced via `aria-live` regions where appropriate.
* Confirm feedback messages are distinct by category (success, warning, error).

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-help-the-user-stay-safe

**Control 4.11 Help the User Stay Safe**

Destructive or costly actions must require confirmation. Where possible, actions should be reversible. Users with cognitive disabilities are especially vulnerable to interfaces that punish accidental clicks.

**Design patterns**:

* Require explicit confirmation for destructive or costly actions.
* Make actions reversible where possible (undo, restore, cancel).
* Use clear warning language before risky actions.
* Avoid making destructive actions the default option in dialogs.

**Assessment heuristics**:

* Confirm destructive actions (delete, send, purchase) require confirmation.
* Confirm reversible alternatives are offered where feasible.
* Confirm the destructive option is not the default button in confirmation dialogs.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

### control-use-familiar-metrics-and-units

**Control 4.12 Use Familiar Metrics and Units**

Units of measurement must match the user's locale. Showing imperial units to a metric audience (or vice versa) creates avoidable cognitive friction.

**Design patterns**:

* Detect or ask for user locale and display units accordingly.
* Provide unit conversions where multiple units are common.
* Label units clearly; avoid ambiguous abbreviations.
* Allow the user to switch units explicitly.

**Assessment heuristics**:

* Confirm units match the user's locale by default.
* Confirm conversions are provided when units may be unfamiliar.
* Confirm unit abbreviations are unambiguous (for example, distinguishing kilometres from kilobytes).

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## Objective 7 - Provide Help and Support

Objective 7 covers patterns that explain consequences, offer in-context help, gather feedback, and confirm important actions. The user need is "Feedback and Confirmation": users with cognitive and learning disabilities benefit when the interface explains outcomes before they commit, makes help easy to find, and reminds them of upcoming events or tasks.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 7, <https://www.w3.org/TR/coga-usable/#objective-7>.

### control-clearly-state-the-results-and-disadvantages-of-actions-options-and-selections

**Control 7.1 Clearly State the Results and Disadvantages of Actions, Options, and Selections**

Users must know what an action will do before they commit. Hidden consequences (recurring charges, account merges, irreversible deletions) damage trust and exclude users who cannot easily reverse mistakes.

**Design patterns**:

* State the outcome of each action in plain language before the user commits.
* Disclose recurring or future commitments (subscriptions, cancellation fees) clearly.
* Warn the user before irreversible actions.
* Show comparisons between options to help users choose.

**Assessment heuristics**:

* Confirm action labels describe the outcome (for example, "Send invoice" rather than "Submit").
* Confirm recurring commitments are disclosed before the user commits.
* Confirm irreversible actions are flagged and require confirmation.

Source: <https://www.w3.org/TR/coga-usable/#objective-7>.

### control-provide-help-for-forms-and-non-standard-controls

**Control 7.2 Provide Help for Forms and Non-standard Controls**

Help must be available where the user needs it, not buried in a separate help section. Inline help, examples, and tooltips placed next to form fields and non-standard controls answer questions at the point of confusion.

**Design patterns**:

* Provide inline help next to fields that may confuse users.
* Provide format examples for fields with specific format requirements.
* Provide tooltips and inline guidance for non-standard controls.
* Link to detailed help where inline guidance is insufficient.

**Assessment heuristics**:

* Confirm inline help appears next to fields that require explanation.
* Confirm format examples appear next to fields with specific format requirements.
* Confirm non-standard controls have inline guidance the first time they appear.

Source: <https://www.w3.org/TR/coga-usable/#objective-7>.

### control-make-it-easy-to-find-help-and-give-feedback

**Control 7.3 Make it Easy to Find Help and Give Feedback**

A user who cannot find help is a user who abandons the task. Help and feedback links must be present in conventional locations on every page, with multiple contact methods so users can choose the one that suits them.

**Design patterns**:

* Place help links in conventional locations (header or footer) on every page.
* Offer multiple contact methods (chat, phone, email, web form).
* Provide a clear feedback channel so users can report problems.
* Avoid burying help behind multi-level menus.

**Assessment heuristics**:

* Confirm help and contact links appear on every page in a consistent location.
* Confirm at least two contact methods are available.
* Confirm a feedback channel is available for users to report issues.

Source: <https://www.w3.org/TR/coga-usable/#objective-7>.

### control-provide-help-with-directions

**Control 7.4 Provide Help with Directions**

Wayfinding within a site or application must be straightforward. Breadcrumbs, clear page titles, and visible site maps help users keep track of where they are and find their way back.

**Design patterns**:

* Provide breadcrumbs showing the current location within the site.
* Use descriptive page titles that match the user's location.
* Provide a site map for complex sites.
* Show "you are here" indicators in navigation.

**Assessment heuristics**:

* Confirm breadcrumbs appear on every page below the home page.
* Confirm the active navigation item is visually distinct.
* Confirm a site map is provided for sites with more than a few sections.

Source: <https://www.w3.org/TR/coga-usable/#objective-7>.

### control-provide-reminders

**Control 7.5 Provide Reminders**

Users with memory or attention differences benefit from reminders about upcoming events, expiring sessions, scheduled appointments, or incomplete tasks. Reminders must be timely and dismissible.

**Design patterns**:

* Offer reminders for upcoming events, appointments, or expirations.
* Allow the user to choose the reminder channel (email, in-app, push).
* Allow the user to dismiss or snooze reminders.
* Avoid spamming users with unnecessary reminders.

**Assessment heuristics**:

* Confirm reminders are offered for time-sensitive events.
* Confirm reminders can be customised by channel and frequency.
* Confirm reminders can be dismissed or snoozed.

Source: <https://www.w3.org/TR/coga-usable/#objective-7>.

## Objective 2 - Help Users Find What They Need

Objective 2 covers patterns that make important tasks, features, actions, and information easy to locate. The user need is "Findability": users with cognitive and learning disabilities benefit from prominent placement of primary tasks, predictable site hierarchies, clear page structure, segmented media, and tolerant search facilities.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 2, <https://www.w3.org/TR/coga-usable/#objective-2>.

### control-make-it-easy-to-find-the-most-important-tasks-and-features-of-the-site

**Control 2.1 Make it Easy to Find the Most Important Tasks and Features of the Site**

The site's primary tasks must be discoverable without exploration. Users should not have to hunt through menus to find what the site is for. Prominent placement of the top three to five tasks lets users reach their goal quickly.

**Design patterns**:

* Identify the top three to five user tasks and surface them on the home page.
* Place primary calls to action above the fold on common viewports.
* Use clear, action-oriented labels for primary tasks.
* Avoid burying core tasks behind multi-level menus.

**Assessment heuristics**:

* Confirm the site's primary tasks appear on the home page without scrolling.
* Confirm task labels use the same vocabulary the audience uses.
* Confirm users can reach the primary task in three clicks or fewer from the home page.

Source: <https://www.w3.org/TR/coga-usable/#objective-2>.

### control-make-the-site-hierarchy-easy-to-understand-and-navigate

**Control 2.2 Make the Site Hierarchy Easy to Understand and Navigate**

Site navigation must mirror how users think about the content, not how the organisation is structured. Shallow, intuitive hierarchies let users predict where to look. Breadcrumbs and consistent menus help users keep track of their location.

**Design patterns**:

* Group content by user need rather than internal team structure.
* Keep the hierarchy shallow; aim for content to be reachable within three levels.
* Provide breadcrumbs showing the user's current location.
* Maintain the same navigation across all pages.

**Assessment heuristics**:

* Confirm navigation reflects user mental models, not the organisation chart.
* Confirm breadcrumbs are present on every page below the home page.
* Confirm navigation labels and structure are identical across pages.

Source: <https://www.w3.org/TR/coga-usable/#objective-2>.

### control-use-a-clear-and-understandable-page-structure

**Control 2.3 Use a Clear and Understandable Page Structure**

A page's regions must be visually and programmatically distinct so users can scan and skip. Dense, undifferentiated layouts force users to read every word to find what they need.

**Design patterns**:

* Divide pages into visually distinct regions using whitespace, borders, or background variation.
* Use semantic landmarks (`<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>`).
* Provide descriptive headings at each section level.
* Avoid wall-of-text layouts; chunk content into scannable blocks.

**Assessment heuristics**:

* Confirm landmarks divide the page into named regions.
* Confirm heading structure is hierarchical and reflects content organisation.
* Confirm visual region boundaries match the programmatic structure.

Source: <https://www.w3.org/TR/coga-usable/#objective-2>.

### control-make-it-easy-to-find-the-most-important-actions-and-information-on-the-page

**Control 2.4 Make it Easy to Find the Most Important Actions and Information on the Page**

Within a page, the primary action and the most important information must stand out. Users should not have to read or scan extensively to find the call to action. Visual hierarchy and prominent placement direct attention.

**Design patterns**:

* Place the primary action prominently, typically above the fold and styled distinctively.
* Place the most important information near the top of the page.
* Use visual hierarchy (size, weight, colour) to indicate importance.
* Avoid competing primary actions that dilute focus.

**Assessment heuristics**:

* Confirm the primary action is visually distinct from secondary actions.
* Confirm the page has at most one primary call to action.
* Confirm key information appears in the first viewport on common viewports.

Source: <https://www.w3.org/TR/coga-usable/#objective-2>.

### control-break-media-into-chunks

**Control 2.5 Break Media into Chunks**

Long videos, podcasts, and tutorials overwhelm users who need to find or revisit specific content. Chunking media into chapters or segments, providing anchored transcripts, and offering summaries lets users navigate to the part they need.

**Design patterns**:

* Provide chapter markers within long videos and audio.
* Offer transcripts with anchored headings users can jump to.
* Split long media into shorter standalone episodes when feasible.
* Provide a brief summary alongside long media so users can decide whether to watch or read.

**Assessment heuristics**:

* Confirm videos longer than approximately five minutes have chapter markers or segmented playback.
* Confirm transcripts include anchored headings.
* Confirm a written summary accompanies long-form media.

Source: <https://www.w3.org/TR/coga-usable/#objective-2>.

### control-provide-search

**Control 2.6 Provide Search**

Users who cannot remember exact navigation paths benefit from search. Search must tolerate typos, recognise synonyms, and provide suggestions. Search without these affordances frustrates users who cannot spell technical terms or recall exact product names.

**Design patterns**:

* Provide a site search in a conventional location.
* Tolerate common typographical errors and offer "did you mean" suggestions.
* Recognise synonyms and related terms.
* Show recent searches and suggested completions.

**Assessment heuristics**:

* Confirm site search is reachable from every page.
* Confirm search returns useful results for common misspellings.
* Confirm search supports auto-suggest and recent queries.

Source: <https://www.w3.org/TR/coga-usable/#objective-2>.

## Objective 6 - Ensure Processes Do Not Rely on Memory

Objective 6 covers patterns that remove the burden of remembering information across screens, steps, or sessions. The user need is "Memory Support": users with cognitive and learning disabilities, working memory differences, or age-related decline are excluded by interfaces that expect them to memorise instructions, codes, or menu structures.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 6, <https://www.w3.org/TR/coga-usable/#objective-6>.

### control-ensure-processes-do-not-rely-on-memory

**Control 6.1 Ensure Processes Do Not Rely on Memory**

Multi-step processes must not require the user to remember information from earlier steps. Reference numbers, prior selections, and instructions should remain visible or be reproduced where needed.

**Design patterns**:

* Display reference numbers and prior selections persistently throughout multi-step processes.
* Reproduce relevant instructions on the screen where they are needed.
* Provide a summary of prior steps that remains accessible.
* Avoid asking users to memorise temporary codes between screens.

**Assessment heuristics**:

* Confirm information set in earlier steps remains visible when needed later.
* Confirm reference numbers and confirmation codes are persistently visible or saved.
* Confirm instructions are repeated on each screen where they apply.

Source: <https://www.w3.org/TR/coga-usable/#objective-6>.

### control-let-users-avoid-navigating-voice-menus

**Control 6.2 Let Users Avoid Navigating Voice Menus**

Voice menus and interactive voice response trees impose heavy memory and attention demands. Users should have alternative contact methods (text chat, email, web form) so they can complete the task in a modality that suits them.

**Design patterns**:

* Provide alternative contact methods alongside any voice menu.
* Offer a direct route to a human agent.
* Provide a visible flat menu (text) as an alternative to voice trees.
* Allow callbacks rather than requiring users to wait on hold.

**Assessment heuristics**:

* Confirm voice menus are accompanied by web-based alternatives (chat, email, web form).
* Confirm users can reach a human without navigating a deep menu tree.
* Confirm callback options are offered for long wait times.

Source: <https://www.w3.org/TR/coga-usable/#objective-6>.

### control-do-not-rely-on-user-calculations-or-memorising-information

**Control 6.3 Do Not Rely on User Calculations or Memorising Information**

Users should never have to perform mental arithmetic or transcribe information across forms. Compute totals automatically and carry forward data the system already knows.

**Design patterns**:

* Calculate totals, tax, and similar derived values automatically.
* Pre-populate fields with information the system already holds.
* Show running totals and intermediate results clearly.
* Avoid asking users to copy or transcribe data the system can carry forward.

**Assessment heuristics**:

* Confirm derived values (totals, percentages, due dates) are computed automatically.
* Confirm known user information is pre-populated in subsequent forms.
* Confirm users are never asked to perform arithmetic the system can perform.

Source: <https://www.w3.org/TR/coga-usable/#objective-6>.

## Objective 5 - Help Users Focus

Objective 5 covers patterns that reduce distraction and protect the user's attention. The user need is "Attention Support": users with attention-related disabilities, anxiety, or executive function differences struggle when interfaces present competing demands, unnecessary detours, or visual noise. Designs that strip distraction and shorten critical paths help all users complete tasks.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 5, <https://www.w3.org/TR/coga-usable/#objective-5>.

### control-help-users-focus

**Control 5.1 Help Users Focus**

Visual noise, autoplay media, and unsolicited overlays steal attention from the task at hand. Pages must minimise distraction so users can keep their focus on the action they came to perform.

**Design patterns**:

* Reduce competing visual elements on task-focused pages.
* Disable autoplay for video, audio, and animation by default.
* Avoid unsolicited modal overlays during a task.
* Use whitespace and visual hierarchy to direct attention to the primary action.

**Assessment heuristics**:

* Confirm task-focused pages have a single dominant action and minimal competing content.
* Confirm media does not autoplay without explicit consent.
* Confirm overlays appear only in response to user action or as part of the task flow.

Source: <https://www.w3.org/TR/coga-usable/#objective-5>.

### control-make-short-critical-paths

**Control 5.2 Make Short Critical Paths**

The path from intent to completion must be as short as possible. Every detour, intermediate page, or upsell increases the chance the user abandons the task or makes a mistake.

**Design patterns**:

* Remove non-essential steps from critical paths (checkout, sign-in, support contact).
* Combine related steps where it does not increase complexity.
* Offer guest checkout and one-click options where appropriate.
* Avoid forcing account creation before allowing a task to complete.

**Assessment heuristics**:

* Confirm critical paths (checkout, sign-in, primary task) involve the minimum necessary steps.
* Confirm optional information requests are clearly marked as optional.
* Confirm the user can complete a primary task without unrelated detours.

Source: <https://www.w3.org/TR/coga-usable/#objective-5>.

### control-avoid-too-much-content

**Control 5.3 Avoid Too Much Content**

Pages overloaded with information overwhelm users. Showing only what is needed for the current task, with optional detail available on demand, lets users absorb the content at their pace.

**Design patterns**:

* Show only the information needed for the current task.
* Use progressive disclosure (expandable sections, "show more") for optional detail.
* Defer secondary information to separate pages or sections.
* Trim repeated or redundant content.

**Assessment heuristics**:

* Confirm pages display only the information needed to complete the immediate task.
* Confirm optional detail is reachable but does not clutter the default view.
* Confirm content is not repeated within the same page.

Source: <https://www.w3.org/TR/coga-usable/#objective-5>.

## Objective 8 - Support Adaptation and Personalization

Objective 8 covers patterns that let users adapt the interface to their preferences and capabilities. The user need is "User Control": users with cognitive and learning disabilities benefit when they can control motion, integrate assistive extensions, simplify the interface, and personalise the appearance and behaviour to match their needs.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 8, <https://www.w3.org/TR/coga-usable/#objective-8>.

### control-let-users-control-when-the-content-moves-or-changes

**Control 8.1 Let Users Control When the Content Moves or Changes**

Motion, animation, and auto-advancing carousels distract users with attention differences and can trigger vestibular reactions. Users must be able to pause, stop, or disable motion globally.

**Design patterns**:

* Provide pause and stop controls for any moving or auto-advancing content.
* Honour the `prefers-reduced-motion` user preference.
* Disable autoplay for video and animation by default.
* Avoid using motion as the sole indicator of state.

**Assessment heuristics**:

* Confirm `prefers-reduced-motion` disables non-essential animation.
* Confirm auto-advancing content has visible pause and stop controls.
* Confirm motion is not the sole indicator of state changes.

Source: <https://www.w3.org/TR/coga-usable/#objective-8>.

### control-enable-apis-and-extensions

**Control 8.2 Enable APIs and Extensions**

Users rely on browser extensions, reading aids, and assistive technology to adapt content. The site must use standard semantic markup, expose accessibility APIs correctly, and avoid blocking extensions through anti-automation measures.

**Design patterns**:

* Use semantic HTML so reading aids and extensions can parse the content.
* Expose accessibility properties via ARIA where appropriate.
* Avoid blocking browser extensions or assistive technology with anti-automation defences.
* Avoid heavy client-side rendering that hides content from extensions.

**Assessment heuristics**:

* Confirm content is exposed through the accessibility tree, not only through visual rendering.
* Confirm browser extensions (reading aids, simplifiers, translators) can access and modify content.
* Confirm anti-automation measures do not interfere with assistive technology.

Source: <https://www.w3.org/TR/coga-usable/#objective-8>.

### control-support-simplification

**Control 8.3 Support Simplification**

Some users benefit from a simplified version of a page. Sites should support reader modes, provide print-friendly views, and avoid layouts that break under simplification.

**Design patterns**:

* Support browser reader mode by using semantic article markup.
* Provide a print-friendly view that strips navigation and decoration.
* Avoid relying on positioning that breaks when content is linearised.
* Ensure key content is reachable in a single linear reading order.

**Assessment heuristics**:

* Confirm reader mode produces a usable, complete version of the content.
* Confirm a print view is available and includes only the relevant content.
* Confirm the linear reading order matches the visual order.

Source: <https://www.w3.org/TR/coga-usable/#objective-8>.

### control-support-a-personalised-and-familiar-interface

**Control 8.4 Support a Personalised and Familiar Interface**

Personalisation lets users adjust the interface to suit their preferences. Honouring user settings (font size, contrast, dark mode, language) and remembering choices across sessions makes the interface feel familiar and reduces cognitive load.

**Design patterns**:

* Honour user preferences for font size, contrast, dark mode, and language.
* Remember personalisation choices across sessions when the user consents.
* Use standard semantics so personalisation extensions can apply the user's chosen vocabulary, icons, or symbols.
* Avoid forcing a single visual theme on all users.

**Assessment heuristics**:

* Confirm user preferences (`prefers-color-scheme`, `prefers-reduced-motion`, font-size settings) are honoured.
* Confirm personalisation choices persist across sessions when the user has opted in.
* Confirm semantic markup supports personalisation extensions and assistive vocabularies.

Source: <https://www.w3.org/TR/coga-usable/#objective-8>.

