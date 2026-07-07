// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import { SITE_PAGES, visitInvariantPage } from './_helpers/a11yInvariants';

test.describe('Heading-order accessibility regression locks', () => {
  for (const { name, path } of SITE_PAGES) {
    test(`${name} does not skip heading levels`, async ({ page }) => {
      await visitInvariantPage(page, { name, path });

      const levels = await page.$$eval('h1, h2, h3, h4, h5, h6', (headings) =>
        headings.map((heading) => Number(heading.tagName.charAt(1))),
      );

      let previousLevel: number | null = null;
      for (const level of levels) {
        if (previousLevel !== null) {
          expect(
            level,
            `Heading level jumped from ${previousLevel} to ${level} on ${name}`,
          ).toBeLessThanOrEqual(previousLevel + 1);
        }
        previousLevel = level;
      }
    });
  }
});
