// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { PAGES } from './_helpers/pages';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'];

// Full-site accessibility crawl. One representative URL per rendered page
// template is scanned against WCAG 2.x A/AA with a single axe pass per page
// (threshold 0). This list is the
// canonical page set for the site; the reflow spec mirrors it for page parity.
// The 404 entry exercises the not-found template, which is also a rendered
// page type users can reach.

test.describe('Full-site accessibility crawl', () => {
  for (const { name, path } of PAGES) {
    test(`${name} passes an axe scan`, async ({ page }, testInfo) => {
      test.setTimeout(60000);
      await page.goto(path, { waitUntil: 'domcontentloaded' });

      const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
      await testInfo.attach(`${name}-incomplete`, {
        body: JSON.stringify(results.incomplete, null, 2),
        contentType: 'application/json',
      });
      expect(results.violations).toEqual([]);
    });
  }
});
