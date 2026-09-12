---
title: HTML slide deck starter
description: Create, edit, build and share a local presentation-first HTML deck.
---

## Build and view

Use Node.js 24 or later. In this deck's directory:

```bash
npm ci
npm run bundle
npm test
```

Restore dependencies only when needed. `bundle` builds the folder first, then writes
`dist/<directory-name>.html`. Open that file directly in a desktop browser. Alternatively,
`npm run build` writes `dist/index.html` with local sibling files. Open generated output,
not the source HTML. No server, live agent or authentication is needed.

The default four slides are neutral layout examples, not researched HVE product claims.
Change them before presenting. The walkthrough is scripted and all chat controls inside
it are display-only; only the presenter controls perform local actions.

## Source owners

| File | Edit here |
|------|-----------|
| `deck.json` | Presentation title, description and source qualification |
| `index.html` | Slide order, stable IDs, headings, notes, citation keys and example mounts |
| `content.js` | Sources, examples, walkthrough steps and state/diff helpers |
| `components.js`, `components.css` | Code, request, question/answer and implementation views |
| `theme.css` | Presentation colors, typography, layouts and controls |
| `deck.js` | Slide/step navigation, dialogs, focus and keyboard behavior |
| `build.mjs` | Local asset list and generation of `dist/config.js` from `deck.json` |
| `bundle.mjs` | Self-contained HTML packaging and resource checks |
| `deck.test.cjs` | Source, state, configuration and bundling tests |

Keep source and generated files separate. Changes to `deck.json` require a rebuild;
the browser reads its generated classic script, not a runtime JSON fetch.
For new slides, provide unique `id`, `data-title`, `data-chapter` and appropriate
`data-sources` values. Keep private evidence out of the source registry and notes.

For a static example, add a `data-example` mount whose key exists in `examples`.
For a walkthrough, add one `data-demo` host and its entry in `demos`. Each step's
phase must appear in that demo's `phases` array. Unknown data fails visibly.
Use a different demo key for another independent walkthrough.

Keep `vendor/reveal.js`, `config.js`, `content.js`, `components.js` and `deck.js`
in that order. The bundler recognizes the declared stylesheet and deferred classic-script
tag shapes. Do not change their attributes or introduce new resource types without
updating the parser and tests. Keep styles in declared CSS files: source inline style
blocks and `style` attributes are rejected by the bundler.

## Presenter controls

| Control | Behavior |
|---------|----------|
| Left / Right, Page Up / Page Down | Previous / next slide |
| Space / Shift+Space | Next / previous slide |
| Home / End | First / last slide |
| Back / Next step, \[ / \] | Previous / next walkthrough step |
| Reset or R | Reset only the current walkthrough |
| O / S / N / ? | Slide index / sources / notes / keyboard help |
| F | Browser full screen when available |
| Escape | Close an overlay and return focus |
| Tab / Enter | Reach and activate controls |
| Motion | Optional fades; reduced-motion preference takes priority |

Focused controls, editable fields, text selections and modifier shortcuts keep their
normal behavior. Walkthroughs retain their step when revisiting slides. Reload restores
the slide hash but resets walkthroughs. Nothing advances automatically.

The design canvas is 1600 by 900 and should also be checked at 1280 by 720.
Compact screens retain controls but are not the intended projected format.

## Verify and share

After editing, run the scoped tests and inspect the actual browser result, including
all changed slides and walkthrough states, keyboard/focus, dialogs and reduced motion.
Node tests do not establish rendered quality or interaction correctness.

Copy only the single HTML file to an empty temporary directory, rename it and open it
with network disabled. It must work without the source folder. Retain the full reveal.js
notice embedded by the bundler and this starter's MIT license in source distributions.

OneDrive can share the file for download; its preview is not website hosting. A hosted
interactive URL requires a separate approved publishing step. Recipients can read every
note, example and embedded source string. Do not include credentials or private data.

## Template maintenance

This deck was created from the repository-only HVE Slides starter. Its files are local
copies, not runtime imports from another deck. Adapt them deliberately; do not overwrite
an existing deck with a newer template.

The repository template is the maintained source for future scaffolds. The full HVE
Updates example may use a thin build-time wrapper around that canonical bundler; a newly
scaffolded deck includes its own complete copy and does not need that wrapper.

The source code is licensed under MIT; see `LICENSE`. This README's explanatory prose
is Microsoft content under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
