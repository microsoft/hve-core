// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';

// Curated key pages mirrored from the site-crawl spec for page parity (the
// 404 entry is omitted because reflow/resize assertions target real content
// pages).
const PAGES = [
  { name: 'home', path: '/hve-core/' },
  { name: 'docs', path: '/hve-core/docs/' },
  { name: 'getting-started', path: '/hve-core/docs/getting-started/' },
  { name: 'content (task-researcher)', path: '/hve-core/docs/rpi/task-researcher/' },
];

// Sub-pixel rounding can leave scrollWidth one pixel beyond clientWidth on
// otherwise-conformant layouts, so a 1px tolerance absorbs that noise.
const hasNoHorizontalScroll = () =>
  document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1;

// WCAG 1.4.10 Reflow: at 320 CSS px wide, content must not require horizontal
// scrolling. The assertion is scoped to the document root — Infima legitimately
// allows internal horizontal scroll on code blocks (`pre`) and wide tables, so
// those descendants are intentionally excluded to avoid false positives.
test.describe('Reflow at 320 CSS px (WCAG 1.4.10)', () => {
  test.use({ viewport: { width: 320, height: 856 } });

  for (const { name, path } of PAGES) {
    test(`${name} has no horizontal scroll`, async ({ page }) => {
      await page.goto(path);

      await expect(page.getByRole('main')).toBeVisible();
      expect(await page.evaluate(hasNoHorizontalScroll)).toBeTruthy();
    });
  }
});

// WCAG 1.4.4 Resize Text: at the default viewport, enlarging text to 200% must
// not clip or obscure primary content. Font-size is reset after each assertion
// so the shared page state does not leak between checks.
test.describe('Resize text to 200% (WCAG 1.4.4)', () => {
  for (const { name, path } of PAGES) {
    test(`${name} stays usable at 200% text size`, async ({ page }) => {
      await page.goto(path);

      await page.evaluate(() => {
        document.documentElement.style.fontSize = '200%';
      });

      try {
        await expect(page.getByRole('main')).toBeVisible();
        expect(await page.evaluate(hasNoHorizontalScroll)).toBeTruthy();
      } finally {
        await page.evaluate(() => {
          document.documentElement.style.fontSize = '';
        });
      }
    });
  }
});
