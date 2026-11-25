// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Browser smoke tests for probe-live-region. These reproduce the runner's real
// observe-before-navigation, clear-before-trigger, settle-then-read path against
// inline fixtures, proving the live-region firing detection and the WCAG 4.1.3
// verdict. Named *.smoke.mjs so the default browserless `node --test` run does
// not pick them up; run them with `npm run ci:test:a11y:smoke`.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { liveRegionStatus } from '../../../../scripts/runtime_a11y/runner/_core.mjs';
import {
  clearLiveRegionLog,
  launchChrome,
  liveRegionObserverScript,
  readLiveRegionSnapshot,
} from '../../../../scripts/runtime_a11y/runner/_shared.mjs';
import { CASES } from './live-region.cases.mjs';

let browser;

before(async () => {
  browser = await launchChrome();
});

after(async () => {
  await browser?.close();
});

for (const testCase of CASES) {
  test(`probe-live-region smoke: ${testCase.name}`, async () => {
    const page = await browser.newPage();
    try {
      // Mirror runProbeWithPage: observe from first paint, navigate, clear the
      // hydration log, drive the trigger, then read the settled snapshot.
      await page.addInitScript(liveRegionObserverScript);
      await page.goto(`data:text/html,${encodeURIComponent(testCase.html)}`, {
        waitUntil: 'domcontentloaded',
      });
      await clearLiveRegionLog(page);
      if (testCase.fire) {
        await page.evaluate(() => (typeof window.__fire === 'function' ? window.__fire() : undefined));
      }
      const snapshot = await readLiveRegionSnapshot(page, { settleMs: 200 });
      assert.equal(
        liveRegionStatus(snapshot, testCase.state),
        testCase.expected.status,
        `snapshot: ${JSON.stringify(snapshot)}`,
      );
    } finally {
      await page.close();
    }
  });
}
