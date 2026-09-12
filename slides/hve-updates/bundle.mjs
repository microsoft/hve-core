// Copyright (c) Microsoft Corporation. Licensed under the MIT License.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDeck } from './build.mjs';
import { bundleDeck as bundleDirectory, createStandaloneHtml } from '../../.github/skills/hve-slides/templates/deck/bundle.mjs';

export { createStandaloneHtml };

export function bundleDeck() {
  return bundleDirectory({ build: buildDeck });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(`Created ${await bundleDeck()}\nShare this one file. Download it and open it in a browser; no sibling files or server are needed.`);
}
