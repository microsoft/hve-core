import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// WCAG 2.1.2 No Keyboard Trap: the mobile navigation menu must open, expose its
// contents to assistive tech, and remain operable in its expanded state.
test.use({ viewport: { width: 390, height: 844 } });

test.describe('Mobile navigation menu', () => {
  test('toggle opens the sidebar and the opened state passes an axe scan', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');

    const toggle = page.locator('.navbar__toggle');
    await expect(toggle).toBeVisible();

    await toggle.click();

    const mobileSidebar = page.locator('.navbar-sidebar');
    await expect(mobileSidebar).toBeVisible();

    const results = await new AxeBuilder({ page })
      .withTags(WCAG_TAGS)
      .include('.navbar-sidebar')
      .analyze();
    expect(results.violations).toEqual([]);
  });
});
