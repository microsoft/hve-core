// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
import { copyFile, mkdir, access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(fileURLToPath(import.meta.url));
const files = ['index.html', 'theme.css', 'components.css', 'content.js', 'components.js', 'deck.js'];
const vendor = [
  ['dist/reveal.css', 'reveal.css'],
  ['dist/reveal.js', 'reveal.js'],
  ['LICENSE', 'reveal-LICENSE.txt']
];
export async function buildDeck() {
  for (const [source] of vendor) {
    try {
      await access(path.join(root, 'node_modules/reveal.js', source));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      throw new Error('reveal.js is missing. Run npm ci in slides/hve-updates/ before building the deck.', { cause: error });
    }
  }
  const output = path.join(root, 'dist');
  await mkdir(path.join(output, 'vendor'), { recursive: true });
  for (const file of files) {
    await copyFile(path.join(root, file), path.join(output, file));
  }
  for (const [source, destination] of vendor) {
    await copyFile(path.join(root, 'node_modules/reveal.js', source), path.join(output, 'vendor', destination));
  }
  return output;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await buildDeck();
  console.log('Built slides/hve-updates/dist/index.html. Open this file in a browser; no server is required.');
}
