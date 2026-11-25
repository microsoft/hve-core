// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import test from 'node:test';

import { buildResultsFromEntry } from '../../../scripts/runtime_a11y/runner/_core.mjs';
import {
  assertKnownMethod,
  isKnownMethod,
  loadMethodVocabulary,
} from '../../../scripts/runtime_a11y/runner/methods.mjs';
import { resolveObservedMethod } from '../../../scripts/runtime_a11y/runner/probe-real-sr.mjs';

const ENTRY = {
  probeId: 'probe-real-sr',
  decides: [{ criterionId: '4.1.2', framework: 'wcag-22', states: ['default'] }],
  informs: [],
};

test('vocabulary defines the seven shared methods with ranks', async () => {
  const vocabulary = await loadMethodVocabulary();
  assert.equal(vocabulary.size, 7);
  assert.equal(vocabulary.get('screen-reader').rank, 65);
  assert.equal(vocabulary.get('runtime-automation').rank, 50);
});

test('unknown method is rejected rather than silently accepted', async () => {
  assert.equal(await isKnownMethod('vibes-based'), false);
  await assert.rejects(() => assertKnownMethod('vibes-based'));
});

test('results default to runtime automation when no method is declared', () => {
  const [result] = buildResultsFromEntry({
    entry: ENTRY,
    probeId: 'probe-real-sr',
    surfaceId: 'home',
    state: 'default',
    evidence: 'http://127.0.0.1:3000/',
  });
  assert.equal(result.method, 'runtime-automation');
});

test('a declared method reaches the emitted result', () => {
  const [result] = buildResultsFromEntry({
    entry: ENTRY,
    probeId: 'probe-real-sr',
    surfaceId: 'home',
    state: 'default',
    evidence: 'http://127.0.0.1:3000/',
    method: 'screen-reader',
  });
  assert.equal(result.method, 'screen-reader');
});

test('only a real assistive technology run claims screen-reader evidence', () => {
  assert.equal(
    resolveObservedMethod({ ran: true, supported: true, driver: 'nvda' }),
    'screen-reader',
  );
  assert.equal(
    resolveObservedMethod({ ran: true, supported: true, driver: 'synthetic' }),
    'runtime-automation',
  );
  assert.equal(
    resolveObservedMethod({ ran: false, supported: true, driver: 'nvda' }),
    'runtime-automation',
  );
  assert.equal(resolveObservedMethod(null), 'runtime-automation');
});
