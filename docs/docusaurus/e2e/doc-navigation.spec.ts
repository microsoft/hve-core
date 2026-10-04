// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { SITE_PAGES, collectPageSnapshot, visitInvariantPage, waitForHydration } from './_helpers/a11yInvariants';

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
    await waitForHydration(page);

    await expect(page.locator('.theme-doc-sidebar-container')).toBeVisible();
    await expect(page.locator('nav.theme-doc-breadcrumbs')).toBeVisible();

    const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
    expect(results.violations).toEqual([]);
  });

  test('section breadcrumbs on child pages link to the section overview', async ({ page }) => {
    const cases = [
      {
        route: '/hve-core/docs/security/fuzzing',
        links: { 'Security Documentation': '/hve-core/docs/security/' },
        plain: ['Reference'],
      },
      {
        route: '/hve-core/docs/getting-started/methods/extension',
        links: {
          'Get Started': '/hve-core/docs/getting-started/',
          'Setup Methods': '/hve-core/docs/getting-started/methods/',
        },
        plain: [],
      },
      {
        route: '/hve-core/docs/hve-guide/lifecycle/setup',
        links: {
          'HVE Guide': '/hve-core/docs/hve-guide/',
          Lifecycle: '/hve-core/docs/hve-guide/lifecycle/',
        },
        plain: ['Workflows'],
      },
    ];

    for (const { route, links, plain } of cases) {
      await page.goto(route);
      await waitForHydration(page);
      const crumbs = page.locator('nav.theme-doc-breadcrumbs');

      for (const [label, href] of Object.entries(links)) {
        await expect(
          crumbs.getByRole('link', { name: label, exact: true }),
          `${route}: "${label}" crumb should link to its overview`,
        ).toHaveAttribute('href', href);
      }

      // A crumb without a landing page must not look like a link.
      for (const label of plain) {
        await expect(crumbs.getByRole('link', { name: label, exact: true })).toHaveCount(0);
        const crumb = crumbs.locator('span.breadcrumbs__link', { hasText: label });
        const [crumbColor, bodyColor] = await crumb.evaluate((element) => [
          getComputedStyle(element).color,
          getComputedStyle(document.body).color,
        ]);
        expect(crumbColor, `${route}: "${label}" crumb should use body text color`).toBe(bodyColor);
      }
    }
  });

  test('pagination navigates to an adjacent doc', async ({ page }) => {
    // Start from the docs landing page and follow its "next" link to an
    // adjacent doc. Category landing pages are covered separately by the
    // landing-page pagination check in the sidebar disclosure spec.
    await page.goto('/hve-core/docs/');
    await waitForHydration(page);

    const nextLink = page.locator('.pagination-nav__link--next');
    await expect(nextLink).toBeVisible();

    const startUrl = page.url();
    await nextLink.click();
    await page.waitForLoadState('networkidle');

    expect(page.url()).not.toBe(startUrl);
    await expect(page.getByRole('main')).toBeVisible();
  });
});
