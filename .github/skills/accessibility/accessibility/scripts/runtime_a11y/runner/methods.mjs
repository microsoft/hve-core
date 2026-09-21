// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { readFile } from 'node:fs/promises';

const METHODS_URL = new URL('../methods.json', import.meta.url);

let cached = null;

// Read the shared evidence-method vocabulary. The Python matrix engine loads the
// same file, so a method name written here cannot drift from the ranks and
// human-evidence flags the matrix applies during merge and rendering.
export async function loadMethodVocabulary() {
  if (!cached) {
    const payload = JSON.parse(await readFile(METHODS_URL, 'utf8'));
    cached = new Map(payload.methods.map((entry) => [entry.name, entry]));
  }
  return cached;
}

export async function isKnownMethod(name) {
  return (await loadMethodVocabulary()).has(name);
}

// Reject a method the vocabulary does not define rather than emitting a label
// the matrix would silently rank zero.
export async function assertKnownMethod(name) {
  if (!(await isKnownMethod(name))) {
    throw new Error(`Unknown evidence method: ${name}`);
  }
  return name;
}
