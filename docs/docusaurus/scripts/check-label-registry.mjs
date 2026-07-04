// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
//
// COGA-1 (WCAG 3.2.4 Consistent Identification) guard.
//
// The site's user-facing labels are centralized in src/data/labelRegistry.ts so
// the same concept renders under one consistent label. This check fails when a
// drift-prone consumer file stops sourcing its labels from the registry, which
// is the regression that reintroduces inconsistent labels for the same concept.

import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(currentDir, '..');

// Files that must source their user-facing labels from the label registry.
const consumers = [
  'src/data/collectionCards.ts',
  'src/data/hubCards.tsx',
  'src/pages/index.tsx',
];

const failures = [];
for (const relative of consumers) {
  const absolute = path.join(root, relative);
  if (!fs.existsSync(absolute)) {
    failures.push(`${relative}: expected consumer file is missing`);
    continue;
  }
  const contents = fs.readFileSync(absolute, 'utf8');
  if (!contents.includes('labelRegistry')) {
    failures.push(
      `${relative}: does not reference labelRegistry (labels must come from src/data/labelRegistry.ts)`,
    );
  }
}

if (failures.length > 0) {
  console.error('Label-registry consistency check failed (COGA-1 / WCAG 3.2.4):');
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  process.exit(1);
}

console.log(`Label-registry consistency check passed (${consumers.length} consumers verified).`);
