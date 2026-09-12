---
description: 'Adaptable CSS architecture, slide layouts and component-data examples for HVE HTML decks.'
---
<!-- cspell:words Menlo Consolas -->

# Styling Recipes

Use these patterns selectively. They illustrate the existing design guidance; they do not
replace the deck shell, its navigation or the user's chosen visual direction. Code examples
are Microsoft code under the [MIT license](../../../../LICENSE); prose is CC BY 4.0.

The [starter and fragment guide](templates.md) provides these patterns as files that can
be copied selectively. Its generic `DeckContent`/`DeckComponents` globals differ from the
larger HVE Updates exemplar's `HVEContent`/`HVEComponents`; use the selected deck's contract.

## Keep the Styling Layers Small

The reference deck loads styles in this order:

```html
<link rel="stylesheet" href="vendor/reveal.css">
<link rel="stylesheet" href="theme.css">
<link rel="stylesheet" href="components.css">
```

| Owner | Put here | Keep elsewhere |
|-------|----------|----------------|
| `theme.css` tokens | Colors, type families, focus and reusable spacing | Topic-specific transcript text |
| `theme.css` layouts | Slide padding, column grids, ordered flows, presenter controls | Copilot component internals |
| `components.css` | Editor surfaces, composer rows, questions, diff lines | Slide order or step state |
| `content.js` | Named example data and source references | HTML strings with inline styles |
| `components.js` | Semantic DOM built from data, state classes and local controls | Repeated per-slide renderers |
| `deck.js` | Navigation and rendering the selected step | Theme colors or copied component markup |

Use the cascade already present. Do not append a second theme or retrofit cascade layers
into an existing deck just to follow an example. Keep page-level controls/dialogs separate
from the scaled `.reveal .slides` content. A viewport media query uses the browser width,
not the logical slide width; shrinking text in both systems can make projected code tiny.

## Theme Tokens

For a new deck, this subset gives slide text and code surfaces a common vocabulary.
In HVE Updates, edit the existing declarations rather than adding another `:root` block.
Keep the rest of the deck's tokens when copying its shell.

```css
:root {
  color-scheme: dark;
  --canvas: #101114;
  --ink: #f1f2f5;
  --muted: #b5b9c5;
  --line: #363d49;
  --cyan: #a9ceff;
  --editor: #1f1f1f;
  --chrome: #181818;
  --editor-text: #cccccc;
  --focus: #a7d8ff;
  --font-mono: "SF Mono", Menlo, Monaco, Consolas, monospace;
}
```

The fixed presentation canvas scales these values when displayed. Choose readable design
sizes and measure their actual rendered size, rather than assuming `font-size: 18px`
on a 1600-pixel-wide slide remains 18 pixels on a smaller screen.

## A Point Beside Its Evidence

Use a narrower explanation and a wider source/example panel. The `minmax(0, ...)` tracks
allow wrapping without a long code line pushing the grid outside the slide.
Add these layout rules to `theme.css` only if an equivalent layout does not exist.

```css
.reveal .story-split {
  display: grid;
  grid-template-columns: minmax(0, .7fr) minmax(0, 1.3fr);
  align-items: start;
  gap: 36px;
}
.reveal .story-split > * { min-width: 0; }
.reveal .story-note p { font-size: 30px; line-height: 1.45; }
.reveal .evidence-surface {
  margin: 0;
  background: var(--editor);
  border: 1px solid var(--line);
  border-radius: 8px;
}
.reveal .evidence-surface figcaption {
  padding: 14px 22px;
  background: var(--chrome);
  border-bottom: 1px solid var(--line);
  color: var(--muted);
  font-size: 23px;
}
.reveal .evidence-surface pre {
  margin: 0;
  padding: 24px;
  color: var(--editor-text);
  font: 28px/1.5 var(--font-mono);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
```

This is one slide fragment for `index.html`, inside the existing `.slides` element.
The excerpt is fictional, not a real completed contributor task. Add the slide's real
source keys when using it to explain an actual HVE artifact.

```html
<section id="scoped-change" data-title="Make one scoped change"
         data-chapter="Contributing">
  <div class="eyebrow">SOURCE AND EVIDENCE</div>
  <h2>Keep the change and its check together</h2>
  <div class="story-split">
    <div class="story-note">
      <p>Change the owning file. Preserve unrelated work.
        Check the visible result before calling it complete.</p>
    </div>
    <figure class="evidence-surface">
      <figcaption>Illustrative changes excerpt</figcaption>
      <pre><code>## Completed work
- [x] Clarify the contributor example

## Check
The updated caption fits beside the source panel.</code></pre>
    </figure>
  </div>
</section>
```

If the example is too dense, shorten it or split the slide. Do not use `overflow: hidden`
to conceal required code or squeeze the explanation into a nearly unreadable column.

## An Ordered Workflow

Use a semantic list for a small linear process. Keep branch/merge relationships in an
SVG or diagram backed by one graph model instead of forcing them into this layout.
Add the rules below to `theme.css`; the labels belong in `index.html` or example data.

```css
.reveal .story-flow {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 24px;
  margin: 38px 0 0;
  padding: 0;
  list-style: none;
}
.reveal .story-flow li {
  position: relative;
  min-width: 0;
  padding: 24px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: var(--editor);
}
.reveal .story-flow li:not(:last-child)::after {
  content: "";
  position: absolute;
  top: 50%;
  left: 100%;
  width: 24px;
  height: 2px;
  background: var(--line);
}
.reveal .story-flow strong { display: block; font-size: 30px; }
.reveal .story-flow span { display: block; margin-top: 12px; font-size: 25px; }
```

```html
<ol class="story-flow" aria-label="Contributor workflow">
  <li><strong>1. Find the source</strong><span>Locate the owner.</span></li>
  <li><strong>2. Read the contract</strong><span>Confirm the boundary.</span></li>
  <li><strong>3. Make the change</strong><span>Keep it scoped.</span></li>
  <li><strong>4. Check the result</strong><span>Inspect the output.</span></li>
</ol>
```

The number of tracks matches this four-step example. Adjust the grid when the process
changes; do not squeeze a fifth node into a layout that still declares four columns.
Label a current/blocked state in text as well as color.

## Reuse a Copilot Component

For a presenter-stepped request, add a data object like this to the relevant
`demos.<name>.steps` array in `content.js`. Its `phase` must also appear in that demo's
`phases` list. Preserve the existing demo host and step controls in `deck.js`.

```javascript
{
  phase: 'Request',
  state: 'Waiting for direction',
  kind: 'composer',
  title: 'Start with a bounded request',
  context: 'GitHub Copilot Chat',
  body: 'Clarify the contributor example. Keep the existing controls and source links.',
  attachments: ['README.md'],
  mode: 'Agent',
  insight: 'This is a scripted request, not a message sent to Copilot.'
}
```

This is an object literal to insert into an array, not a standalone executable script.
The existing `renderExample` dispatcher selects `renderComposer`; its context chips,
body and agent/model row are styled in `components.css`. A label in a chat request is
data, not permission to change the user's real agent. Do not rebuild the composer with
inline HTML or turn its decorative send glyph into a dead focusable button.

For a live local presentation control, use a real button and the existing action handler.
Keep keyboard focus visible:

```css
.demo-controls button:focus-visible {
  outline: 3px solid var(--focus);
  outline-offset: 4px;
}
```

## Diagrams and Changes Views

Use the implementation patterns already present in
[content.js](../../../../slides/hve-updates/content.js) and
[components.js](../../../../slides/hve-updates/components.js):

* Declare nodes and edges once. Let `mermaidSource` and the constrained diagram preview
  consume the same graph. Keep source/preview parity when adding or renaming nodes.
* Use typed nodes for user, model, tool and subagent calls in an illustrative research trace.
  Derive connectors from node positions, rather than drawing unrelated decorative arrows.
* Keep the completed-task list and changes excerpt in one column, with the changed-file
  summary, readable diff and compact composer in the other. `diffStats` derives counts
  from the actual displayed `add` and `remove` rows.

Those renderers explain small authored examples; they are not a VS Code extension host
or general-purpose Mermaid interpreter.

## Source References

* [Reference theme](../../../../slides/hve-updates/theme.css) and
  [component styles](../../../../slides/hve-updates/components.css): current maintained implementation.
* [CSS Grid](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_grid_layout):
  track sizing and layout concepts.
* [VS Code source](https://github.com/microsoft/vscode): verify current UI structure before
  depicting additional client components.
