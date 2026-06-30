// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// Homepage hero: white text sits over the dark gradient + pattern, and the
// navbar search input sits over the navbar surface. Both are contrast-sensitive
// regions that the static axe scan must keep >= AA in light and dark themes.
test.describe('Homepage hero accessibility', () => {
  test('hero and search contrast pass an axe scan', async ({ page }) => {
    await page.goto('/hve-core/', { waitUntil: 'domcontentloaded' });

    await expect(page.getByRole('heading', { level: 1, name: 'HVE Core' })).toBeVisible();

    const results = await new AxeBuilder({ page })
      .withTags(WCAG_TAGS)
      .include('.navbar')
      .include('header')
      .analyze();
    expect(results.violations).toEqual([]);
  });

  test('hero contrast passes in dark theme', async ({ page }) => {
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.goto('/hve-core/', { waitUntil: 'domcontentloaded' });
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');

    await expect(page.getByRole('heading', { level: 1, name: 'HVE Core' })).toBeVisible();

    const results = await new AxeBuilder({ page })
      .withTags(WCAG_TAGS)
      .include('.navbar')
      .include('header')
      .analyze();
    expect(results.violations).toEqual([]);
  });
});
