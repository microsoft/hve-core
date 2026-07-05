// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { SITE_PAGES, collectPageSnapshot, visitInvariantPage } from './_helpers/a11yInvariants';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// Document navigation: the sidebar, prev/next pagination, and breadcrumbs must
// drive real navigation and remain accessible.
test.describe('Document navigation', () => {
  for (const pageCase of SITE_PAGES) {
    test(`${pageCase.name} exposes banner, navigation, main, and grouped content semantics`, async ({ page }) => {
      await visitInvariantPage(page, pageCase);

      const snapshot = await collectPageSnapshot(page);
      expect(snapshot.landmarks.banner, `${pageCase.name} should expose a banner landmark`).toBeGreaterThan(0);
      expect(snapshot.landmarks.navigation, `${pageCase.name} should expose a navigation landmark`).toBeGreaterThan(0);
      expect(snapshot.landmarks.main, `${pageCase.name} should expose a main landmark`).toBeGreaterThan(0);
      // The article table-of-contents heading only exists on doc pages; custom
      // pages (home, 404) legitimately have no TOC.
      if (pageCase.path.includes('/docs/')) {
        expect(snapshot.tocHeading, `${pageCase.name} should expose an article TOC heading`).toContain('article');
      }
      expect(snapshot.footerTitles.length, `${pageCase.name} should expose footer group titles`).toBeGreaterThan(0);
    });
  }

  test('sidebar renders and breadcrumbs are present on a doc page', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');

    await expect(page.locator('.theme-doc-sidebar-container')).toBeVisible();
    await expect(page.locator('nav.theme-doc-breadcrumbs')).toBeVisible();

    const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
    expect(results.violations).toEqual([]);
  });

  test('pagination navigates to an adjacent doc', async ({ page }) => {
    // Start from the docs landing page, whose "next" link targets a distinct
    // adjacent doc (deeper category-index pages can emit a self-referential
    // next link, which would never change the URL).
    await page.goto('/hve-core/docs/');

    const nextLink = page.locator('.pagination-nav__link--next');
    await expect(nextLink).toBeVisible();

    const startUrl = page.url();
    await nextLink.click();
    await page.waitForLoadState('networkidle');

    expect(page.url()).not.toBe(startUrl);
    await expect(page.getByRole('main')).toBeVisible();
  });
});
