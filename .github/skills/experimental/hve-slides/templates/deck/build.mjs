// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { constants } from 'node:fs';
import { lstat, open, mkdir, mkdtemp, rename, unlink, rmdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(fileURLToPath(import.meta.url));
export const sourceFiles = ['deck.json', 'index.html', 'theme.css', 'components.css', 'content.js', 'components.js', 'deck.js'];
const vendor = [['dist/reveal.css', 'reveal.css'], ['dist/reveal.js', 'reveal.js'], ['LICENSE', 'reveal-LICENSE.txt']];

// Every existing ancestor must be a real directory, including Windows junctions.
export async function inspectPath(value, kind, { allowMissing = false } = {}) {
  const target = path.resolve(value);
  const parsed = path.parse(target);
  const parts = target.slice(parsed.root.length).split(path.sep).filter(Boolean);
  let current = parsed.root;
  for (let index = 0; index < parts.length; index += 1) {
    current = path.join(current, parts[index]);
    let entry;
    try {
      entry = await lstat(current);
    } catch (error) {
      if (allowMissing && error.code === 'ENOENT') return target;
      throw error;
    }
    const directory = index < parts.length - 1 || kind === 'directory';
    if (entry.isSymbolicLink() || (directory ? !entry.isDirectory() : !entry.isFile())) {
      throw new Error(`Expected a real ${directory ? 'directory' : 'regular file'}: ${current}`);
    }
  }
  if (!parts.length && kind !== 'directory') throw new Error('A file path is required.');
  return target;
}

export async function readRegularFile(file) {
  await inspectPath(file, 'file');
  const handle = await open(file, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  try {
    const opened = await handle.stat({ bigint: true });
    const entry = await lstat(file, { bigint: true });
    if (!opened.isFile() || !entry.isFile() || opened.dev !== entry.dev || opened.ino !== entry.ino) {
      throw new Error(`Source must be a stable regular file: ${file}`);
    }
    return await handle.readFile('utf8');
  } finally {
    await handle.close();
  }
}

export async function writeOutput(file, content) {
  const destination = await inspectPath(file, 'file', { allowMissing: true });
  const parent = path.dirname(destination);
  await mkdir(parent, { recursive: true });
  await inspectPath(parent, 'directory');
  const staging = await mkdtemp(path.join(parent, '.html-slide-'));
  const stagedFile = path.join(staging, 'output');
  try {
    const handle = await open(stagedFile, 'wx', 0o600);
    try {
      await handle.writeFile(content, 'utf8');
    } finally {
      await handle.close();
    }
    await inspectPath(destination, 'file', { allowMissing: true });
    await rename(stagedFile, destination);
  } finally {
    await unlink(stagedFile).catch(error => { if (error.code !== 'ENOENT') throw error; });
    await rmdir(staging);
  }
}

export function configScript(config) {
  for (const key of ['title', 'description', 'sourceNote']) {
    if (typeof config?.[key] !== 'string' || !config[key].trim()) throw new Error(`deck.json requires a nonempty ${key}.`);
  }
  const json = JSON.stringify(config).replaceAll('<', '\\u003c').replaceAll('\u2028', '\\u2028').replaceAll('\u2029', '\\u2029');
  return `// Generated from deck.json.\nglobalThis.DeckConfig = ${json};\n`;
}

export async function buildDeck({ deckDir = root, output = path.join(deckDir, 'dist'), dependencyRoot = deckDir } = {}) {
  const sourceRoot = await inspectPath(deckDir, 'directory');
  const dependencies = await inspectPath(dependencyRoot, 'directory');
  const files = new Map();
  for (const file of sourceFiles) files.set(file, await readRegularFile(path.join(sourceRoot, file)));
  const config = configScript(JSON.parse(files.get('deck.json')));
  for (const [source, name] of vendor) {
    try {
      files.set(`vendor/${name}`,
        await readRegularFile(path.join(dependencies, 'node_modules/reveal.js', source)));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      throw new Error(`reveal.js is missing. Run npm ci in ${dependencies} before building.`, { cause: error });
    }
  }
  const destination = await inspectPath(output, 'directory', { allowMissing: true });
  if (destination === sourceRoot || destination === dependencies) throw new Error('Build output must not replace source or dependencies.');
  files.set('config.js', config);
  for (const [file, content] of files) await writeOutput(path.join(destination, file), content);
  return destination;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(`Built ${path.join(await buildDeck(), 'index.html')}. Open this file in a browser.`);
}
