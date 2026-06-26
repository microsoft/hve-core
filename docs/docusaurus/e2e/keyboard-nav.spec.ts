// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// WCAG 2.1.1 Keyboard: primary navigation must be operable by keyboard and
// every interactive element must surface a visible focus state.
test.describe('Keyboard navigation', () => {
  test('navbar links are reachable via Tab from the top of the page', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');

    const docNavLink = page.getByRole('link', { name: 'Documentation', exact: true });
    await expect(docNavLink).toBeVisible();

    // Walk the focus order until the Documentation navbar link receives focus.
    let focusedDocLink = false;
    for (let i = 0; i < 12; i++) {
      await page.keyboard.press('Tab');
      if (await docNavLink.evaluate((el) => el === document.activeElement)) {
        focusedDocLink = true;
        break;
      }
    }

    expect(focusedDocLink).toBe(true);
  });

  test('doc page initial state passes an axe scan', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');
    await expect(page.getByRole('main')).toBeVisible();

    const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
    expect(results.violations).toEqual([]);
  });
});
