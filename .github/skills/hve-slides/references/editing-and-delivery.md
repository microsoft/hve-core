---
description: 'Source ownership, new-deck adaptation and local HTML delivery for HVE presentations.'
---

# Editing and Delivery

## Read the Working Reference

The current implementation is under `slides/hve-updates/`. Read its
[README](../../../../slides/hve-updates/README.md) and the files relevant to the change.
These paths identify the implementation inspected when this skill was created; if they
move or disappear, locate the equivalent within the current repository or report the gap.
Do not search a previous user's home directory for a replacement.

| Source | Owns |
|--------|------|
| `index.html` | Slide order, stable IDs, headings, notes, source keys and component mount points |
| `content.js` | Citation registry, example sequences, phase names, questions and graph data |
| `components.js` | Original VS Code-style rendering, icons and local component interactions |
| `theme.css` | Deck layout, type, colors, process diagrams and presenter chrome |
| `components.css` | Composer, questions, diagrams, diffs, installation UI and agent selection |
| `deck.js` | reveal.js startup, navigation, state, focus, dialogs and keyboard arbitration |
| `build.mjs` | Local source/vendor file list and folder output |
| `bundle.mjs` | Ordered inline styles/scripts and notices in the single-file output |
| `deck.test.cjs` | Content, state, source, graph, bundle and topic-specific regression contracts |
| `package.json`, lockfile, `.npmrc`, `.gitignore` | Local commands, reproducible dependencies and ignored output |

Edit original source, then regenerate `dist/`. Do not patch `dist/index.html` or the one-file
HTML as the source of truth. Keep required coupled changes in the same batch: a new example
kind needs its renderer, styles, data contract, tests and build inclusion.

## Update an Existing Deck

Read the full affected slide or sequence and its consumers. Preserve unrelated user edits,
content, visuals, controls and citations. A request to polish is not permission to rewrite
history or change the selected technology.

* Keep slide IDs stable unless the requested restructuring requires a rename; update hash
  links, source keys, index titles, tests and notes when they change.
* Refer to slides by ID/title while working. Inserting a slide invalidates later numeric
  references, README counts and exact-count assertions.
* Inspect both data and rendering for demo changes. Keep selected phase, question/answer,
  current step, reset, data-driven counts and scope explanations consistent.
* Read the CSS cascade before changing shared selectors. Prefer correcting the owning rule
  to stacking late overrides or adding a different component for the same role.
* Preserve the agent-selection slide and RPI reminders when updating the HVE updates deck.
  Their local help dialogs illustrate the UI; they do not switch the user's real agent.
* Refresh the requested shareable bundle after the last source change. A previously built
  file does not reflect later edits.

## Create a New Deck

Choose an unused lower-kebab-case directory under `slides/`. If it already exists, inspect
it and resolve whether the user wants an update; do not overwrite it as a scaffold.

Use the create-only script described in [templates.md](templates.md). It copies the
declared files from `templates/deck/`, sets the title and package name, and leaves a
self-contained source directory. The neutral starter has no mandatory RPI mounts or
plugin installation content. It does not copy dependencies or generated output.

For an existing deck, use the fragments selectively instead. The following adaptation
checklist also applies when intentionally reusing parts of the larger HVE Updates exemplar;
it is not a requirement to copy that exemplar into every new deck.

Before considering the new scaffold runnable:

1. Replace its title, description, topic, source date, slide IDs, notes and public citation
   registry. Remove inherited historical/version claims that the new brief does not support.
2. Define new example data and relevant renderer kinds. Remove topic-specific sample
   transcripts, inventory, installation results and other unrelated content.
3. Reconcile `deck.js` with the new HTML. The exemplar unconditionally mounts
   `#participation-example` and `#agent-selection-example`, loads RPI data, and replaces
   marked slide labels with RPI reminders. Retain these only when relevant. Remove their
   calls/imports with their mounts, or explicitly model an optional feature; never retain
   a null-element crash or hide a missing required mount behind a silent fallback.
4. Keep cross-file names consistent. The exemplar uses `HVEContent` and `HVEComponents`
   globals and ordered classic scripts. Renaming is optional; partial renames break startup.
5. Keep the build source list, package name, startup messages and README paths consistent.
   The starter derives the bundle filename from its deck directory. Edit `deck.json` for
   its title, description and source note; the build generates `config.js` for the browser.
6. Adapt tests to the new story. Preserve navigation, finite-step, citation, graph/source,
   diff-count and bundle invariants that still apply. Replace exact topic/count/source
   assertions with the new deck's real contract; do not delete functional checks just
   because the copied assertions fail.
7. Keep a pinned reveal.js version and a valid local lockfile. Retain canonical public
   registry settings. Follow repository dependency rules for manifest changes and restores.
   No new framework, editor or service is needed merely to display source.

The exemplar's current file count, slide count, step counts and installed versions are
observations, not universal requirements for new decks.

## Build and Share

Use [bundling.md](bundling.md) when creating or adapting `build.mjs` and `bundle.mjs`.
It shows which maintained files to reuse, the exact supported HTML shape, script ordering,
package commands and a test for the pure bundling function.

Read the selected package's scripts before running commands. For the reference deck:

```bash
npm run build --prefix slides/hve-updates
npm test --prefix slides/hve-updates
npm run bundle --prefix slides/hve-updates
```

Restore dependencies with that install root's `npm ci` when required by repository rules
or a missing-dependency failure. Do not install into the repository root or docs site merely
because a deck has its own package. Do not run restore repeatedly against a known-current
installation.

The folder build opens at `dist/index.html` and needs its local sibling files. The bundle
command rebuilds it and writes `dist/hve-updates.html`. Both can run as local files; they
do not require a server. Confirm the actual command and output for a newly adapted deck.

The one-file bundler supports this source shape, not arbitrary websites. It preserves script
order after the document markup, embeds CSS and data resources, retains the reveal.js license,
and rejects unsupported resource tags, external CSS URLs/imports and unsafe raw-text
delimiters. If new images, fonts or other resources exceed that contract, implement and test
explicit embedding or keep the folder delivery with an honest limitation. Do not remove the
checks and declare success.

Upload or publish only with explicit authorization. OneDrive can store the one-file HTML
for recipients to download and open; its preview is not a static website host. For a browser
URL that runs immediately, use an approved static host and its own access controls. OneDrive
permissions do not transfer to a separate website. Keep library notices and all sharing
privacy limits with the chosen format.

## Delivery References

* [reveal.js installation](https://revealjs.com/installation/): basic local-file delivery;
  server requirements depend on the selected plugins and resources.
* [OneDrive previews](https://support.microsoft.com/en-us/onedrive/file-types-supported-for-previewing-files-in-onedrive-sharepoint-and-teams):
  file preview differs from hosting an interactive application.
