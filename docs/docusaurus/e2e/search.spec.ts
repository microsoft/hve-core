// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { SITE_PAGES, visitInvariantPage } from './_helpers/a11yInvariants';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

// Local search (@easyops-cn/docusaurus-search-local) is swizzled/ejected under
// src/theme/SearchBar so the input can be wired to the WAI-ARIA APG Combobox
// pattern. The widget must be operable, surface results, expose a conformant
// combobox/listbox structure, and respond to keyboard navigation.
test.describe('Search', () => {
  for (const pageCase of SITE_PAGES.filter(({ path }) => path.includes('/docs/') || path === '/hve-core/')) {
    test(`${pageCase.name} keeps the search widget semantically wired`, async ({ page }) => {
      await visitInvariantPage(page, pageCase);

      const searchInput = page.locator('.navbar__search-input').first();
      await expect(searchInput).toBeVisible();
      await expect(searchInput).toHaveAttribute('role', 'combobox');
      await expect(searchInput).toHaveAttribute('aria-expanded', 'false');
      await expect(searchInput).toHaveAttribute('aria-labelledby');
      const describedBy = await searchInput.getAttribute('aria-describedby');
      expect(describedBy).toBeTruthy();
    });
  }

  test('injected sr-only heading and description stay visually hidden', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');

    const searchInput = page.locator('.navbar__search-input').first();
    await expect(searchInput).toBeVisible();
    // Focus triggers the swizzle's sync(), which injects the labelling nodes.
    await searchInput.click();

    // The sr-only heading and description must be clipped to a 1px box. A broken
    // hide (e.g. assigning a style object to HTMLElement.style, which is a no-op)
    // would render full-size text and add a stray heading to the banner landmark,
    // so assert the clipped geometry rather than only the ARIA wiring.
    for (const selector of ['#search-input-heading', '#search-shortcut-description']) {
      const node = page.locator(selector);
      await expect(node).toHaveCount(1);
      const box = await node.boundingBox();
      expect(box, `${selector} should be attached to the DOM`).not.toBeNull();
      expect(box!.width).toBeLessThanOrEqual(1);
      expect(box!.height).toBeLessThanOrEqual(1);
    }
  });

  async function openResults(page: import('@playwright/test').Page) {
    await page.goto('/hve-core/docs/getting-started/');

    const searchInput = page.locator('.navbar__search-input').first();
    await expect(searchInput).toBeVisible();

    await searchInput.click();
    await searchInput.fill('getting started');

    // The local search renders a listbox of results anchored to the input. Wait
    // for the actual combobox/listbox structure so the test exercises the
    // interactive widget instead of a transient class name.
    await expect(page.locator('[role="listbox"]').first()).toBeVisible({ timeout: 15000 });
    await expect(page.locator('[role="option"]').first()).toBeVisible({ timeout: 15000 });

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

  test('search results are announced via a status region', async ({ page }) => {
    await openResults(page);

    const status = page.locator('[role="status"]').first();
    await expect(status).toHaveCount(1);
    await expect(status).toHaveText(/No results|\d+ results?/i, { timeout: 15000 });
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
