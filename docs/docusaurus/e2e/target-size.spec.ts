// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import { PAGES } from './_helpers/pages';
import { collectTargetSizeViolations } from './_helpers/targetSize';

test.describe('Target size compliance', () => {
  for (const { name, path } of PAGES) {
    test(`${name} has no SC 2.5.8 target-size violations`, async ({ page }) => {
      await page.goto(path, { waitUntil: 'domcontentloaded' });

      const violations = await collectTargetSizeViolations(page);
      expect(violations).toEqual([]);
    });
  }
});
