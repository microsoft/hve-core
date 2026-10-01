// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

// Real-browser contract tests for probe-aria-tree. The smoke lane is CI-owned
// because it launches system Chrome; run it with `npm run ci:test:a11y:smoke`
// after installing the skill-local dependencies.
import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { buildAriaTreeProbePayload } from '../../../../scripts/runtime_a11y/runner/probe-aria-tree.mjs';
import { launchChrome, snapshotAccessibilityTree } from '../../../../scripts/runtime_a11y/runner/_shared.mjs';

let browser;

before(async () => {
  browser = await launchChrome();
});

after(async () => {
  await browser?.close();
});

async function inspectFixture(html) {
  const page = await browser.newPage();
  try {
    await page.setContent(html, { waitUntil: 'domcontentloaded' });
    const accessibilityTree = await snapshotAccessibilityTree(page);
    const payload = await buildAriaTreeProbePayload({
      accessibilityTree,
      snapshot: { accessibleNameCount: 0, labels: 0, roles: 0 },
      state: 'default',
      surfaceId: 'fixture',
      targetUrl: 'data:text/html,aria-tree',
    });
    return { accessibilityTree, payload };
  } finally {
    await page.close();
  }
}

test('probe-aria-tree smoke: real CDP nodes use AXValue fields and childIds', async () => {
  const { accessibilityTree, payload } = await inspectFixture('<main><button></button></main>');
  const visibleNodes = accessibilityTree.nodes.filter((node) => node.ignored !== true);

  assert.equal(accessibilityTree.source, 'cdp');
  assert.ok(visibleNodes.some((node) => typeof node.role?.value === 'string'));
  assert.ok(visibleNodes.some((node) => Array.isArray(node.childIds) && node.childIds.length > 0));
  assert.equal(payload.results.find((result) => result.criterionId === '4.1.2')?.status, 'fail');
});

test('probe-aria-tree smoke: named native button passes without explicit roles', async () => {
  const { payload } = await inspectFixture('<main><button>Continue</button></main>');

  assert.equal(payload.results.find((result) => result.criterionId === '4.1.2')?.status, 'pass');
});
