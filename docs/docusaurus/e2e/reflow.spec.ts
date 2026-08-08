// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect, type Page } from '@playwright/test';
import { SITE_PAGES, openSearchWidget, visitInvariantPage } from './_helpers/a11yInvariants';

async function expandNavbarSearch(page: Page) {
  // Gate on upstream attachment, not on role="combobox": the swizzle applies
  // that role itself, so waiting for it would fill the field before the
  // upstream handler exists and leave the popup unrendered.
  const input = await openSearchWidget(page);
  await input.fill('agent');
  await page.locator('[role="listbox"]').first().waitFor({ state: 'visible', timeout: 30000 });
  return input;
}

// Curated key pages mirrored from the site-crawl spec for page parity (the
// 404 entry is omitted because reflow/resize assertions target real content
// pages).
const PAGES = SITE_PAGES.filter(({ path }) => path !== '/hve-core/this-page-does-not-exist/');

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
      await visitInvariantPage(page, { name, path });

      await expect(page.getByRole('main')).toBeVisible();
      expect(await page.evaluate(hasNoHorizontalScroll)).toBeTruthy();
    });

    // WCAG 1.4.10 Reflow: at 320 CSS px the expanded navbar search must not
    // overlay the "HVE Core" brand link. The search plugin positions its
    // container absolutely, so the brand is sized to its content and the
    // wordmark is taken out of layout at this breakpoint to leave room.
    test(`${name} keeps the expanded navbar search from overlapping the brand`, async ({ page }) => {
      await visitInvariantPage(page, { name, path });

      const input = await expandNavbarSearch(page);
      await expect(input).toBeVisible();

      const overlap = await page.evaluate(() => {
        const brand = document.querySelector('.navbar__brand') as HTMLElement | null;
        const searchInput = document.querySelector('input.navbar__search-input') as HTMLElement | null;
        if (!brand || !searchInput) {
          return false;
        }

        const brandRect = brand.getBoundingClientRect();
        const inputRect = searchInput.getBoundingClientRect();
        const horizontalOverlap = brandRect.right >= inputRect.left && brandRect.left <= inputRect.right;
        const verticalOverlap = brandRect.bottom >= inputRect.top && brandRect.top <= inputRect.bottom;
        return horizontalOverlap && verticalOverlap;
      });

      expect(overlap, `${name} should keep the navbar search from overlapping the brand at 320 CSS px`).toBe(false);
    });
  }
});

// WCAG 1.4.4 Resize Text: at the default viewport, enlarging text to 200% must
// not clip or obscure primary content. Font-size is reset after each assertion
// so the shared page state does not leak between checks.
test.describe('Resize text to 200% (WCAG 1.4.4)', () => {
  for (const { name, path } of PAGES) {
    test(`${name} stays usable at 200% text size`, async ({ page }) => {
      await visitInvariantPage(page, { name, path });

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
