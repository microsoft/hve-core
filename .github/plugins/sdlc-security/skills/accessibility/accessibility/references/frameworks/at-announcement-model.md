---
title: Assistive-technology announcement model reference
description: What a screen-reader user should hear for the announcement-class success criteria (WCAG 1.3.1, 4.1.2, 4.1.3), used to make announcement correctness specifiable and testable rather than inferred from attribute presence
---

# Assistive-technology announcement model reference

This reference specifies the announcement-class outcomes: **what a screen-reader user should hear**, not merely which attribute is present. Static analysis can confirm that a `role`, an `aria-*` value, or a landmark exists; it cannot confirm that the assistive technology (AT) computes the intended name, role, state, or live update. That gap is where the announcement-class defects (WCAG 1.3.1, 4.1.2, and 4.1.3) survive an all-green static scan.

The expected announcements below are described functionally in the authors' own words. They characterize the computed accessibility outcome, which is a product of the DOM, the accessibility tree, and the AT's presentation logic. They are **not** transcriptions of any assistive-technology product's documentation or speech output: Windows NVDA and JAWS each phrase output differently and none of that phrasing is reproduced here. Use the functional outcome as the acceptance condition and confirm it with an accessibility-tree assertion or a manual AT pass.

Per the consolidated skill's method-adequacy doctrine, every criterion in this file is **decided** by an accessibility-tree assertion of the computed name/role/state or by a manual AT pass, and only **informed** by static attribute presence.

## Repository contract for generated AT cases

The generated AT cases in this skill follow a conservative public contract. The catalog is citation-bearing and reviewable, but the current catalog defaults intentionally remain manual-only for the five starter patterns because the richer AT-mode and quick-navigation semantics are not faithfully modeled by the current structured command vocabulary. Runtime overrides may still create explicit synthetic contract tests for a local workflow, but those tests are candidate evidence only and never a conformance pass.

The case resolver applies state -> surface -> catalog fallback, stores commands and assertions as atomic arrays, and uses an explicit empty array to disable execution. Unknown patterns remain generic manual drafts or project-refinement markers rather than an automated pass; equally specific ambiguity is a configuration error before rendering or driver startup. The public CLI exposes `render-artifacts` as an optional mapping configuration step and `run-at-plan` for list/select/execute/report flows. Supported real-driver stacks are Guidepup-backed Windows NVDA automation plus human-led JAWS evidence; braille, cognitive walkthroughs, unsupported stacks, and synthetic runs remain separate from conformance evidence and must be routed through the shared runbook for later qualified-human review.

Source anchors: W3C WCAG 2.2 (<https://www.w3.org/TR/WCAG22/>) and the W3C Accessible Name and Description Computation (<https://www.w3.org/TR/accname/>), both under the W3C Document License. This reference paraphrases their intent; the success-criterion definitions remain normative in [wcag-22.md](wcag-22.md). This file's framing, acceptance conditions, and taxonomy are repository-original content licensed under CC BY 4.0.

## The name / role / state / value model (WCAG 4.1.2)

Every interactive control conveys four things to AT. A control that renders correctly but computes any of these wrongly fails 4.1.2 even though the control "works" for a mouse user.

| Facet | What the user should hear                                               | Common failure                                                                                                                                                                            |
|-------|-------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Role  | The control's kind ("button", "link", "combobox", "checkbox")           | A `<div>`/`<span>` with a click handler announces as plain text or nothing                                                                                                                |
| Name  | The control's accessible name (its label)                               | An icon-only control announces only its role ("button") with no name                                                                                                                      |
| State | Dynamic state ("expanded"/"collapsed", "checked", "selected", "x of y") | `aria-expanded` announced on a control that is not actually a combobox/disclosure; stale or missing `aria-selected`; wrong `aria-posinset`/`aria-setsize` producing an incorrect "x of y" |
| Value | The current value for inputs, sliders, spinbuttons                      | `aria-valuetext` missing so the user hears a raw number with no unit or meaning                                                                                                           |

Acceptance conditions:

* **Icon-only or dynamic control has a name.** Navigating to it, the user hears a role **and** a name (for example, "Clear search, button"), never a bare role. A clear/close button whose only affordance is an icon must carry an accessible name via `aria-label` or a visually-hidden text node, and the selector that applies it must match the rendered element.
* **Position count is correct.** Arrowing through a set of options, the user hears the true "position of size" (for example, "3 of 12"). This requires correct `aria-posinset`/`aria-setsize` on each option (or letting the upstream widget own them); a focus-stealing hack that corrupts `aria-activedescendant` also corrupts the position count.
* **State is only claimed when true.** `aria-expanded` is exposed only on a control that is genuinely a combobox, disclosure, or menu button, and reflects the real open/closed state; it is not set on a plain text field.

## Structure and relationships (WCAG 1.3.1)

1.3.1 is satisfied when relationships conveyed visually are also conveyed programmatically, so AT can announce them. The frequent failure is a relationship that is visually obvious but has no programmatic association.

### Grouped lists (navigation groups, footer columns, "in this article")

Acceptance condition: navigating into a group, the user hears the **group's title before** its items (for example, the column title, then "list with N items"). A footer column or a table-of-contents list whose visible title is not associated as the accessible name of its `<ul>` announces as a bare list with no group name.

Correct association: give each group's list an accessible name — `aria-labelledby` pointing at the title element's `id`, or wrap the group in a `<nav aria-label>` / `role="group" aria-labelledby`. Apply the same association to footer columns, sidebar groups, and the TOC list, not only to landing-page sections.

### Tables

Acceptance conditions:

* Navigating a data table, the user hears the **table's accessible name** (its caption) on entry, and for each data cell hears the associated **header cell name**.
* Header association requires explicit `scope="col"` / `scope="row"` on `<th>` (or `headers`/`id` for complex spanning tables). Markdown-generated tables that emit `<th>` without `scope` leave association to AT inference, which is partial for single-header tables and fails for row-header or complex tables.
* An accessible name comes from a `<caption>` or an `aria-labelledby`/`aria-label`; a table with no name announces only as a grid of cells. Layout tables carry `role="presentation"` so they are not announced as data tables.

### Headings and outline (also 2.4.10 where in scope)

Acceptance condition: listing headings, the user hears a gap-free outline (H1 → H2 → H3) in which every visually-prominent section title is a real heading. A "heading" produced by a CSS `::before` label, bold text, or a `<div class="*__title">` has **no heading element** for AT to include, so it is absent from the heading list and the outline breaks. Replace faux headings with real `<h*>` elements and move the styling onto the heading selectors so appearance is unchanged.

## Status messages and live regions (WCAG 4.1.3)

4.1.3 is satisfied when a status change that does not move focus is still **announced** by AT. Presence of a `role="status"` or `aria-live` node only informs the criterion; whether the announcement fires depends on the node being in the accessibility tree before the update, on the correct surface, and updated (not replaced) at the moment the status changes.

Acceptance conditions:

* **Present-but-empty at load.** The live region (`role="status"` / `aria-live="polite"`, or `role="alert"` / `aria-live="assertive"` for urgent messages) exists in the DOM at load and is empty, so a later text insertion is announced.
* **On the surface that changes.** The region lives on the surface where the status actually changes. A result-count announcer added only to a navbar search widget does nothing on a separate `/search/` results route that renders its own component — that route needs its own live region. This is the wrong-surface failure: the fix and the reproduction are on different surfaces.
* **Fires on the real change.** Typing a query, the user hears the deterministic count ("N documents found" / "No documents found"); the region updates its text content rather than being torn down and recreated, and is not cleared before AT reads it.
* **Shortcut and helper text announced.** A keyboard shortcut hint or helper description associated via `aria-describedby` is heard after the field's name (for example, the field name followed by its shortcut description). Confirm the described-by target exists and persists through open/close/refocus.

## How to decide these criteria

1. **Accessibility-tree assertion (automatable).** Assert the computed name, role, state, `posinset`/`setsize`, and live-region text in the affected interaction state (`focus`, `open`, `error`, `empty`) using the runtime probe harness (`probe-aria-tree`, `probe-live-region`, `probe-name-in-label`). This is an adequate method and can gate CI.
2. **Screen-reader assertion (automatable — simulated or real).** Capture the announced phrase log and assert the expected outcome. The virtual screen reader (`probe-virtual-sr`) decides announcement composition at the accname/AAM spec layer and runs headless every PR; the real-screen-reader tier (Guidepup driving Windows NVDA) confirms it against actual AT. Both align to the expected assertions catalogued by W3C ARIA-AT (see [Alignment with W3C ARIA-AT](#alignment-with-w3c-aria-at)).
3. **Manual AT pass (authoritative).** For final acceptance on the 1.3.1 / 4.1.2 / 4.1.3 cluster, a documented Windows NVDA or human-led JAWS pass confirms the user actually hears the expected outcome. Record the AT stack in the evidence register's `assistiveTechValidated` field.

A criterion in this cluster is not `covered` until one of these adequate methods decides it. Attribute presence alone caps it at `partial`.

## Alignment with W3C ARIA-AT

The W3C ARIA-AT project (ARIA and Assistive Technologies) maintains a community-reviewed corpus of *expected screen-reader assertions* for the ARIA Authoring Practices Guide patterns across NVDA and JAWS. VoiceOver references remain in this repository only as superseded historical context for earlier planning work, not as current operating guidance. Each test names the commands a user runs and the assertions that must hold in the resulting announcement, so it is the canonical source of "what the AT should say" per pattern per command per screen reader.

This reference's functional expected outcomes align to ARIA-AT rather than re-deriving them: where a widget maps to an APG pattern, prefer the ARIA-AT expected assertions for that pattern as the acceptance condition and cite the ARIA-AT test. The real-screen-reader tier (Guidepup) can execute ARIA-AT-derived command sequences directly, and the generated test cases follow the ACT Rules Format described in [act-rule-format.md](../ci/act-rule-format.md).

Source: W3C ARIA and Assistive Technologies (ARIA-AT), <https://aria-at.w3.org/> and <https://github.com/w3c-cg/aria-at>, published under the W3C Document License. Paraphrase expected assertions and cite the canonical ARIA-AT test; do not reproduce ARIA-AT assertion tables verbatim. Screen-reader command names and reading behaviors are facts, not licensed prose.
