// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
const { copyFileSync, mkdirSync, readdirSync, unlinkSync } = require('node:fs');
const path = require('node:path');

const defaultSource = path.resolve(__dirname, '../../slides');
const defaultDestination = path.resolve(__dirname, '../static/slides');

function loadSlideBundles(source = defaultSource) {
  return readdirSync(source, { withFileTypes: true })
    .filter(entry => entry.name.endsWith('.html'))
    .map(entry => {
      if (!entry.isFile() || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*\.html$/.test(entry.name) || entry.name === 'index.html') {
        throw new Error(`Expected a regular, lower-kebab-case deck HTML file other than index.html: ${entry.name}`);
      }
      return { slug: entry.name.slice(0, -5) };
    })
    .sort((left, right) => left.slug.localeCompare(right.slug));
}

function syncSlideBundles(source = defaultSource, destination = defaultDestination) {
  const decks = loadSlideBundles(source);
  mkdirSync(destination, { recursive: true });
  const names = new Set(decks.map(deck => `${deck.slug}.html`));
  for (const name of names) {
    copyFileSync(path.join(source, name), path.join(destination, name));
  }
  for (const entry of readdirSync(destination, { withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith('.html') && !names.has(entry.name)) {
      unlinkSync(path.join(destination, entry.name));
    }
  }
  return decks;
}

module.exports = { loadSlideBundles, syncSlideBundles };

if (require.main === module) {
  try {
    const decks = syncSlideBundles();
    console.log(`Staged ${decks.length} slide bundle(s) for Docusaurus.`);
  } catch (error) {
    console.error(`Could not stage slide bundles: ${error.message}`);
    process.exitCode = 1;
  }
}
