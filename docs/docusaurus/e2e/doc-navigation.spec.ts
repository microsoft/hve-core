import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// Document navigation: the sidebar, prev/next pagination, and breadcrumbs must
// drive real navigation and remain accessible.
test.describe('Document navigation', () => {
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
