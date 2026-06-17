import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// Local search (@easyops-cn/docusaurus-search-local) is swizzled/ejected under
// src/theme/SearchBar so the input can be wired to the WAI-ARIA APG Combobox
// pattern. The widget must be operable, surface results, expose a conformant
// combobox/listbox structure, and respond to keyboard navigation.
test.describe('Search', () => {
  async function openResults(page: import('@playwright/test').Page) {
    await page.goto('/hve-core/docs/getting-started/');

    const searchInput = page.locator('.navbar__search-input').first();
    await expect(searchInput).toBeVisible();

    await searchInput.click();
    await searchInput.fill('getting started');

    // The local search renders a suggestions dropdown anchored to the input;
    // @easyops-cn/docusaurus-search-local emits hashed `suggestion_*` classes.
    const results = page.locator('[class*="suggestion_"]').first();
    await expect(results).toBeVisible({ timeout: 15000 });

    return searchInput;
  }

  test('typing a query surfaces operable results that pass an axe scan', async ({ page }) => {
    await openResults(page);

    // Scoped scan of the open combobox + listbox. The swizzled SearchBar now
    // marks the input as role="combobox" and the library emits the
    // role="listbox"/role="option" tree, so the dropdown must be violation-free.
    const results = await new AxeBuilder({ page })
      .withTags(WCAG_TAGS)
      .include('.navbar__search')
      .analyze();
    expect(results.violations).toEqual([]);
  });

  test('the combobox exposes the required APG structure', async ({ page }) => {
    const searchInput = await openResults(page);

    await expect(searchInput).toHaveAttribute('role', 'combobox');
    await expect(searchInput).toHaveAttribute('aria-autocomplete', 'list');
    await expect(searchInput).toHaveAttribute('aria-expanded', 'true');

    // aria-controls must reference the live listbox.
    const listbox = page.locator('[role="listbox"]').first();
    const listboxId = await listbox.getAttribute('id');
    expect(listboxId).toBeTruthy();
    await expect(searchInput).toHaveAttribute('aria-controls', listboxId as string);

    // Options carry role="option" with stable ids for aria-activedescendant.
    await expect(page.locator('[role="option"]').first()).toBeVisible();
  });

  test('the results dropdown is keyboard operable', async ({ page }) => {
    const searchInput = await openResults(page);

    // SC 2.1.1: ArrowDown moves the active option and syncs aria-activedescendant.
    await searchInput.press('ArrowDown');

    const activeId = await searchInput.getAttribute('aria-activedescendant');
    expect(activeId).toBeTruthy();
    const activeOption = page.locator(`#${activeId}`);
    await expect(activeOption).toHaveAttribute('aria-selected', 'true');

    // Enter activates the cursored option and navigates to its document.
    await searchInput.press('Enter');
    await expect(page).not.toHaveURL(/\/docs\/getting-started\/?$/, { timeout: 15000 });
  });

  test('Escape dismisses the open dropdown', async ({ page }) => {
    const searchInput = await openResults(page);

    // APG: Escape dismisses the popup and collapses the combobox.
    await searchInput.press('Escape');

    await expect(page.locator('[role="option"]').first()).toBeHidden({ timeout: 5000 });
    await expect(searchInput).toHaveAttribute('aria-expanded', 'false');
  });
});
