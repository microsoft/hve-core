---
description: 'Visual system for HVE Core HTML decks: tokens, type roles, the slide skeleton, components and the checks that keep decks consistent.'
---
<!-- cspell:words Menlo Consolas -->

# Style Guide

Every HVE deck shares one visual system: a token set, a type scale, a slide skeleton and a
small set of components built on them. [HVE Updates](../../../../slides/hve-updates/README.md)
implements all of it and is the deck to compare against. [Design and examples](design-and-examples.md)
explains when to use a layout and [styling recipes](style-recipes.md) show adaptable code.
This guide sets the values and rules both of them assume.

Prose here is CC BY 4.0. Code examples are Microsoft code under the
[MIT license](../../../../LICENSE).

## Visual Character

The decks look like a dark VS Code workbench with an editorial accent. A near-black canvas
carries flat charcoal surfaces and light text. Light blue marks what is current or
interactive, light green marks what is new or passing, and red appears only for removals.
The cover, chapter dividers and closing slide may set one phrase of the title in italic serif.
Content slides stay calm and repeat the same structure, so the audience reads the content
instead of the layout. Reconstructed VS Code UI keeps VS Code's own palette, which keeps it
recognizable as the product rather than as deck chrome.

## Tokens

Declare tokens once in the `:root` block of `theme.css` and use the semantic names in every
rule. Component rules do not hard-code palette values. The exception is a VS Code
reconstruction in `components.css`, which follows the product's palette.

### Color

| Token                                                       | Value                           | Use                                               |
|-------------------------------------------------------------|---------------------------------|---------------------------------------------------|
| `--canvas`                                                  | `#101114`                       | Slide ground and the presenter bar's surroundings |
| `--ink`                                                     | `#f1f2f5`                       | Titles and primary text                           |
| `--ink-soft`                                                | `#d3d9e2`                       | Body text inside cards, timelines and tables      |
| `--muted`                                                   | `#b5b9c5`                       | Secondary text, labels and footnotes              |
| `--faint`                                                   | `#959da9`                       | Inactive items, such as other chapters in a list  |
| `--accent`                                                  | `#a9ceff`                       | Current state, links and identity                 |
| `--positive`                                                | `#b8dda9`                       | New, added, accepted or passing; skill names      |
| `--negative`                                                | `#ffb4b6`                       | Removed or failed                                 |
| `--surface-recessed`                                        | `#141519`                       | Historical or de-emphasized cards                 |
| `--surface`                                                 | `#171b22`                       | Default card                                      |
| `--surface-raised`                                          | `#1d232c`                       | Nodes, tags and chips                             |
| `--surface-accent`                                          | `#1a2535`                       | Current or emphasized card                        |
| `--surface-positive`, `--surface-negative`                  | `#1c2e22`, `#2e1d20`            | Accepted and removed states                       |
| `--line`                                                    | `#333a46`                       | Hairlines, table rules and dividers               |
| `--border`                                                  | `#404958`                       | Card borders                                      |
| `--border-accent`, `--border-positive`, `--border-negative` | `#54709a`, `#618a69`, `#8a575c` | Borders that match their surface                  |
| `--connector`                                               | `#7290b5`                       | Flow lines, arrows and timeline axes              |
| `--glow`, `--glow-chapter`                                  | `#2c3b5650`, `#29467370`        | Ambient light on the viewport                     |

Color repeats a meaning that text, a sign or a shape already carries. An accepted finding
says "Accepted" in its tag; the green only reinforces it. Green is never decoration. These
pairs pass 4.5:1 for body text on every surface they appear on; check any new pair before
using it.

### Type

| Role       | Token               | Design size | Weight and leading              | Use                                 |
|------------|---------------------|-------------|---------------------------------|-------------------------------------|
| Display    | `--text-display`    | 104 px      | 560, 1.04, tracking -0.035em    | Cover title                         |
| Chapter    | `--text-chapter`    | 88 px       | 560, 1.06, tracking -0.03em     | Chapter divider titles              |
| Title      | `--text-title`      | 60 px       | 560, 1.1, tracking -0.025em     | Slide titles (`h2`)                 |
| Heading    | `--text-heading`    | 34 px       | 600, 1.2                        | Card and column headings (`h3`)     |
| Subheading | `--text-subheading` | 28 px       | 600, 1.2                        | Timeline and compact headings       |
| Lead       | `--text-lead`       | 34 px       | 400, 1.4, muted                 | Subtitles on title slides           |
| Body       | `--text-body`       | 27 px       | 400, 1.45                       | Running text                        |
| Small      | `--text-small`      | 24 px       | 400, 1.45, muted                | Supporting text in cards            |
| Caption    | `--text-caption`    | 21 px       | 400, 1.5, muted                 | Footnotes and slide-bottom labels   |
| Label      | `--text-label`      | 18 px       | 650, uppercase, tracking 0.08em | Column labels, field names and tags |

* Set everything that is not code in the system sans stack (`--font-sans`). It matches the
  VS Code UI the decks reconstruct.
* Use monospace (`--font-mono`) for code, commands, file names, IDs, argument values and
  timeline dates. Labels and headings never use it.
* Use the serif italic (`--font-serif`) for one phrase inside a cover, chapter or closing
  title, and nowhere else.
* Keep rendered sizes readable after scaling. At a 1280 by 720 viewport, main text renders at
  least 18 CSS pixels, code at least 16 and minor labels at least 12. Shorten or split content
  before shrinking it.
* Titles use sentence case and `text-wrap: balance`. Body text uses `text-wrap: pretty`.

### Space, Shape and Depth

* Space comes from `--space-1` to `--space-8`: 4, 8, 12, 16, 24, 32, 48 and 64 pixels. Use
  `gap` between siblings. Keep groups tight inside and separate groups generously.
* Corners are `--radius-sm` (6 px) for tags, nodes and chips and `--radius` (10 px) for cards
  and windows. Pills are reserved for ordered steps and markers on an axis.
* Borders are 1 px. Connectors and arrows are 2 px in `--connector`, drawn with CSS borders so
  forced-colors mode repaints them.
* Only reconstructed windows (editor, terminal and walkthrough frame) cast `--shadow-window`.
  Cards stay flat.
* Leave out colored side stripes wider than 1 px, hard offset shadows, gradient panels,
  decorative blur and Unicode arrows standing in for icons.

## Canvas and Background

Slides use a 1600 by 900 design canvas with 44 px top, 64 px side and 40 px bottom padding.
reveal.js scales that canvas to the window, so anything drawn on the section stops at the
scaled slide's edge. Draw the ambient glow on the viewport instead and keep sections
transparent:

```css
body.reveal-viewport { background: radial-gradient(ellipse 72% 78% at 100% 0%, var(--glow), transparent 72%) var(--canvas); }
body.reveal-viewport.chapter { background: radial-gradient(ellipse 62% 88% at 80% 56%, var(--glow-chapter), transparent 72%) var(--canvas); }
.reveal .slides > section { background: transparent; }
[data-reading-view="true"] body.reveal-viewport { background-attachment: fixed; }
```

A divider with `data-state="chapter"` switches to the centered glow, because reveal.js copies
a slide's `data-state` value onto the viewport while that slide shows.

## Slide Skeleton

Every content slide has the same structure:

```html
<section id="review-evidence" data-title="Review the work" data-chapter="RPI" data-sources="review">
  <div class="slide-meta"><span class="tag">Scripted walkthrough</span></div>
  <h2>Review the work against the requirements</h2>
  <div class="slide-body"><!-- one main example, comparison or diagram --></div>
  <p class="footnote">Fidelity, limits or dates in one or two sentences.</p>
  <aside class="notes">Details, pull request numbers and caveats.</aside>
</section>
```

The meta band and footnote are optional. The section is a flex column, so the title lands at
the same position on every content slide (96 px from the top). The body fills the remaining
height and centers its content with auto margins, which keeps a short slide from leaving its
content stuck under the title. The footnote sits at the bottom.

| Slide type      | Class or attribute                          | Structure                                                    |
|-----------------|---------------------------------------------|--------------------------------------------------------------|
| Cover           | `cover-slide`                               | Display title, lead and date beside one supporting visual    |
| Chapter divider | `chapter-slide` with `data-state="chapter"` | Chapter title and lead beside the chapter list               |
| Content         | none                                        | Meta band, title, body and footnote                          |
| Walkthrough     | `demo-slide`                                | Fidelity tag, title and the fixed-height walkthrough frame   |
| Closing         | `closing-slide`                             | Title, commands to try and a footer with the source snapshot |

Do not put an eyebrow or kicker above a title. The presenter bar already names the chapter,
and chapter dividers show where the talk is. Put dates and pull request numbers in the
footnote or the notes.

## Meta Band

The meta band is a right-aligned row above the title. It holds two kinds of item:

* Fidelity tags such as "Scripted walkthrough" and "Reconstructed UI" on reconstructed or
  scripted examples.
* The RPI Agent reminder ("Switch the agent dropdown to RPI Agent for coordinated RPI") on
  every slide about RPI. That includes the RPI chapter divider and a closing slide that
  invites `/rpi-research`. The deck script adds it to any section marked `data-rpi-agent`.

Slides only about HVE Builder or installation do not get the RPI reminder. A slide with
nothing to report leaves the band empty, and its title stays in the same place.

## Components

| Component         | Classes                                                                         | Use it for                        | Rules                                                                 |
|-------------------|---------------------------------------------------------------------------------|-----------------------------------|-----------------------------------------------------------------------|
| Card              | `panel`, `panel current`, `panel historical`                                    | Comparisons and grouped facts     | Flat. The accent surface marks the current option. Never nest cards.  |
| Tag               | `tag`, `tag accent`, `tag positive`, `decision`, `status-chip`                  | State, fidelity and decisions     | The tag's text carries the meaning; color repeats it.                 |
| Label             | `label`, table headers, `dt`                                                    | Naming a column or field          | Uppercase sans at 18 px.                                              |
| Flow              | `flow-arrow`, `flow-arrow down`, `lifecycle-steps`, `loop-line`, `plugin-route` | Ordered steps                     | CSS connectors. Number the steps when order matters.                  |
| Lanes             | `lane-board`, `lanes`                                                           | Helper work that runs in parallel | A trunk with one branch per lane; each lane shows its effort.         |
| Timeline          | `timeline`                                                                      | Dated changes                     | One axis, events on alternate sides, an era marker on the axis.       |
| Table             | `settings-table`, `ledger`                                                      | Reference rows                    | Label-style headers and hairline rules.                               |
| Source panel      | `editor`, `terminal`                                                            | Code and artifacts                | VS Code palette, window shadow and an "Illustrative excerpt" tag.     |
| Talk track        | `talk-track`, `callout`                                                         | Explanation beside evidence       | A heading, short paragraphs and one green takeaway at most.           |
| Chapter list      | `chapter-list`                                                                  | Chapter dividers                  | Every chapter, with `aria-current="true"` on the current one.         |
| Walkthrough frame | `demo`                                                                          | Presenter-stepped examples        | Fixed height. Every step fits with at least 16 px above the controls. |

## Diagrams and Timelines

* Space timeline events evenly and say so in the footnote, unless the slide is about how the
  pace changed. Mark an era boundary on the axis with a text label, and give screen readers
  the same boundary as text in the list.
* Declare graph nodes, edges and any grouping frame in `content.js`. Renderers draw what the
  data says; a frame such as "One parallel batch" lists its member nodes so the text
  description can name them.
* Draw arrows with `.flow-arrow` or SVG markers. Visible markup never uses arrow characters.
* Give every diagram a name and a text description, as
  [design and examples](design-and-examples.md#accessible-slide-content-and-controls) requires.

## Writing on Slides

* A title says what the audience should notice or do, in sentence case, and fits on one line
  at the title size (about 45 characters).
* Keep one idea per card and short sentences in the body. Skip em dashes and bold-prefixed
  lists.
* A footnote states fidelity, limits or dates in one or two sentences.
* Notes hold the detail: pull request numbers, caveats and what was scripted.
* Use the same term for the same thing on every slide, matching the source the slide cites.

## Checks Before Handoff

* Render every slide at 1600 by 900. Titles sit at the same position, nothing overflows the
  canvas and footnotes sit at the bottom.
* Step through every walkthrough. Each step keeps at least 16 px between its content and
  the controls.
* Check reading view at 390 px wide. Nothing overflows horizontally, and every new layout
  class has a reading-view rule.
* Check forced-colors mode. Connectors, timeline dots and the current chapter marker stay
  visible.
* If a design linter is available, such as Impeccable's detector, run it on the changed
  files and explain any finding you keep.

## Adopting the Guide in an Existing Deck

Apply the parts in this order: tokens, background, skeleton, components, then the deck's
tests. The [deck starter](../templates/deck/README.md) already follows the guide.
[RPI with HVE Core](../../../../slides/rpi-with-hve/README.md) and
[RAI Planner](../../../../slides/rai-planner/README.md) draw the glow on the viewport but keep
their eyebrow labels until their next restyle.
