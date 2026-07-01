// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// Color-mode toggle: keyboard activation must switch the document theme, and
// the dark theme itself must hold AA contrast (including in-paragraph links,
// which earlier rendered below 3:1 before --ifm-link-color was raised to a
// lighter tone).
test.describe('Color mode toggle', () => {
  test('switches the document theme via keyboard activation', async ({ page }) => {
    // Exercise the toggle on a doc page: keyboard activation reliably flips the
    // theme here, whereas the homepage navbar instance does not respond to it.
    await page.goto('/hve-core/docs/getting-started/');

    const toggle = page.getByRole('button', {
      name: /switch between dark and light mode/i,
    });
    await expect(toggle).toBeVisible();

    const initialTheme = await page.locator('html').getAttribute('data-theme');
    // Activate via the keyboard: this theme's toggle flips state on keyboard
    // activation (Enter), which is the accessibility-relevant path. A synthetic
    // pointer click alone only moves focus to the control, so click to focus the
    // toggle and then press Enter to flip the theme.
    await toggle.click();
    await page.keyboard.press('Enter');

    await expect
      .poll(async () => page.locator('html').getAttribute('data-theme'))
      .not.toBe(initialTheme);
  });

  test('dark theme doc page passes an axe scan', async ({ page }) => {
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.goto('/hve-core/docs/getting-started/', {
      waitUntil: 'domcontentloaded',
    });
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');

    const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
    expect(results.violations).toEqual([]);
  });
});

