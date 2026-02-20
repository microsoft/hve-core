---
description: "Required instructions for creating or editing any Markdown (.md) files"
applyTo: '**/*.md'
---
# Markdown Instructions

These instructions define the Markdown style guide enforced by markdownlint in this codebase. Follow them when creating or updating any `.md` file here. Examples are included in XML-style blocks that downstream tools can extract.

## Scope

* Applies to all Markdown files in this codebase excluding files with `<!-- markdownlint-disable-file -->`.
* Mirrors the active configuration in `.markdownlint.json`.
* When in doubt, prefer clarity and consistency. Automated fixes are acceptable if they preserve intent.

## General conventions

* Use UTF-8 and plain ASCII punctuation unless content requires otherwise.
* Prefer descriptive headings and concise paragraphs; avoid trailing or leading extra spaces.
* Keep lines reasonably short for readability; wrap where sensible without breaking URLs or code.

## Headings

* Start documents with a single level-1 heading that acts as the title when appropriate.
* Increase heading levels by one at a time; do not skip levels.
* Use a consistent heading style per file. Prefer ATX style (`#`, `##`, `###`, ...) for new content.
* Do not indent headings; they must start at column 1.
* Surround each heading with a blank line above and below (except at file start/end).
* Do not end headings with punctuation such as `. , ; : !` or their full-width variants.
* Avoid duplicate headings under the same parent section; make them unique.
* Do NOT use an H1 heading when YAML frontmatter contains a `title:` field. The frontmatter title satisfies MD025 and MD041. Start content with H2 or below after frontmatter. If no frontmatter exists, begin the file with a top-level heading.
* Use exactly one space after the `#` characters in headings; do not omit or use multiple spaces.
* If you close ATX headings with trailing `#` characters, use a single space between the text and both the opening and closing hashes; do not use multiple spaces on either side.
* Use only one top-level heading per document; subsequent sections must use lower levels.

<!-- <example-headings> -->
```markdown
# Title

## Section

### Subsection
```
<!-- </example-headings> -->

## YAML Frontmatter

* All markdown files MUST include YAML frontmatter at the beginning of the file
* Frontmatter MUST be the first content in the file (before H1 heading)
* Use triple-dash delimiters (---) on separate lines to wrap frontmatter YAML
* Frontmatter provides machine-readable metadata for validation, SEO, and site generation
* Do NOT use an H1 heading when frontmatter includes a `title:` field; the title in frontmatter acts as the document title per MD025/MD041
* Start document content with H2 or below when frontmatter contains a `title:` field

### Required Fields by File Type

| File Type                                               | Required Fields          | Schema File                              |
|---------------------------------------------------------|--------------------------|------------------------------------------|
| Root community files (README.md, CONTRIBUTING.md, etc.) | `title`, `description`   | `root-community-frontmatter.schema.json` |
| Documentation files (`docs/**/*.md`)                    | `title`, `description`   | `docs-frontmatter.schema.json`           |
| Instruction files (`.github/**/*.instructions.md`)      | `description`, `applyTo` | `instruction-frontmatter.schema.json`    |
| Agent files (`.github/**/*.agent.md`)                   | `description`            | `agent-frontmatter.schema.json`          |
| Prompt files (`.github/**/*.prompt.md`)                 | `description`            | `prompt-frontmatter.schema.json`         |

### Recommended Fields

* `author`: Author or team responsible for the content
* `ms.date`: Last modified date in ISO 8601 format (YYYY-MM-DD)
* `ms.topic`: Documentation topic type (overview, concept, tutorial, reference, how-to, troubleshooting)
* `keywords`: Array of keywords for content categorization
* `estimated_reading_time`: Positive integer (minutes)

### Date Format

* MUST use ISO 8601 format: YYYY-MM-DD (e.g., `ms.date: 2025-11-15`)
* Do NOT use MM/DD/YYYY, DD/MM/YYYY, or other formats

### Schema Validation

* Schemas are located in `scripts/linting/schemas/`
* Pattern-based mapping in `schema-mapping.json` determines which schema applies to each file
* VS Code YAML extension (`redhat.vscode-yaml`) provides in-editor validation
* Run validation: `npm run validate:frontmatter` or `pwsh scripts/linting/Validate-MarkdownFrontmatter.ps1`

### Schema Pattern Matching

Files are validated against schemas based on glob pattern matching:

* Patterns are evaluated in order from most specific to least specific
* First matching pattern determines the schema
* If no pattern matches, `base-frontmatter.schema.json` is used as default
* Pattern syntax supports:
  * `**` for recursive directory matching
  * `*` for single path segment wildcard
  * `|` for alternation (e.g., `README.md|CONTRIBUTING.md`)

Pattern examples:

* `.github/**/*.instructions.md` - All instruction files in .github directory tree
* `docs/**/*.md` - All markdown files under docs directory
* `README.md|CONTRIBUTING.md` - Exact filename match (alternation)

### Examples

<!-- <example-frontmatter-docs> -->
```yaml
---
title: Getting Started with HVE Core
description: Quick setup guide for using HVE Core Copilot customizations in your projects
author: Microsoft
ms.date: 2025-11-15
ms.topic: tutorial
keywords:
  - github copilot
  - setup
  - getting started
estimated_reading_time: 5
---

# Getting Started with HVE Core

This guide shows you how to configure your project...
```
<!-- </example-frontmatter-docs> -->

<!-- <example-frontmatter-instructions> -->
```yaml
---
description: "Required instructions for creating or editing any Markdown (.md) files"
applyTo: '**/*.md'
---

# Markdown Instructions

These instructions define the Markdown style guide...
```
<!-- </example-frontmatter-instructions> -->

## Lists

* Use unordered list markers consistently across a file; for the same level, do not mix `*`, `+`, `-`.
  * Try to always use `*` for unordered lists.
  * Avoid using `-` and `+` for unordered lists unless the file already uses these.
* Indent unordered sublist content by 2 spaces per level.
* Keep indentation consistent for items at the same nesting level.
* Use one space between any list marker and the list text for both ordered and unordered lists.
* Surround lists with a blank line before and after (unless at file start/end).
* For ordered lists, either use `1.` for all items or increment numerically; do not mix styles within a list. Leading zeros are allowed only when used consistently.

<!-- <example-lists> -->
```markdown
* Item 1
* Item 2
  * Nested item

1. Step
2. Step
3. Step
```
<!-- </example-lists> -->

### Bullet point punctuation

Follow professional editorial standards for bullet point punctuation consistency:

* **Fragment bullet points** (short phrases, technical terms, simple commands): Do NOT end with periods.
* **Complete sentence bullet points** (subject + verb constructions): End with periods.
* Based on Google, Microsoft, and GitLab style guidelines

<!-- <example-bullet-punctuation> -->
```markdown
* Configuration file
* API endpoint
* User authentication
* Enable debugging mode

* This function validates the input parameters
* The system processes requests asynchronously
* Users can configure settings through the UI
* When enabled, it provides detailed logging information
```
<!-- </example-bullet-punctuation> -->

## Code blocks and code spans

* Use fenced code blocks consistently (prefer triple backticks) and surround them with a blank line before and after. Use fenced code instead of indented code blocks.
* Always specify a language for fenced code blocks; use `text` if no highlighting is desired.
* Avoid tabs; use spaces everywhere. Do not include hard tab characters in code, lists, or text.
* Do not add spaces just inside backticks of code spans; write `` `code` `` not `` ` code ` ``.
* For shell examples, do not prefix commands with `$` unless you also show the command output; prefer copy-pasteable commands without the prompt.
* Use backticks for code fences consistently across the repository; do not use tildes.

<!-- <example-code> -->
````markdown
```bash
# Good
echo "Hello"
```

Some inline `code` here.
````
<!-- </example-code> -->

## Links and images

* Do not reverse link syntax; write `[text](url)`.
* Do not use empty links like `[]()` or `(#)`; always provide a valid destination.
* Avoid bare URLs; wrap them in angle brackets like `<https://example.com>` or make them proper links with text.
* Ensure link fragments match generated heading IDs (kebab-case, lower-case). Use `<a id="...">` when needed.
* Provide alternate text for all images. If an image must be hidden from assistive tech, use `aria-hidden="true"` in HTML.
* Keep spaces out of link text brackets: `[text]`, not `[ text ]`.
* Use a consistent link/image style within a document. Inline and autolink styles are allowed. When using full `[text][label]` or collapsed `[label][]` references, ensure the corresponding `[label]: URL` is defined. Remove unused or duplicate reference definitions.
* If literal bracketed text is intended (not a link), escape the brackets as `\[text\]`.

<!-- <example-links-images> -->
```markdown
See <https://example.com> and [Docs](https://example.com/docs).

![Diagram](./diagram.png)
```
<!-- </example-links-images> -->

## Spacing and blank lines

* Limit paragraph and prose lines to approximately 500 characters; keep headings under 80 characters.
* Do not add trailing spaces at the end of lines except when intentionally forcing a hard line break; when forcing breaks, use exactly two spaces.
* Do not use multiple consecutive blank lines; keep at most one in a row.
* Surround fenced code blocks, headings, lists, and tables with a blank line before and after (unless at file start/end).
* Files must end with a single newline; no extra blank lines at EOF.
* Do not break long URLs or long words to satisfy line length. Headings should honor their shorter limit; tables are exempt from line length checks. Code blocks may exceed normal line length; avoid wrapping code for width alone.

## Blockquotes

* Use a single space after the `>` marker; avoid multiple spaces.
* Do not place a bare blank line between adjacent blockquotes unless they are the same quote (then include `>` on the blank line to continue it).
* Inside blockquotes, apply the same list and code rules; when creating tight lists with code fences inside blockquotes, consider whether a blank line is required for your target renderer.

<!-- <example-blockquotes> -->
```markdown
> Quoted text continues
>
> Same quote after a blank line.
```
<!-- </example-blockquotes> -->

## Horizontal rules

* Use one horizontal rule style consistently within a document. Prefer `---`.

## Emphasis

* Use a consistent style for emphasis and strong emphasis throughout a document. Prefer `*italic*` and `**bold**` for new content.
* Do not put spaces inside emphasis markers: `**bold**`, not `** bold **`.
* Do not use emphasis-only lines as section separators; use proper headings instead.
 * Avoid emphasis within words using underscores; prefer asterisks for word-internal emphasis if absolutely necessary.

## Tables

* Surround tables with a blank line before and after (unless at file start/end).
* Use a consistent pipe style; prefer leading and trailing pipes on all rows.
* Ensure every row has the same number of cells as the header.
* Keep header and delimiter rows aligned in column count so the table is recognized by renderers.
* Use aligned column style: all pipe characters must align vertically across all rows. Pad cell content with spaces so pipes line up.

<!-- <example-tables> -->
```markdown
| Column A | Column B | Column C |
|----------|----------|----------|
| Short    | Medium   | Longer   |
| A        | BB       | CCC      |
```
<!-- </example-tables> -->

## Miscellaneous

* Do not include inline HTML unless necessary; if used, limit to explicitly allowed elements like `<details>` and `<summary>` in this repository.
* Fenced code blocks must declare a language; use a recognized language name. If no highlighting is desired, use `text`.
* Follow proper capitalization for product and technology names used in this repository (e.g., "GitHub", "JavaScript").
 * Avoid using inline HTML when a Markdown equivalent exists. If an inline HTML element is necessary and allowed, keep it minimal and well-formed.
* Ensure files end with exactly one trailing newline character.
* Use a consistent fence marker for code blocks (backticks) across a file.
* Use a consistent emphasis style throughout a file (prefer asterisks for both italic and bold).
* Validate intra-document link fragments; they must match the generated IDs of headings or explicitly provided anchors. Prefer lower-case, dash-separated fragments.
* When using reference-style links or images, ensure the referenced labels are defined. Remove any unused or duplicate reference definitions. Keep the special checkbox syntax `[x]` intact.
* Link and image styles allowed: autolinks `<https://...>`, inline `[text](url)`, and reference `[text][label]`/`[label][]`. Avoid bare URLs in text; prefer autolink syntax. Avoid inline links where the link text equals the same absolute URL with no title; prefer autolink.
* For tables, apply a consistent leading/trailing pipe style; prefer both leading and trailing pipes. Ensure all rows have the same number of cells as the header.
