// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import { validateScreenReaderCommand } from '../../../scripts/runtime_a11y/runner/drivers/command-contract.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const schemaPath = resolve(__dirname, '../../../scripts/runtime_a11y/config-schema.json');

test('validateScreenReaderCommand accepts Control+K for a real key command', () => {
  const result = validateScreenReaderCommand({ kind: 'key', value: 'Control+K' });

  assert.equal(result, null);
});

test('config schema command kinds and contract validation stay in parity', () => {
  const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));
  const schemaKinds = new Set(schema?.$defs?.screenReaderAction?.properties?.kind?.enum || []);
  const representativePayloads = new Map([
    ['command', { kind: 'command', value: 'perform' }],
    ['pause', { kind: 'pause', durationMs: 1 }],
    ['keyboard', { kind: 'keyboard', value: 'ArrowDown' }],
    ['key', { kind: 'key', value: 'Control+K' }],
    ['perform', { kind: 'perform', value: 'performDefaultActionForItem' }],
    ['type', { kind: 'type', value: 'agent' }],
    ['waitFor', { kind: 'waitFor', value: '#search-results-status[role="status"]' }],
  ]);

  for (const kind of schemaKinds) {
    const payload = representativePayloads.get(kind);
    assert.ok(payload, `Expected a representative payload for ${kind}`);
    assert.equal(validateScreenReaderCommand(payload), null, `Expected ${kind} to be accepted by validateScreenReaderCommand`);
  }

  const acceptedKinds = new Set(
    [...representativePayloads.keys()].filter((kind) => validateScreenReaderCommand(representativePayloads.get(kind)) === null),
  );

  for (const kind of acceptedKinds) {
    assert.ok(schemaKinds.has(kind), `Expected ${kind} to appear in the config-schema enum`);
  }
});

test('validateScreenReaderCommand restricts typed text to printable characters', () => {
  // Typed text reaches OS-level keystroke synthesis, so a control character
  // would be delivered as a command rather than as text.
  assert.equal(validateScreenReaderCommand({ kind: 'type', value: 'accessibility' }), null);
  assert.equal(validateScreenReaderCommand({ kind: 'type', value: 'search terms 42!' }), null);

  for (const value of ['line\nbreak', 'tab\there', 'null\u0000byte', 'esc\u001b[A']) {
    assert.match(
      String(validateScreenReaderCommand({ kind: 'type', value })),
      /printable characters/,
      `Expected ${JSON.stringify(value)} to be rejected`,
    );
  }
});
