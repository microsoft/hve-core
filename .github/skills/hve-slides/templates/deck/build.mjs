// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
import { readFile, writeFile, copyFile, mkdir, access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(fileURLToPath(import.meta.url));
export const sourceFiles = ['index.html', 'theme.css', 'components.css', 'content.js', 'components.js', 'deck.js'];
const vendor = [['dist/reveal.css', 'reveal.css'], ['dist/reveal.js', 'reveal.js'], ['LICENSE', 'reveal-LICENSE.txt']];

export function configScript(config) {
  for (const key of ['title', 'description', 'sourceNote']) {
    if (typeof config?.[key] !== 'string' || !config[key].trim()) throw new Error(`deck.json requires a nonempty ${key}.`);
  }
  const json = JSON.stringify(config).replaceAll('<', '\\u003c').replaceAll('\u2028', '\\u2028').replaceAll('\u2029', '\\u2029');
  return `// Generated from deck.json.\nglobalThis.DeckConfig = ${json};\n`;
}

export async function buildDeck() {
  const config = configScript(JSON.parse(await readFile(path.join(root, 'deck.json'), 'utf8')));
  for (const [source] of vendor) {
    try {
      await access(path.join(root, 'node_modules/reveal.js', source));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      throw new Error(`reveal.js is missing. Run npm ci in ${root} before building.`, { cause: error });
    }
  }
  const output = path.join(root, 'dist');
  await mkdir(path.join(output, 'vendor'), { recursive: true });
  for (const file of sourceFiles) await copyFile(path.join(root, file), path.join(output, file));
  for (const [source, destination] of vendor) await copyFile(path.join(root, 'node_modules/reveal.js', source), path.join(output, 'vendor', destination));
  await writeFile(path.join(output, 'config.js'), config, 'utf8');
  return output;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(`Built ${path.join(await buildDeck(), 'index.html')}. Open this file in a browser.`);
}
