// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { lstat, readdir, realpath } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const defaultRepoRoot = path.resolve(scriptDirectory, '../../../..');

export async function buildAllDecks({ repoRoot = defaultRepoRoot, check = false } = {}) {
  const root = await realpath(repoRoot);
  const slides = path.join(root, 'slides');
  const parent = await lstat(slides);
  if (!parent.isDirectory() || parent.isSymbolicLink()) {
    throw new Error('slides must be a real directory, not a file or symbolic link.');
  }
  const entries = await readdir(slides, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.isSymbolicLink()) throw new Error(`Refusing symbolic-link entry: ${path.join(slides, entry.name)}`);
  }
  const names = entries.filter(entry => entry.isDirectory()).map(entry => entry.name).sort();
  if (!names.length) throw new Error(`No slide decks found in ${slides}. Create a deck with npm run slides:create first.`);

  const outputs = [];
  for (const name of names) {
    const directory = path.join(slides, name);
    try {
      const script = path.join(directory, 'bundle.mjs');
      const entry = await lstat(script);
      if (!entry.isFile() || entry.isSymbolicLink()) throw new Error('bundle.mjs must be a regular file.');
      const module = await import(pathToFileURL(script).href);
      const operation = check ? 'checkBundle' : 'bundleDeck';
      if (typeof module[operation] !== 'function') throw new Error(`bundle.mjs must export a ${operation} function.`);
      const output = await module[operation]();
      const expected = path.join(root, 'docs/slides', `${name}.html`);
      if (output !== expected) throw new Error(`${operation} must return ${expected}.`);
      const file = await lstat(output);
      if (!file.isFile() || file.size === 0) throw new Error(`Expected a nonempty HTML file at ${output}.`);
      outputs.push(output);
    } catch (error) {
      throw new Error(`Failed to bundle slides/${name}: ${error.message}`, { cause: error });
    }
  }
  if (check) {
    const generated = await readdir(path.join(root, 'docs/slides'), { withFileTypes: true });
    for (const entry of generated.filter(entry => entry.name.endsWith('.html'))) {
      if (!entry.isFile() || !names.includes(entry.name.slice(0, -5))) {
        throw new Error(`Unexpected generated slide bundle: ${entry.name}. Every HTML bundle must have a corresponding source deck.`);
      }
    }
  }
  return outputs;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = process.argv.slice(2);
    if (args.length === 1 && args[0] === '--help') {
      console.log('Usage: npm run slides:build | npm run slides:check\nBundles every deck under slides/ into docs/slides/<deck-name>.html. --check verifies committed HTML without rewriting it. Does not install, serve or publish.');
    } else {
      const check = args.length === 1 && args[0] === '--check';
      if (args.length && !check) throw new Error('Only --check or --help is supported.');
      const outputs = await buildAllDecks({ check });
      for (const output of outputs) console.log(`${check ? 'Checked' : 'Built'} ${output}`);
      console.log(`${check ? 'Checked' : 'Bundled'} ${outputs.length} deck(s).`);
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
