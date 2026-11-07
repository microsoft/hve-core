// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { mkdir, mkdtemp, readdir, rmdir, unlink } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDeck, inspectPath } from '../templates/deck/build.mjs';
import { bundleDeck, checkBundle, readRevealVersion, supportedRevealVersion } from '../templates/deck/bundle.mjs';

const skillRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function contains(root, target) {
  const relative = path.relative(root, target);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

export function parseArguments(args) {
  const values = {};
  for (let index = 0; index < args.length; index += 1) {
    const option = args[index];
    if (!['--deck-dir', '--output', '--check'].includes(option)) throw new Error(`Unknown option: ${option}`);
    const key = { '--deck-dir': 'deckDir', '--output': 'output', '--check': 'check' }[option];
    if (Object.hasOwn(values, key)) throw new Error(`Repeated option: ${option}`);
    if (option === '--check') values.check = true;
    else {
      const value = args[++index];
      if (!value || value.startsWith('--')) throw new Error(`Missing value for ${option}`);
      values[key] = value;
    }
  }
  if (!values.deckDir || !values.output) throw new Error('Both --deck-dir and --output are required.');
  return values;
}

export async function renderDeck({ deckDir, output, check = false }) {
  const source = await inspectPath(deckDir, 'directory');
  const destination = await inspectPath(output, 'file', { allowMissing: !check });
  if (contains(skillRoot, source) || contains(skillRoot, destination)) {
    throw new Error('Deck source and output must be outside the renderer installation. Copy the template into a caller-owned directory.');
  }
  if (contains(source, destination)) throw new Error('Standalone output must be outside the source directory.');
  if (path.extname(destination).toLowerCase() !== '.html') throw new Error('Output must be an .html file.');
  const version = await readRevealVersion(source);
  if (version !== supportedRevealVersion) throw new Error(`reveal.js must be pinned and installed at ${supportedRevealVersion}.`);
  const parent = path.dirname(destination);
  await mkdir(parent, { recursive: true });
  await inspectPath(parent, 'directory');
  const staging = await mkdtemp(path.join(parent, '.html-render-'));
  try {
    // Imported modules are trusted package code, never the caller's build.mjs.
    const options = {
      build: () => buildDeck({ deckDir: source, dependencyRoot: source, output: staging }),
      dependencyRoot: source,
      output: destination
    };
    return await (check ? checkBundle(options) : bundleDeck(options));
  } finally {
    // Delete only regular files in this invocation's private staging directory.
    for (const directory of [path.join(staging, 'vendor'), staging]) {
      let entries;
      try { entries = await readdir(directory, { withFileTypes: true }); }
      catch (error) { if (error.code === 'ENOENT') continue; throw error; }
      for (const entry of entries) {
        const file = path.join(directory, entry.name);
        await inspectPath(file, 'file');
        await unlink(file);
      }
      await rmdir(directory);
    }
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const options = parseArguments(process.argv.slice(2));
    console.log(`${options.check ? 'Checked' : 'Created'} ${await renderDeck(options)}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
