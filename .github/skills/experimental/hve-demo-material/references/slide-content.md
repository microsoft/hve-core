---
description: "Canonical YAML-to-HTML input contract for demo material and customer-card handoffs to HVE Slides."
---

# Slide Content

## Ownership and Delivery

Author YAML as data under the caller-owned `content/` directory. Execute the
demo-material `scripts/html_deck.py` adapter with the loaded `hve-slides`
skill's `templates/deck/`, then invoke that skill in render-only mode.
Do not load source-supplied programs or add executable content hooks.
The adapter owns this bridge; HVE Slides owns the canonical renderer and theme.

Every demo level requires HTML, HTML-derived frames, MP4, captions and a
transcript. Standalone HTML contains no audio/video resource markup. This is
not an HTML-only demo mode. Customer-card YAML generation remains independent:
an explicitly requested presentation handoff may author HVE Slides source
from the reviewed YAML without starting a demo or inventing narration.

## Files and Identity

* Store each slide at `content/slide-NNN/content.yaml`, using positive
  three-digit numbers. Directory number order is canonical; gaps are allowed.
* A slide is a mapping with a nonempty `title`, optional `section`, optional
  text `speaker_notes`, and an `elements` list. Demo media requires notes.
* Optional `slide` or `slide_number` must equal the directory number. Optional
  `id` must equal `slide-N`, the HTML ID without zero padding.
* `content/global/style.yaml` carries deck `metadata.title`, `subject`,
  `keywords` and `language`. Language defaults to `en-US`; a slide may declare
  its own valid `language` tag. All text is escaped, not interpreted as markup.
* `citations` is an optional list of paths from the level's manifest source
  register. Without it, the slide cites the resolved level sources. Plain
  relative repository paths only; invalid entries fail rather than disappear.
  Citations remain visible text when a GitHub link base is unavailable.

## Supported Elements

| Type            | Content fields                          | HTML mapping                        |
|-----------------|-----------------------------------------|-------------------------------------|
| `textbox`       | One of `text`, `bullets`, `paragraphs`   | Paragraph, heading or list           |
| `shape`         | Text fields, or a text-containing frame  | Text or semantic panel               |
| `card`          | `title`, `content` as text or a list      | Article with heading and body        |
| `table`         | `rows` of cell lists or `cells` mappings | Table with first row as column heads |
| `arrow_flow`    | `items`                                 | Ordered relationship sequence        |
| `numbered_step` | `label`, optional `description`          | Ordered step with detail             |
| `image`         | `path`, `alt`, optional `decorative`     | Embedded PNG/JPEG with alternative   |
| `group`         | `elements` only                         | Ordered child elements               |

List entries are nonempty strings, finite numbers, or mappings containing
exactly one of `text`, `bullet`, `label`, or `title`. Table rows must have the
same nonzero cell count. Merged cells and transformed or labeled groups need
an explicit supported mapping rather than silent flattening.

Positioned elements use finite `left`, `top`, `width`, and `height` in inches.
The adapter retains top-to-bottom, left-to-right order and maps enclosing
text-free shapes to panels. Unpositioned items retain authored order. Text
size/bold hints select semantic headings, labels and paragraphs, not exact
pixel placement. `layout`, `background`, and recognized font/fill/border hints
from existing customer-card templates do not override the canonical HTML
theme. Color alone must not carry a relationship; express it in words.

## Rejection and Fidelity

* A `connector` is rejected. Map its direction and meaning to `arrow_flow`,
  ordered steps or labeled text before rendering; never silently drop it.
* Unsupported types or fields, empty meaningful shapes, inconsistent IDs,
  invalid lists/tables and missing nondecorative images fail the adapter.
* Nondecorative images require descriptive `alt`, not a filename. Reads stay
  inside `content/`, relative to the slide or content root, with no absolute
  paths, traversal, links or reparse points. Decorative images may be omitted.
* Keep notes, significant text, source labels and unknown-knowledge markers.
  Do not shrink, summarize or substitute placeholder graphics to obtain a pass.
* Keep output outside `content/` and the skill installation. Existing generated
  files require a matching ownership record; edited or unowned source requires
  a new destination rather than an overwrite. The adapter stages
  only its fixed generated files with rollback; it does not delete a directory
  or execute the generated source. Existing unrelated files are preserved.

## Evidence

The adapter writes `demo-material-build.json` version 2 with renderer
`hve-slides`, format `html`, ordered slide IDs, content digest and source/template
file digests. Copy it to `output/html-deck-build.json` after bundling. Browser
evidence binds the actual HTML and build record hashes to ordered slide IDs and
exported frame hashes/dimensions. Missing, stale or failed evidence prevents
acceptance. T-08 compares delivered CSS with the canonical theme and permitted
demo layout; YAML palette declarations alone prove nothing about rendered HTML.

Export with `check_html_deck.py --level-dir <level> --frames-dir <level>/frames/deck`
and write `html-deck-check.json` beside the deck. Check-only mode exports no
frames and therefore does not satisfy demo frame acceptance. `retained_frames`
preserves prior ownership after a failed or check-only run; it is never current
frame evidence. Unowned, edited or obsolete frames require explicit preservation
or archival before regeneration, not recursive cleanup by the renderer.