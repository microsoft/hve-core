// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Real-browser contract tests for probe-forced-colors. The smoke lane is
// CI-owned because it launches system Chrome; run it with
// `npm run ci:test:a11y:smoke` after installing the skill-local dependencies.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { buildForcedColorsProbePayload, captureForcedColorsSnapshot } from '../../../../scripts/runtime_a11y/runner/probe-forced-colors.mjs';
import { launchChrome } from '../../../../scripts/runtime_a11y/runner/_shared.mjs';

let browser;

before(async () => {
  browser = await launchChrome();
});

after(async () => {
  await browser?.close();
});

test('probe-forced-colors smoke: real computed none keyword fails the production verdict path', async () => {
  const context = await browser.newContext({ forcedColors: 'active' });
  const page = await context.newPage();
  try {
    await page.setContent(`
      <style>
        button {
          background-image: linear-gradient(red, red);
          forced-color-adjust: none;
          outline: 0;
        }
      </style>
      <button>Continue</button>
    `);
    const snapshot = await captureForcedColorsSnapshot(page);
    const payload = await buildForcedColorsProbePayload({
      snapshot,
      state: 'forced-colors',
      surfaceId: 'fixture',
      targetUrl: 'data:text/html,forced-colors',
    });

    assert.equal(snapshot.indicatorStyles[0].forcedColorAdjust, 'none');
    assert.equal(payload.results.find((result) => result.criterionId === '1.4.11')?.status, 'fail');
  } finally {
    await context.close();
  }
});

test('probe-forced-colors smoke: real computed auto keyword passes the production verdict path', async () => {
  const context = await browser.newContext({ forcedColors: 'active' });
  const page = await context.newPage();
  try {
    await page.setContent(`
      <style>
        button {
          background-image: linear-gradient(red, red);
          forced-color-adjust: auto;
          outline: 0;
        }
      </style>
      <button>Continue</button>
    `);
    const snapshot = await captureForcedColorsSnapshot(page);
    const payload = await buildForcedColorsProbePayload({
      snapshot,
      state: 'forced-colors',
      surfaceId: 'fixture',
      targetUrl: 'data:text/html,forced-colors',
    });

    assert.equal(snapshot.indicatorStyles[0].forcedColorAdjust, 'auto');
    assert.equal(payload.results.find((result) => result.criterionId === '1.4.11')?.status, 'pass');
  } finally {
    await context.close();
  }
});
