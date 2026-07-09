// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Unit tests for the pure runtime-probe helpers. Runs under `node --test`
// without a browser or node_modules (the module under test never imports
// Playwright).

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildProbeResults,
  buildResultsFromEntry,
  computeTrapFromSequence,
  loadProbeCriteriaMap,
  redactUrl,
  tagToCriterion,
} from '../../../scripts/runtime_a11y/runner/_core.mjs';

test('tagToCriterion maps wcag tags to dotted criteria', () => {
  assert.equal(tagToCriterion('wcag412'), '4.1.2');
  assert.equal(tagToCriterion('wcag131'), '1.3.1');
  assert.equal(tagToCriterion('wcag1410'), '1.4.10');
  assert.equal(tagToCriterion('wcag2a'), null);
  assert.equal(tagToCriterion('best-practice'), null);
  assert.equal(tagToCriterion(''), null);
});

test('redactUrl removes query strings and secret params', () => {
  assert.equal(redactUrl('https://x.test/a/b'), 'https://x.test/a/b');
  assert.equal(redactUrl('https://x.test/a?token=abc'), 'https://x.test/a?[redacted]');
  assert.equal(redactUrl(''), '');
  assert.match(redactUrl('not-a-url?token=secret'), /\[redacted\]/);
});

const entry = {
  probeId: 'probe-sample',
  decides: [
    { criterionId: '1.1.1', framework: 'wcag-22', states: ['default'] },
    { criterionId: '2.5.8', framework: 'wcag-22', states: ['default'] },
  ],
  informs: [{ criterionId: '4.1.2', framework: 'wcag-22', states: ['default'] }],
};

test('buildResultsFromEntry applies decide/inform defaults', () => {
  const results = buildResultsFromEntry({
    entry,
    probeId: 'probe-sample',
    surfaceId: 'home',
    state: 'default',
    evidence: 'https://x.test/',
    decideStatus: 'fail',
    informStatus: 'candidate',
  });
  const byId = Object.fromEntries(results.map((r) => [r.criterionId, r]));
  assert.equal(byId['1.1.1'].status, 'fail');
  assert.equal(byId['2.5.8'].status, 'fail');
  assert.equal(byId['2.5.8'].severity, 'moderate');
  assert.equal(byId['4.1.2'].status, 'candidate');
  assert.equal(byId['1.1.1'].method, 'runtime-automation');
});

test('buildResultsFromEntry honors per-criterion status override', () => {
  const results = buildResultsFromEntry({
    entry,
    probeId: 'probe-sample',
    surfaceId: 'home',
    state: 'default',
    evidence: 'e',
    decideStatus: 'fail',
    statusByCriterion: { '1.1.1': 'pass' },
  });
  const byId = Object.fromEntries(results.map((r) => [r.criterionId, r]));
  assert.equal(byId['1.1.1'].status, 'pass');
  assert.equal(byId['2.5.8'].status, 'fail');
});

test('buildResultsFromEntry filters criteria by state', () => {
  const stateEntry = {
    decides: [{ criterionId: '2.4.7', framework: 'wcag-22', states: ['focus'] }],
    informs: [],
  };
  assert.equal(
    buildResultsFromEntry({ entry: stateEntry, probeId: 'p', surfaceId: 's', state: 'default', evidence: 'e' }).length,
    0,
  );
  assert.equal(
    buildResultsFromEntry({ entry: stateEntry, probeId: 'p', surfaceId: 's', state: 'focus', evidence: 'e' }).length,
    1,
  );
});

test('computeTrapFromSequence flags only a genuine 3-press stall', () => {
  assert.deepEqual(computeTrapFromSequence(['0', '1', '2', '3']), { trapped: false, reachableCount: 4 });
  assert.equal(computeTrapFromSequence(['5', '5', '5']).trapped, true);
  assert.equal(computeTrapFromSequence(['5', '5']).trapped, false);
  assert.equal(computeTrapFromSequence(['none', 'none', 'none']).trapped, false);
  assert.equal(computeTrapFromSequence(['1', '2', '2', '2', '3']).trapped, true);
  assert.equal(computeTrapFromSequence([]).reachableCount, 0);
});

test('loadProbeCriteriaMap reads real probe entries', async () => {
  const axe = await loadProbeCriteriaMap('probe-axe');
  assert.equal(axe.probeId, 'probe-axe');
  assert.ok(Array.isArray(axe.decides) && axe.decides.length > 0);
  await assert.rejects(() => loadProbeCriteriaMap('probe-does-not-exist'), /Unknown probe id/);
});

test('buildProbeResults resolves criteria from the real map', async () => {
  const results = await buildProbeResults({
    probeId: 'probe-axe',
    surfaceId: 'home',
    state: 'default',
    evidence: 'https://x.test/',
    decideStatus: 'pass',
    statusByCriterion: { '1.3.1': 'fail' },
  });
  const byId = Object.fromEntries(results.map((r) => [r.criterionId, r]));
  assert.equal(byId['1.3.1'].status, 'fail');
  assert.equal(byId['2.4.1'].status, 'pass');
});
