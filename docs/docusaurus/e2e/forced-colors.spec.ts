// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { PAGES } from './_helpers/pages';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

test.use({ contextOptions: { forcedColors: 'active' } });

test.describe('Forced-colors accessibility regression locks', () => {
  for (const { name, path } of PAGES) {
    test(`${name} passes an axe scan in forced-colors mode`, async ({ page }) => {
      await page.goto(path, { waitUntil: 'domcontentloaded' });

      const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
      expect(results.violations).toEqual([]);
    });
  }
});
