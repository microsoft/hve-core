// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { runProbe as runAriaTreeProbe } from '../../../scripts/runtime_a11y/runner/probe-aria-tree.mjs';
import { runProbe as runAxeProbe } from '../../../scripts/runtime_a11y/runner/probe-axe.mjs';
import { runProbe as runContrastProbe } from '../../../scripts/runtime_a11y/runner/probe-contrast.mjs';
import { runProbe as runForcedColorsProbe } from '../../../scripts/runtime_a11y/runner/probe-forced-colors.mjs';

function createRunWithPage(page = {}) {
  return async (callback) => callback({
    page,
    state: 'default',
    surface: { id: 'home' },
    targetUrl: 'https://example.test/',
  });
}

function statusesByCriterion(payload) {
  return Object.fromEntries(
    payload.results.map((result) => [result.criterionId, result.status]),
  );
}

test('probe-contrast wrapper keeps unavailable axe evidence non-authoritative', async () => {
  const payload = await runContrastProbe({
    emitProbeResult() {},
    injectAxe: async () => null,
    runProbeWithPage: createRunWithPage({
      evaluate: async () => ({
        backgroundColor: 'rgb(255, 255, 255)',
        color: 'rgb(0, 0, 0)',
        fontSize: '16px',
      }),
    }),
  });

  assert.equal(statusesByCriterion(payload)['1.4.3'], 'candidate');
});

test('probe-axe wrapper distinguishes unavailable and implicated criterion evidence', async () => {
  const page = {
    evaluate: async () => ({ focusables: 1, landmarks: 1, title: 'Example' }),
  };
  const unavailable = await runAxeProbe({
    emitProbeResult() {},
    injectAxe: async () => null,
    runProbeWithPage: createRunWithPage(page),
  });
  assert.deepEqual(
    Object.fromEntries(
      Object.entries(statusesByCriterion(unavailable))
        .filter(([criterion]) => ['1.3.1', '2.4.1', '2.4.2', '3.1.1'].includes(criterion)),
    ),
    {
      '1.3.1': 'candidate',
      '2.4.1': 'candidate',
      '2.4.2': 'candidate',
      '3.1.1': 'candidate',
    },
  );

  const violated = await runAxeProbe({
    emitProbeResult() {},
    injectAxe: async () => ({
      violations: [{ id: 'landmark-unique', nodes: [{}], tags: ['wcag131'] }],
    }),
    runProbeWithPage: createRunWithPage(page),
  });
  const statuses = statusesByCriterion(violated);
  assert.equal(statuses['1.3.1'], 'fail');
  assert.equal(statuses['2.4.1'], 'pass');
});

test('probe-forced-colors wrapper applies the explicit keyword predicate', async () => {
  const baseStyle = {
    backgroundImage: 'url("focus.svg")',
    outlineColor: 'rgb(0, 0, 0)',
    outlineStyle: 'none',
    outlineWidth: '0px',
  };
  const payload = await runForcedColorsProbe({
    captureForcedColorsSnapshot: async () => ({
      activeElement: 'BODY',
      colorScheme: 'light',
      focusableCount: 1,
      forcedColors: true,
      indicatorStyles: [{ ...baseStyle, forcedColorAdjust: 'none' }],
    }),
    emitProbeResult() {},
    runProbeWithPage: createRunWithPage(),
  });

  assert.equal(statusesByCriterion(payload)['1.4.11'], 'fail');
});

test('probe-aria-tree wrapper fails a native nameless control without explicit DOM roles', async () => {
  const payload = await runAriaTreeProbe({
    emitProbeResult() {},
    runProbeWithPage: createRunWithPage({
      evaluate: async () => ({ accessibleNameCount: 0, labels: 0, roles: 0 }),
    }),
    snapshotAccessibilityTree: async () => ({
      source: 'cdp',
      nodes: [
        {
          childIds: ['2'],
          ignored: false,
          name: { type: 'computedString', value: 'Example' },
          nodeId: '1',
          role: { type: 'internalRole', value: 'RootWebArea' },
        },
        {
          childIds: [],
          ignored: false,
          name: { type: 'computedString', value: '' },
          nodeId: '2',
          role: { type: 'role', value: 'button' },
        },
      ],
    }),
  });

  const statuses = statusesByCriterion(payload);
  assert.equal(statuses['4.1.2'], 'fail');
  assert.equal(statuses['1.3.1'], 'fail');
});

test('probe-aria-tree wrapper keeps unavailable accessibility evidence non-authoritative', async () => {
  const payload = await runAriaTreeProbe({
    emitProbeResult() {},
    runProbeWithPage: createRunWithPage({
      evaluate: async () => ({ accessibleNameCount: 0, labels: 0, roles: 0 }),
    }),
    snapshotAccessibilityTree: async () => null,
  });

  const statuses = statusesByCriterion(payload);
  assert.equal(statuses['4.1.2'], 'candidate');
  assert.equal(statuses['1.3.1'], 'candidate');
});
