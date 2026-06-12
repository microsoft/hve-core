---
title: "Objective 1 - Help Users Understand What Things Are and How to Use Them"
description: "Objective 1 covers patterns that make the purpose of a page, the role of each control, and the relationship between controls and their effects immediately clear."
---

# Objective 1 - Help Users Understand What Things Are and How to Use Them

Objective 1 covers patterns that make the purpose of a page, the role of each control, and the relationship between controls and their effects immediately clear. The user need is "Clear Purpose" and "Clear Operation": users with cognitive and learning disabilities benefit when sites use predictable, consistent layouts, conventional control shapes, and familiar iconography so that recognition replaces the need for problem-solving.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 1, <https://www.w3.org/TR/coga-usable/#objective-1>.

## control-make-the-purpose-of-your-page-clear

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

## control-use-a-familiar-hierarchy-and-design

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

## control-use-a-consistent-visual-design

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

## control-make-each-step-clear

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

## control-clearly-identify-controls-and-their-use

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

## control-make-the-relationship-clear-between-controls-and-the-content-they-affect

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

## control-use-icons-that-help-the-user

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

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
