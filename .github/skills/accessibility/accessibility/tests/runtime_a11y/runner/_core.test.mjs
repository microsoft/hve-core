// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Unit tests for the pure runtime-probe helpers. Runs under `node --test`
// without a browser or node_modules (the module under test never imports
// Playwright).

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  ariaTreeNameEvaluation,
  axeProbeEvaluation,
  buildProbeResults,
  buildResultsFromEntry,
  computeTrapFromSequence,
  contrastProbeEvaluation,
  findNamelessControls,
  isForcedColorsIndicatorRisk,
  liveRegionStatus,
  loadProbeCriteriaMap,
  redactUrl,
  tagToCriterion,
  virtualSrNameRoleStatus,
} from '../../../scripts/runtime_a11y/runner/_core.mjs';

test('tagToCriterion maps wcag tags to dotted criteria', () => {
  assert.equal(tagToCriterion('wcag412'), '4.1.2');
  assert.equal(tagToCriterion('wcag131'), '1.3.1');
  assert.equal(tagToCriterion('wcag1410'), '1.4.10');
  assert.equal(tagToCriterion('wcag2a'), null);
  assert.equal(tagToCriterion('best-practice'), null);
  assert.equal(tagToCriterion(''), null);
});

test('contrastProbeEvaluation distinguishes unavailable, clean, and violated analysis', () => {
  assert.deepEqual(
    contrastProbeEvaluation(null),
    { status: 'candidate', violations: [], nodeCount: 0 },
  );
  assert.equal(contrastProbeEvaluation({ violations: [] }).status, 'pass');
  assert.deepEqual(
    contrastProbeEvaluation({
      violations: [
        { id: 'color-contrast', nodes: [{ target: ['main'] }, { target: ['footer'] }] },
        { id: 'landmark-one-main', nodes: [{ target: ['body'] }] },
      ],
    }),
    {
      status: 'fail',
      violations: [
        { id: 'color-contrast', nodes: [{ target: ['main'] }, { target: ['footer'] }] },
      ],
      nodeCount: 2,
    },
  );
});

test('axeProbeEvaluation makes unavailable criteria candidates and fails only implicated criteria', () => {
  const criteria = ['1.3.1', '2.4.1'];
  const unavailable = axeProbeEvaluation(null, criteria);
  assert.equal(unavailable.available, false);
  assert.deepEqual(unavailable.statusByCriterion, {
    '1.3.1': 'candidate',
    '2.4.1': 'candidate',
  });

  const clean = axeProbeEvaluation({ violations: [] }, criteria);
  assert.deepEqual(clean.statusByCriterion, { '1.3.1': 'pass', '2.4.1': 'pass' });

  const violated = axeProbeEvaluation({
    violations: [{ id: 'landmark-unique', tags: ['wcag131'], nodes: [{}] }],
  }, criteria);
  assert.deepEqual(violated.statusByCriterion, { '1.3.1': 'fail', '2.4.1': 'pass' });
  assert.deepEqual([...violated.criterionToRules.get('1.3.1')], ['landmark-unique']);
});

test('isForcedColorsIndicatorRisk requires the explicit none keyword and both visual risks', () => {
  const riskyStyle = {
    backgroundImage: 'url("focus.svg")',
    forcedColorAdjust: 'none',
    outlineColor: 'rgb(0, 0, 0)',
    outlineStyle: 'none',
    outlineWidth: '0px',
  };

  assert.equal(isForcedColorsIndicatorRisk(riskyStyle), true);
  assert.equal(isForcedColorsIndicatorRisk({ ...riskyStyle, forcedColorAdjust: 'auto' }), false);
  assert.equal(isForcedColorsIndicatorRisk({ ...riskyStyle, outlineStyle: 'solid', outlineWidth: '2px' }), false);
  assert.equal(isForcedColorsIndicatorRisk({ ...riskyStyle, backgroundImage: 'none' }), false);
});

test('ariaTreeNameEvaluation consumes AXValue fields and childIds without requiring DOM roles', () => {
  const tree = {
    source: 'cdp',
    nodes: [
      {
        nodeId: '1',
        role: { type: 'internalRole', value: 'RootWebArea' },
        name: { type: 'computedString', value: 'Example' },
        ignored: false,
        childIds: ['2', '3', '4'],
      },
      {
        nodeId: '2',
        role: { type: 'role', value: 'button' },
        name: { type: 'computedString', value: '' },
        ignored: false,
        childIds: [],
      },
      {
        nodeId: '3',
        role: { type: 'role', value: 'heading' },
        name: { type: 'computedString', value: '' },
        ignored: false,
        childIds: [],
      },
      {
        nodeId: '4',
        role: { type: 'role', value: 'link' },
        name: { type: 'computedString', value: '' },
        ignored: true,
        childIds: [],
      },
    ],
  };

  assert.deepEqual(ariaTreeNameEvaluation(tree), {
    status: 'fail',
    source: 'cdp',
    nodeCount: 4,
    namelessRoles: ['button'],
  });
  tree.nodes[1].name.value = 'Continue';
  assert.equal(ariaTreeNameEvaluation(tree).status, 'pass');
});

test('ariaTreeNameEvaluation keeps missing, empty, and fictional CDP evidence non-authoritative', () => {
  assert.equal(ariaTreeNameEvaluation(null).status, 'candidate');
  assert.equal(ariaTreeNameEvaluation({ source: 'cdp', nodes: [] }).status, 'candidate');
  assert.equal(
    ariaTreeNameEvaluation({
      source: 'cdp',
      nodes: [{ nodeId: 1, role: 'button', name: 'Continue', children: [] }],
    }).status,
    'candidate',
  );
  assert.equal(
    ariaTreeNameEvaluation({
      role: 'rootWebArea',
      name: 'Example',
      children: [{ role: 'button', name: '' }],
    }).status,
    'fail',
  );
});

test('redactUrl removes query strings and secret params', () => {
  assert.equal(redactUrl('https://x.test/a/b'), 'https://x.test/a/b');
  assert.equal(redactUrl('https://x.test/a?token=abc'), 'https://x.test/a?[redacted]');
  assert.equal(redactUrl(''), '');
  assert.match(redactUrl('not-a-url?token=secret'), /\[redacted\]/);
});

test('findNamelessControls flags interactive roles with no accessible name', () => {
  const phrases = [
    'document',
    'heading, Title, level 1',
    'button, Clear search',
    'button',
    'link, Docs',
    'link',
    'end of button, Clear search',
    'end of button',
    'table',
    'combobox',
    'columnheader, Name',
  ];

  const nameless = findNamelessControls(phrases);

  assert.deepEqual(nameless, ['button', 'link', 'combobox']);
});

test('findNamelessControls returns empty for named controls and non-lists', () => {
  assert.deepEqual(findNamelessControls(['button, Save', 'heading, X, level 2']), []);
  assert.deepEqual(findNamelessControls([]), []);
  assert.deepEqual(findNamelessControls(null), []);
  assert.deepEqual(findNamelessControls([42, 'button']), ['button']);
});

test('virtualSrNameRoleStatus maps snapshots to verdicts', () => {
  assert.equal(virtualSrNameRoleStatus({ ran: true, namelessCount: 0 }), 'pass');
  assert.equal(virtualSrNameRoleStatus({ ran: true, namelessCount: 2 }), 'fail');
  assert.equal(virtualSrNameRoleStatus({ ran: false }), 'candidate');
  assert.equal(virtualSrNameRoleStatus(null), 'candidate');
  assert.equal(virtualSrNameRoleStatus({ ran: true }), 'pass');
});

test('liveRegionStatus applies the method-adequacy rule per state', () => {
  // Non-expecting states never fail on a missing status message.
  assert.equal(liveRegionStatus({ regionsNow: 0, fired: false }, 'default'), 'pass');
  // Expecting states: fired -> pass, silent -> partial, absent -> fail.
  assert.equal(liveRegionStatus({ regionsNow: 1, fired: true }, 'open'), 'pass');
  assert.equal(liveRegionStatus({ regionsNow: 1, fired: false }, 'open'), 'partial');
  assert.equal(liveRegionStatus({ regionsNow: 0, fired: false }, 'error'), 'fail');
  assert.equal(liveRegionStatus(null, 'open'), 'fail');
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
