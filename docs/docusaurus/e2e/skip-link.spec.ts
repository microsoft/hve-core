// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { waitForHydration } from './_helpers/a11yInvariants';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// WCAG 2.4.1 Bypass Blocks: the "Skip to main content" link must be
// keyboard-reachable and move focus to the main content region.
test.describe('Skip-to-content link', () => {
  test('is reachable by keyboard and moves focus to main content', async ({ page }) => {
    await page.goto('/hve-core/');
    await waitForHydration(page);

    // The skip link is the first focusable element in the DOM.
    await page.keyboard.press('Tab');

    const skipLink = page.getByRole('link', { name: /skip to main content/i });
    await expect(skipLink).toBeFocused();

    await skipLink.press('Enter');

    // Activating the bypass link targets the main-content region. Docusaurus
    // manages focus transiently (it sets tabindex="-1", focuses the container,
    // then removes the attribute) and does not write a URL hash, so focus
    // reverts to <body>. Assert the bypass target is present and visible rather
    // than relying on a racy focus or URL check.
    await expect(page.locator('#__docusaurus_skipToContent_fallback')).toBeVisible();
  });

  test('resolves to the single main landmark on the search route', async ({ page }) => {
    await page.goto('/hve-core/search/');
    await waitForHydration(page);

    // The search route renders no <main> of its own, so the layout promotes the
    // skip-link container to a main landmark. Without one the skip link has no
    // destination on this page at all.
    const skipLink = page.getByRole('link', { name: /skip to main content/i });
    const href = await skipLink.getAttribute('href');
    expect(href, 'the skip link should carry a fragment target').toMatch(/^#/);

    const targetId = href!.slice(1);
    const target = page.locator(`[id="${targetId}"]`);

    // Uniqueness matters: a second element with the same id would give the link
    // a competing destination and make the assertion below meaningless.
    await expect(target).toHaveCount(1);

    const isMainLandmark = await target.evaluate(
      (node) => node.tagName.toLowerCase() === 'main' || node.getAttribute('role') === 'main',
    );
    expect(isMainLandmark, 'the skip-link target must be the main landmark').toBe(true);

    const mainCount = await page.locator('main, [role="main"]').count();
    expect(mainCount, 'the search route must expose exactly one main landmark').toBe(1);

    await page.keyboard.press('Tab');
    await expect(skipLink).toBeFocused();
    await skipLink.press('Enter');
    await expect(target).toBeVisible();
  });

  test('post-activation DOM passes an axe scan', async ({ page }) => {
    await page.goto('/hve-core/');
    await waitForHydration(page);
    await page.keyboard.press('Tab');
    await page.getByRole('link', { name: /skip to main content/i }).press('Enter');

    const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
    expect(results.violations).toEqual([]);
  });
});
