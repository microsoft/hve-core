// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDeck } from './build.mjs';

const stylesheetTag = /<link rel="stylesheet" href="([^"]+)">/g;
const scriptTag = /<script defer src="([^"]+)"><\/script>/g;

function escapeHtml(text) {
  return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
}

function localAssetPath(source) {
  if (!/^[a-zA-Z0-9_-]+(?:\/[a-zA-Z0-9_-]+)*\.(?:css|js)$/.test(source)) {
    throw new Error(`Unsupported bundle asset path: ${source}. Use a relative file within the deck.`);
  }
  return source;
}

export function createStandaloneHtml(html, assets, license) {
  const sourceMarkup = html.replace(/<!--[\s\S]*?-->/g, '');
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
  document = document.replace(scriptTag, (_, source) => {
    const js = asset(source);
    if (/<\/script(?=[\s/>])|<!--/i.test(js)) {
      throw new Error(`Cannot inline ${source}: an HTML raw-text delimiter needs to be removed from the JavaScript source.`);
    }
    scripts.push(`<script data-bundled-source="${escapeHtml(source)}">\n${js}\n</script>`);
    return '';
  });
  if (!styles.length || !scripts.length) throw new Error('The deck must declare local stylesheets and deferred scripts.');

  const markup = document.replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '').replace(/<!--[\s\S]*?-->/g, '');
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
  // Inline classic scripts do not support defer; run in document order after the slide markup exists.
  return document.replace(/<\/body>/i, () => `${notices}\n${scripts.join('\n')}\n</body>`);
}

export async function bundleDeck({ build = buildDeck } = {}) {
  const output = await build();
  const html = await readFile(path.join(output, 'index.html'), 'utf8');
  const paths = new Set([
    ...[...html.matchAll(stylesheetTag)].map(match => match[1]),
    ...[...html.matchAll(scriptTag)].map(match => match[1])
  ]);
  const assets = new Map(await Promise.all([...paths].map(async source => [
    source,
    await readFile(path.join(output, localAssetPath(source)), 'utf8')
  ])));
  const license = await readFile(path.join(output, 'vendor/reveal-LICENSE.txt'), 'utf8');
  const standalone = createStandaloneHtml(html, assets, license);
  const destination = path.join(output, `${path.basename(path.dirname(output))}.html`);
  await writeFile(destination, standalone, 'utf8');
  return destination;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const destination = await bundleDeck();
  console.log(`Created ${destination}\nShare this one file. Download it and open it in a browser; no sibling files or server are needed.`);
}
