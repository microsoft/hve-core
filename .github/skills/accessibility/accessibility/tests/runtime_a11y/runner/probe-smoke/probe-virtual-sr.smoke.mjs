// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Browser smoke tests for probe-virtual-sr. These launch system Chrome and run
// the identical capture path the probe uses (captureVirtualSr) against inline
// fixtures, proving the DOM -> announced-phrase-log -> verdict pipeline. They
// are named *.smoke.mjs (not *.test.mjs) so the default browserless
// `node --test` run does not pick them up; run them with
// `npm run ci:test:a11y:smoke`.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { virtualSrNameRoleStatus } from '../../../../scripts/runtime_a11y/runner/_core.mjs';
import { captureVirtualSr, launchChrome } from '../../../../scripts/runtime_a11y/runner/_shared.mjs';
import { CASES } from './virtual-sr.cases.mjs';

let browser;

before(async () => {
  browser = await launchChrome();
});

after(async () => {
  await browser?.close();
});

for (const testCase of CASES) {
  test(`probe-virtual-sr smoke: ${testCase.name}`, async () => {
    const page = await browser.newPage();
    try {
      await page.setContent(testCase.html, { waitUntil: 'domcontentloaded' });
      const snapshot = await captureVirtualSr(page);
      assert.equal(
        virtualSrNameRoleStatus(snapshot),
        testCase.expected.status,
        `snapshot: ${JSON.stringify(snapshot)}`,
      );
      if (testCase.expected.namelessCount !== undefined) {
        assert.equal(snapshot.namelessCount, testCase.expected.namelessCount);
      }
    } finally {
      await page.close();
    }
  });
}
