// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
const { closeSync, constants, copyFileSync, fstatSync, mkdirSync, openSync, readFileSync, readdirSync, unlinkSync } = require('node:fs');
const path = require('node:path');

const defaultSource = path.resolve(__dirname, '../../slides');
const defaultDestination = path.resolve(__dirname, '../static/slides');

function readSlideMetadata(file) {
  const descriptor = openSync(file, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  let html;
  try {
    if (!fstatSync(descriptor).isFile()) throw new Error(`Slide bundle must be a regular file: ${file}`);
    html = readFileSync(descriptor, 'utf8');
  } finally {
    closeSync(descriptor);
  }
  const blocks = [...html.matchAll(/<script type="application\/json" id="hve-slide-metadata">([\s\S]*?)<\/script>/g)];
  if (blocks.length !== 1) {
    throw new Error(`Expected one generated slide metadata block in ${file}. Run npm run slides:build.`);
  }
  const metadata = JSON.parse(blocks[0][1]);
  for (const key of ['title', 'description']) {
    if (typeof metadata?.[key] !== 'string' || !metadata[key].trim()) {
      throw new Error(`Slide metadata requires a nonempty ${key} in ${file}. Update deck.json and rebuild.`);
    }
  }
  return { title: metadata.title.trim(), description: metadata.description.trim() };
}

function loadSlideBundles(source = defaultSource) {
  return readdirSync(source, { withFileTypes: true })
    .filter(entry => entry.name.endsWith('.html'))
    .map(entry => {
      if (!entry.isFile() || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*\.html$/.test(entry.name) || entry.name === 'index.html') {
        throw new Error(`Expected a regular, lower-kebab-case deck HTML file other than index.html: ${entry.name}`);
      }
      return { slug: entry.name.slice(0, -5), ...readSlideMetadata(path.join(source, entry.name)) };
    })
    .sort((left, right) => left.title.localeCompare(right.title) || left.slug.localeCompare(right.slug));
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
