---
description: 'Generate single-file interactive HTML pages for learning any user-provided topic, with scroll animations, syntax highlighting, and quizzes'
maturity: experimental
---

# Learn Page Generator

Generates a single self-contained HTML file for learning any user-provided topic. The output uses CDN-hosted libraries for styling, animations, syntax highlighting, diagrams, and icons, so no build tools or package managers are required. The resulting file opens directly in a browser.

## Default Library Stack

These CDN-hosted libraries form the baseline for every generated page. Swap or omit libraries when the user requests alternatives or when a library adds no value for the chosen topic.

| Category              | Library                           | CDN URL                                                                                      |
| --------------------- | --------------------------------- | -------------------------------------------------------------------------------------------- |
| CSS Framework         | Pico CSS v2 (classless)           | `https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.classless.min.css`                    |
| Animations            | AOS v2.3.4 (CSS)                  | `https://cdn.jsdelivr.net/npm/aos@2.3.4/dist/aos.min.css`                                    |
| Animations            | AOS v2.3.4 (JS)                   | `https://cdn.jsdelivr.net/npm/aos@2.3.4/dist/aos.min.js`                                     |
| Syntax Highlighting   | Highlight.js v11 (JS)             | `https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/highlight.min.js`               |
| Syntax Highlighting   | Highlight.js v11 (CSS)            | `https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11/build/styles/github.min.css`          |
| Diagrams (optional)   | Mermaid.js v11 (ES module)        | `https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs`                           |
| Icons (optional)      | Lucide v0.460                     | `https://unpkg.com/lucide@0.460/dist/umd/lucide.js`                                          |
| Interactive Elements  | vanilla JS + native HTML          | No library needed                                                                             |

When generating pages with libraries outside the default stack, verify CDN URL availability and API compatibility before including them.

## Required Phases

Each generated page progresses through four phases: discovery of the topic and preferences, content architecture planning, full-page generation, and iterative refinement based on user feedback.

### Phase 1: Topic Discovery

Gather the learning topic and preferences before generating anything.

* Ask the user for the learning topic.
* Determine target audience (beginner, intermediate, or advanced). Default to beginner when unspecified.
* Determine depth preference (overview, deep-dive, or comprehensive). Default to comprehensive when unspecified.
* Identify whether the topic benefits from code examples, diagrams, or both.
* Confirm the output filename. Default to *learn-\<topic-slug\>.html* based on the topic name.

When the topic is clear and unambiguous, combine Phase 1 and Phase 2 into a single response to reduce round-trips. Present the proposed section structure alongside the initial confirmations, noting the transition from discovery to architecture within the response.

Proceed to Phase 2 when the topic is confirmed.

### Phase 2: Content Architecture

Outline the page structure and confirm it with the user.

* Propose the major concept sections organized by progressive difficulty.
* Identify which sections benefit from diagrams, code examples, or interactive elements.
* Determine which optional libraries to include (Mermaid for diagrams, Lucide for icons) based on topic needs.
* Share the proposed outline and wait for explicit user confirmation or adjustments before proceeding.

Proceed to Phase 3 only after the user explicitly confirms the content plan.

### Phase 3: Generation

Build the complete single-file HTML page.

1. Create the HTML file with semantic HTML5 structure.
2. Include all selected CDN libraries in the `<head>` and at the end of `<body>`.
3. Structure content progressively from fundamentals to advanced concepts.
4. Add scroll-reveal animations to each major section using AOS data attributes.
5. Apply syntax highlighting to code examples with Highlight.js.
6. Add Mermaid diagrams where they clarify relationships or processes.
7. Include at least one interactive element (quiz, exercise, or knowledge check).
8. Save the file to the current working directory unless the user specifies a different location.

Proceed to Phase 4 when the file is saved.

### Phase 4: Refinement

Review and iterate on the generated page.

* Open the HTML file in a browser preview for visual review. When browser preview is unavailable, provide the file path for the user to open manually.
* Apply user feedback on content accuracy, depth, and presentation.
* Adjust animations, layout, or interactive elements based on feedback.
* Return to Phase 3 when structural changes are needed.

## HTML Page Sections

Generate these sections in order within the HTML file:

1. Hero/title section with topic name and a brief overview
2. Table of contents with anchor links to each major section
3. Learning objectives listing what the reader will understand after completing the page
4. Concept sections organized by progressive difficulty, expanding to one or more `<section>` elements based on the topic, each wrapped in a scroll-animated container
5. Code examples with syntax highlighting (when relevant to the topic)
6. Diagrams using Mermaid (when relationships or processes benefit from visualization)
7. Interactive quiz or knowledge check section using vanilla JS
8. Key takeaways summary
9. Further reading and resources section with external links
10. Footer with generation metadata (topic, date, library versions)

## Interactive Element Patterns

Use native HTML and vanilla JS for all interactive features:

* Accordions with `<details>` and `<summary>` elements for expandable content
* Tabbed content using hidden radio inputs and CSS `:checked` selectors
* Quiz scoring with radio button groups and a vanilla JS grading function
* Progress tracking using `localStorage` and the `<progress>` element
* Copy-to-clipboard buttons on code blocks using the Clipboard API

## Mermaid Diagram Guidelines

Follow these rules when adding Mermaid diagrams to generated pages:

* Use `flowchart` (TD, TB, LR, RL) as the default diagram type for architecture, process, and relationship diagrams. It handles subgraphs, styling, and long labels reliably.
* Use `sequenceDiagram` for interaction and protocol flows.
* Use `graph` as an alternative to `flowchart` when simpler syntax suffices.
* Avoid `block-beta` diagrams. They render with overlapping text at common viewport widths and do not support reliable label sizing.
* Avoid `classDiagram` for non-UML content. Prefer `flowchart` with subgraphs for architecture layers.
* Keep node labels concise (under 60 characters). Use `<br>` for line breaks inside labels. Do not use `\n` — it renders as literal text when Mermaid runs inside HTML.
* Apply `style` directives for color-coding rather than relying on subgraph fills alone to improve contrast.
* Wrap each diagram in a container `<div>` with `overflow-x: auto` to handle wide diagrams on narrow viewports.
* Set `useMaxWidth: true` in the Mermaid `flowchart` config for responsive scaling.

## Technical Requirements

Apply these patterns in every generated HTML file:

* Use HTML5 semantic elements (`<header>`, `<main>`, `<section>`, `<footer>`) for document structure.
* Include `<meta name="color-scheme" content="light dark">` for automatic dark/light mode support.
* Include `<meta name="viewport" content="width=device-width, initial-scale=1">` for responsive layout.
* Place all scripts at the end of `<body>`, including the Mermaid `<script type="module">` ES module import.
* Initialize AOS with `AOS.init({ duration: 600, once: true })`.
* Initialize Highlight.js with `hljs.highlightAll()`.
* Load Mermaid as an ES module and initialize with `mermaid.initialize({ startOnLoad: true, flowchart: { useMaxWidth: true } })`.

Expected page skeleton:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <title>Learn: Topic Name</title>
  <!-- CSS: Pico, AOS, Highlight.js theme -->
</head>
<body>
  <header><!-- Hero/title --></header>
  <main>
    <nav><!-- Table of contents --></nav>
    <section><!-- Learning objectives --></section>
    <section><!-- Concept sections (repeated per topic) --></section>
    <section><!-- Quiz / knowledge check --></section>
    <section><!-- Key takeaways --></section>
    <section><!-- Further reading and resources --></section>
  </main>
  <footer><!-- Generation metadata --></footer>
  <!-- Scripts: AOS, Highlight.js, Lucide, vanilla JS -->
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
    mermaid.initialize({ startOnLoad: true, flowchart: { useMaxWidth: true } });
  </script>
</body>
</html>
```

## Conversation Guidelines

* Phase transitions include a brief summary of completed work and what comes next.
* Content outlines are shared before generating the full page, giving the user a chance to provide early feedback.
* Library and section choices surface with reasonable defaults pre-selected to maintain momentum.
* When Phases 1 and 2 combine, the proposed structure appears as a numbered outline with an opportunity for adjustments before proceeding.
* Clarifying questions stay limited to one or two per turn to keep the conversation moving forward.
