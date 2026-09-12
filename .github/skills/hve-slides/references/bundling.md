---
description: 'Create, adapt, run and check the single-file bundle.mjs pipeline for HVE HTML decks.'
---

# Creating and Using bundle.mjs

Use the maintained modules as the implementation source:
[build.mjs](../templates/deck/build.mjs),
[bundle.mjs](../templates/deck/bundle.mjs) and
[deck.test.cjs](../templates/deck/deck.test.cjs).
Read them before copying; the examples below explain their current interfaces.
Code examples are Microsoft code under the [MIT license](../../../../LICENSE);
prose is CC BY 4.0.

## Pipeline Architecture

```text
Deck source + locally installed reveal.js
                  |
             buildDeck()
                  |
     dist/index.html + CSS + JS + vendor/license
                  |
             bundleDeck()
                  |
         dist/<deck-slug>.html
```

`build.mjs` owns copying source and installed vendor assets into `dist/`.
`bundle.mjs` calls that build, reads its outputs and embeds them into one HTML file.
The bundler is a build-time Node module, not a browser script or server.

| Export | Input/output | Responsibility |
|--------|--------------|----------------|
| `buildDeck()` | Returns the absolute `dist` path | Build the portable folder beside the selected deck's source |
| `createStandaloneHtml(html, assets, license)` | HTML string, `Map` of relative asset paths to source text, notice text; returns HTML | Pure transformation, resource validation and ordered embedding |
| `bundleDeck({ build } = {})` | Optional build function; returns the absolute standalone file path | Call the selected build, gather assets/notices and write the single file |

## Create the Modules for a New Deck

Use the [create-only scaffold script](templates.md) for the complete starter. To adapt a build
pair manually, copy the two named modules, not a generated output folder. A deck named `contributor-tour` needs
`slides/contributor-tour/build.mjs` and `slides/contributor-tour/bundle.mjs`.
If either destination exists, read and adapt it rather than overwriting it.

1. Copy the maintained `build.mjs` source and retain its MIT header. Adapt its `files`
   list to the new deck's actual source files. Keep the reveal.js CSS, JavaScript and
   license entries if reveal.js is still the engine. Update messages that name the old
   directory. Preserve the exported `buildDeck()` function.
2. Copy the maintained `bundle.mjs` source and retain its MIT header. Its import must
   resolve to the new sibling build module:

   ```javascript
   import { buildDeck } from './build.mjs';
   ```

3. Keep the directory-derived output name. If the build returns
   `slides/contributor-tour/dist`, the bundle is
   `slides/contributor-tour/dist/contributor-tour.html`; no hard-coded filename needs
   replacing. Copy the starter's `deck.json` too, or provide its required nonempty
   `title`, `description` and `sourceNote` strings. The build writes `dist/config.js`.

4. Keep `createStandaloneHtml` exported for tests. Keep the direct-execution guard at
   the bottom of both files: importing a module in a test must not silently rebuild or
   overwrite a deck. Resolve paths relative to `import.meta.url`, not the caller's shell
   directory.
5. Merge the commands below into the new deck's `package.json`, preserving other scripts.
   Keep its existing Node tests and pinned reveal.js dependency/lockfile; the bundler
   itself needs only Node built-ins and the sibling build module.

   ```json
   {
     "scripts": {
       "build": "node build.mjs",
       "bundle": "node bundle.mjs",
       "test": "node --test deck.test.cjs"
     }
   }
   ```

6. Update the new deck's README, tests and ignore rules for its actual output name.
   Ignore `dist/` and `node_modules/`. Do not import `../hve-updates/build.mjs` from
   the new deck: that would build the old deck because the module resolves its own root.

These edits create a deck-local build pair with one maintained source to start from.
Do not write a second, less strict string-replacement bundler from the short snippets here.
When the source shape changes, adapt the maintained implementation and its tests together.

HVE Updates uses a thin build-time wrapper that imports this canonical bundler and passes
its existing `buildDeck` function. That keeps one maintained implementation in this
repository without changing its slides or output format. Generated decks copy the complete
module and remain independent of the skill directory; do not copy the HVE Updates wrapper
as their bundler. Future template changes are not automatically applied to existing decks.

## HTML and Script Contract

For the existing architecture, the head of `index.html` contains the following tags in
this order. Keep the complete slide body, startup message and presenter controls elsewhere
in the document; this fragment is not a complete deck.

```html
<link rel="stylesheet" href="vendor/reveal.css">
<link rel="stylesheet" href="theme.css">
<link rel="stylesheet" href="components.css">
<script defer src="vendor/reveal.js"></script>
<script defer src="config.js"></script>
<script defer src="content.js"></script>
<script defer src="components.js"></script>
<script defer src="deck.js"></script>
```

The current parser recognizes these exact double-quoted tag shapes. Added attributes,
reordered attributes, `type="module"` or a different resource shape need parser changes
and regression tests; otherwise the bundler rejects the leftover resource tags.

The `config.js` tag is part of the starter, not the older HVE Updates source. Its contents
are generated from `deck.json`; do not fetch that JSON at browser runtime.
Ordering matters: `content.js` defines the data consumed by `components.js`, and `deck.js`
starts the presentation after the libraries and DOM exist. External classic scripts use
`defer` in the folder build. The standalone build appends inline classic scripts after
the body markup, in the same order, because `defer` does not defer inline scripts.
Preserve that distinction rather than moving all JavaScript into the head.

The transformation handles declared CSS/JS strings, not arbitrary module graphs.
It does not resolve dynamic imports, remote `fetch` calls or browser-created resource URLs.
Inspect runtime code and use the isolated browser check even when markup validation passes.

## Resource and Notice Handling

Preserve the implementation's failure checks:

* Asset paths stay inside the deck; missing assets fail explicitly.
* Source HTML uses declared stylesheets, not inline style blocks or `style` attributes.
* CSS imports and non-embedded CSS URLs are rejected rather than fetched.
* Inline CSS/JavaScript containing unsafe HTML raw-text delimiters is rejected.
* Unsupported resource markup, such as images, media, frames or extra scripts, is rejected.
* The HTML has one closing body tag, and the reveal.js notice is nonempty.

Inline SVG and already embedded CSS data resources fit the current contract. A data URL
in an `img` tag still fails because `img` itself is unsupported. For a new asset type,
either use an existing supported representation or implement explicit embedding and tests.
Do not remove validation simply to make an incomplete file appear successful.

The full installed reveal.js license is copied to `dist/vendor/reveal-LICENSE.txt`, then
embedded in the single file's inert `bundled-third-party-notices` template. Retain notices
for additional redistributed assets. Review their rights and all presenter notes before
sharing; hidden text in an HTML file is still readable.

## A Focused Test Example

This complete CommonJS test can be adapted into the selected deck's `deck.test.cjs`.
Its synthetic notice is test data only; real bundles need the full installed license.
It supplements the maintained missing-resource, unsafe-input and full-deck tests.

```javascript
const test = require('node:test');
const assert = require('node:assert/strict');

test('bundle keeps script order after document markup', async () => {
  const { createStandaloneHtml } = await import('./bundle.mjs');
  const html = '<!doctype html><html><head>'
    + '<link rel="stylesheet" href="theme.css">'
    + '<script defer src="content.js"></script>'
    + '<script defer src="deck.js"></script>'
    + '</head><body><main id="slides"></main></body></html>';
  const assets = new Map([
    ['theme.css', 'body { color: #fff; background: #101114; }'],
    ['content.js', 'globalThis.exampleTitle = "Contributor tour";'],
    ['deck.js', 'document.querySelector("#slides").textContent = globalThis.exampleTitle;']
  ]);
  const result = createStandaloneHtml(html, assets, 'Fixture notice');
  const dataScript = result.indexOf('<script data-bundled-source="content.js">');
  const entryScript = result.indexOf('<script data-bundled-source="deck.js">');
  assert.ok(dataScript > result.indexOf('</main>'));
  assert.ok(entryScript > dataScript);
  assert.doesNotMatch(result, /<script[^>]+(?:src=|defer)|<link\b/);
  assert.match(result, /bundled-third-party-notices/);
});
```

Also exercise the complete `bundleDeck()` path, assert the expected output filename,
compare embedded source against current files and preserve all rejection cases from the
maintained tests. Do not mistake this small transformation test for browser execution.

## Run and View

From the repository root, for the existing deck:

```bash
npm run bundle --prefix slides/hve-updates
npm test --prefix slides/hve-updates
```

For an adapted `contributor-tour` package with the example commands:

```bash
npm run bundle --prefix slides/contributor-tour
npm test --prefix slides/contributor-tour
```

Use the selected package's `npm ci` only when its dependency state requires restoration
under repository rules. A normal `bundle` invocation already builds the folder first;
an extra `build` call is unnecessary. If tests can regenerate output, their final result
is the file to inspect. Rebuild after the last source edit.

Open `slides/hve-updates/dist/hve-updates.html`, or the new deck's corresponding output,
directly in a browser. No server is needed for this architecture.
Copy only that file into an empty temporary directory, rename it, disable network in the
permitted browser context and exercise the selected slides, demos and dialogs. Confirm
there are no runtime requests for sibling files or remote assets. Clean up only the test
files you created.

The final handoff includes the exact single-file path and its regeneration command.
OneDrive can share it for download; recipients open the downloaded file in their browser.
An interactive hosted URL is a separate publishing task, not a capability of OneDrive preview.

## Source References

* [reveal.js installation](https://revealjs.com/installation/): local-file use depends on
  selected resources and plugins.
* [HTML script element](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/script):
  inline versus deferred classic-script behavior.
* [Node.js ECMAScript modules](https://nodejs.org/api/esm.html): `.mjs` and module-relative paths.
