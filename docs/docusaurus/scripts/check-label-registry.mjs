// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
//
// COGA-1 (WCAG 3.2.4 Consistent Identification) guard.
//
// The site's user-facing labels are centralized in src/data/labelRegistry.ts so
// the same concept renders under one consistent label. This check enforces two
// invariants on the drift-prone consumer files, which together prevent a concept
// from silently acquiring a second, divergent label:
//   1. The consumer imports from the registry.
//   2. The consumer never hardcodes a concept-identity label field (title or
//      supertitle) as a string literal — those values must reference the
//      registry. Merely importing the registry is not enough, because a file can
//      import it and still hardcode a divergent label for the same concept.
//      Freeform link text (`label`) is intentionally out of scope: it names a
//      destination rather than re-identifying a registry concept.

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

// Object keys whose values re-identify a registry concept to users. A value for
// one of these keys must come from labelRegistry, never a bare string literal.
// Type/interface annotations (e.g. `title: string`) and non-concept keys (name
// slugs, maturity enums, descriptions, freeform link `label` text) are excluded.
const labelKeys = ['title', 'supertitle'];
const hardcodedLabel = new RegExp(
  String.raw`(?:^|[\s,{(])(${labelKeys.join('|')})\s*:\s*(['"\`])`,
);

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
    continue;
  }
  const lines = contents.split(/\r?\n/);
  lines.forEach((line, index) => {
    const match = hardcodedLabel.exec(line);
    if (match) {
      failures.push(
        `${relative}:${index + 1}: '${match[1]}' is assigned a hardcoded string literal; ` +
          'source it from src/data/labelRegistry.ts so the concept keeps one consistent label',
      );
    }
  });
}

if (failures.length > 0) {
  console.error('Label-registry consistency check failed (COGA-1 / WCAG 3.2.4):');
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  process.exit(1);
}

console.log(
  `Label-registry consistency check passed (${consumers.length} consumers import the registry and hardcode no title/supertitle values).`,
);
