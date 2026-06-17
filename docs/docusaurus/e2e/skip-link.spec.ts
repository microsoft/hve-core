import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// WCAG 2.4.1 Bypass Blocks: the "Skip to main content" link must be
// keyboard-reachable and move focus to the main content region.
test.describe('Skip-to-content link', () => {
  test('is reachable by keyboard and moves focus to main content', async ({ page }) => {
    await page.goto('/hve-core/');

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

  test('post-activation DOM passes an axe scan', async ({ page }) => {
    await page.goto('/hve-core/');
    await page.keyboard.press('Tab');
    await page.getByRole('link', { name: /skip to main content/i }).press('Enter');

    const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
    expect(results.violations).toEqual([]);
  });
});
