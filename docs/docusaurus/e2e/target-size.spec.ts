// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import { SITE_PAGES, visitInvariantPage } from './_helpers/a11yInvariants';
import { collectTargetSizeViolations } from './_helpers/targetSize';

test.describe('Target size compliance', () => {
  for (const { name, path } of SITE_PAGES) {
    test(`${name} has no SC 2.5.8 target-size violations`, async ({ page }) => {
      await visitInvariantPage(page, { name, path });

      const violations = await collectTargetSizeViolations(page);
      expect(violations).toEqual([]);
    });
  }
});
