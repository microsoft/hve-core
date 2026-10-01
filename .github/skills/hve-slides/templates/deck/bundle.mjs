// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDeck } from './build.mjs';

const stylesheetTag = /<link rel="stylesheet" href="([^"]+)">/g;
const scriptTag = /(?:^[ \t]*)?<script defer src="([^"]+)"><\/script>/gm;

export const revealAsset = 'vendor/reveal.js';
export const supportedRevealVersion = '6.0.2';
export const revealPatches = ['reveal-lazy-src-neutralized', 'reveal-embed-host-regex-neutralized'];
export const securityChecks = ['raw-text-delimiters', 'inline-styles', 'resource-markup', 'reveal-lazy-src'];

// Decks reject media, frames, and data-src attributes, so the bundler removes these unused reveal.js
// paths instead of sanitizing them: DOM-text-to-URL sinks that copy data-src and background-media
// attributes into src, and unanchored embed-host regexes that pick an iframe postMessage target.
// Exact anchors and counts fail closed when a reveal.js update changes the minified code.
const revealSinks = [
  { name: 'lazy-loaded media, source, and iframe data-src', search: 'e.setAttribute(`src`,e.getAttribute(`data-src`))', count: 3, replacement: 'void 0' },
  { name: 'background video source', search: 'n.setAttribute(`src`,t);', count: 1, replacement: 'void 0;' },
  { name: 'background iframe', search: 'a.setAttribute(`src`,r)', count: 1, replacement: 'void 0' },
  { name: 'embedded YouTube host check', search: '/youtube\\.com\\/embed\\//.test(t.getAttribute(`src`))', count: 1, replacement: '!1' },
  { name: 'embedded Vimeo host check', search: '/player\\.vimeo\\.com\\//.test(t.getAttribute(`src`))', count: 1, replacement: '!1' }
];
const lazySourceFlow = /setAttribute\(\s*[`'"]src[`'"]\s*,\s*[\w$.]+\.getAttribute\(\s*[`'"]data-src[`'"]\s*\)\s*\)/;

function escapeHtml(text) {
  return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

function localAssetPath(source) {
  if (!/^[a-zA-Z0-9_-]+(?:\/[a-zA-Z0-9_-]+)*\.(?:css|js)$/.test(source)) {
    throw new Error(`Unsupported bundle asset path: ${source}. Use a relative file within the deck.`);
  }
  return source;
}

export function neutralizeRevealSinks(js, revealVersion) {
  const refresh = 'Review the patched reveal.js code and refresh the anchors in the hve-slides bundler before updating reveal.js.';
  if (revealVersion !== supportedRevealVersion) {
    throw new Error(`reveal.js ${revealVersion} is not supported by the bundler security patches; expected ${supportedRevealVersion}. ${refresh}`);
  }
  let patched = js;
  for (const { name, search, count, replacement } of revealSinks) {
    const found = patched.split(search).length - 1;
    if (found !== count) {
      throw new Error(`reveal.js ${revealVersion} anchor "${name}" matched ${found} times; expected ${count}. ${refresh}`);
    }
    patched = patched.replaceAll(search, replacement);
  }
  return patched;
}

export async function readRevealVersion(dependencyRoot) {
  const manifest = JSON.parse(await readFile(path.join(dependencyRoot, 'package.json'), 'utf8'));
  const pinned = manifest.dependencies?.['reveal.js'];
  let installed;
  try {
    installed = JSON.parse(await readFile(path.join(dependencyRoot, 'node_modules/reveal.js/package.json'), 'utf8')).version;
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    throw new Error(`reveal.js is missing. Run npm ci in ${dependencyRoot} before bundling.`, { cause: error });
  }
  if (installed !== pinned) {
    throw new Error(`Installed reveal.js ${installed} does not match the deck pin ${pinned} in ${dependencyRoot}. Run npm ci before bundling.`);
  }
  return installed;
}

export function createStandaloneHtml(html, assets, license, metadata, { revealVersion } = {}) {
  // Mask ignored regions with separators so validation cannot join new markup tokens.
  const sourceMarkup = html.replace(/<!--[\s\S]*?-->/g, ' ');
  if (/<style\b/i.test(sourceMarkup) || /<[^>]*\sstyle\s*=/i.test(sourceMarkup)) {
    throw new Error('Inline source styles are unsupported. Move styles into a declared local stylesheet before bundling.');
  }
  const scripts = [];
  const styles = [];
  function asset(source) {
    localAssetPath(source);
    const value = assets.get(source);
    if (typeof value !== 'string') throw new Error(`Missing bundle asset: ${source}`);
    return value;
  }

  let document = html.replace(stylesheetTag, (_, source) => {
    const css = asset(source);
    if (/<\/style(?=[\s/>])/i.test(css)) {
      throw new Error(`Cannot inline ${source}: it contains an HTML style end tag.`);
    }
    if (/@import\b/i.test(css)) throw new Error(`Cannot inline ${source}: CSS imports must be bundled first.`);
    for (const [, , target] of css.matchAll(/url\(\s*(['"]?)(.*?)\1\s*\)/gi)) {
      // Resource URLs are not fetched by this bundler. Embedded data and SVG fragments are self-contained.
      if (!/^(?:data:|#)/i.test(target.trim())) {
        throw new Error(`Cannot inline ${source}: CSS URL ${target} is not embedded.`);
      }
    }
    styles.push(source);
    return `<style data-bundled-source="${escapeHtml(source)}">\n${css}\n</style>`;
  });
  let patchedReveal = false;
  document = document.replace(scriptTag, (_, source) => {
    let js = asset(source);
    if (source === revealAsset) {
      js = neutralizeRevealSinks(js, revealVersion);
      patchedReveal = true;
    }
    if (/<\/script(?=[\s/>])|<!--/i.test(js)) {
      throw new Error(`Cannot inline ${source}: an HTML raw-text delimiter needs to be removed from the JavaScript source.`);
    }
    if (lazySourceFlow.test(js)) {
      throw new Error(`Cannot inline ${source}: it copies a data-src attribute into src.`);
    }
    scripts.push(`<script data-bundled-source="${escapeHtml(source)}">\n${js}\n</script>`);
    return '';
  });
  if (!styles.length || !scripts.length) throw new Error('The deck must declare local stylesheets and deferred scripts.');

  const markup = document.replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ').replace(/<!--[\s\S]*?-->/g, ' ');
  if (/<(?:link|script|base|iframe|object|embed|img|audio|video|source)\b/i.test(markup)
    || /\b(?:src|srcset|poster)\s*=/i.test(markup)) {
    throw new Error('The deck contains unsupported resource markup. Embed the resource before creating a single-file bundle.');
  }
  if (!license.trim()) throw new Error('The reveal.js license is required in the standalone bundle.');
  if ((document.match(/<\/body>/gi) || []).length !== 1) throw new Error('The deck must have exactly one closing body tag.');

  document = document.replace(
    /(<div id="startup" role="status">)[\s\S]*?(<\/div>)/,
    '$1Loading the presentation. If it does not open, download the complete HTML file and open it in a browser with JavaScript enabled.$2'
  );
  const notices = `<template id="bundled-third-party-notices"><pre>${escapeHtml(license)}</pre></template>`;
  let catalog = '';
  if (metadata !== undefined) {
    for (const key of ['title', 'description']) {
      if (typeof metadata?.[key] !== 'string' || !metadata[key].trim()) {
        throw new Error(`deck.json requires a nonempty ${key} for the slide catalog.`);
      }
    }
    const json = JSON.stringify({ title: metadata.title.trim(), description: metadata.description.trim() })
      .replaceAll('<', '\\u003c');
    catalog = `<script type="application/json" id="hve-slide-metadata">${json}</script>\n`;
  }
  let provenance = '';
  if (patchedReveal) {
    // Deterministic by design: no timestamps or host details, so generated decks stay byte-stable.
    const json = JSON.stringify({
      generator: 'hve-slides',
      revealVersion,
      patches: revealPatches,
      securityChecks,
      securityCheckResult: 'passed'
    }).replaceAll('<', '\\u003c');
    provenance = `<script type="application/json" id="hve-slide-provenance">${json}</script>\n`;
  }
  // Inline classic scripts do not support defer; run in document order after the slide markup exists.
  return document.replace(/<\/body>/i, () => `${notices}\n${catalog}${provenance}${scripts.join('\n')}\n</body>`);
}

async function renderBundle(build, dependencyRoot) {
  const output = await build();
  const html = await readFile(path.join(output, 'index.html'), 'utf8');
  const paths = new Set([
    ...[...html.matchAll(stylesheetTag)].map(match => match[1]),
    ...[...html.matchAll(scriptTag)].map(match => match[1])
  ]);
  if (!paths.has(revealAsset)) throw new Error(`The deck must load reveal.js from ${revealAsset} so the bundler can apply its security patch.`);
  const assets = new Map(await Promise.all([...paths].map(async source => [
    source,
    await readFile(path.join(output, localAssetPath(source)), 'utf8')
  ])));
  const license = await readFile(path.join(output, 'vendor/reveal-LICENSE.txt'), 'utf8');
  const metadata = JSON.parse(await readFile(path.join(output, 'deck.json'), 'utf8'));
  const deckDirectory = path.dirname(output);
  const revealVersion = await readRevealVersion(dependencyRoot ?? deckDirectory);
  const standalone = createStandaloneHtml(html, assets, license, metadata, { revealVersion });
  const destinationDirectory = path.resolve(deckDirectory, '../../docs/slides');
  const destination = path.join(destinationDirectory, `${path.basename(deckDirectory)}.html`);
  return { destination, standalone };
}

export async function bundleDeck({ build = buildDeck, dependencyRoot } = {}) {
  const { destination, standalone } = await renderBundle(build, dependencyRoot);
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(destination, standalone, 'utf8');
  return destination;
}

export async function checkBundle({ build = buildDeck, dependencyRoot } = {}) {
  const { destination, standalone } = await renderBundle(build, dependencyRoot);
  let actual;
  try {
    actual = await readFile(destination, 'utf8');
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    throw new Error(`Generated bundle is missing: ${destination}. Run npm run slides:build.`, { cause: error });
  }
  if (actual !== standalone) {
    throw new Error(`Generated bundle is stale: ${destination}. Run npm run slides:build.`);
  }
  return destination;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const destination = await bundleDeck();
  console.log(`Created ${destination}\nShare this one file. Download it and open it in a browser; no sibling files or server are needed.`);
}
