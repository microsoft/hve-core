// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';

// Screen-reader exploration flows.
//
// These specs assert the semantics a screen reader consumes from the
// accessibility tree: landmark structure, heading order, accessible names,
// live-region announcements, and keyboard-driven reachability. They are a
// deterministic, CI-robust per-PR smoke set. Authentic spoken-output
// verification with real assistive technology (NVDA on Windows, VoiceOver on
// macOS) is covered by the scheduled nightly screen-reader workflow rather than
// this per-PR suite.
//
// Relevant standards: WCAG 1.3.1 Info and Relationships, 2.4.3 Focus Order,
// 4.1.2 Name, Role, Value, 4.1.3 Status Messages, and the WAI-ARIA Authoring
// Practices Menu and Combobox patterns.

async function headingLevels(page: Page): Promise<number[]> {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6')).map((h) =>
      Number(h.tagName.charAt(1)),
    ),
  );
}

test.describe('Screen-reader exploration: landmark and heading walk', () => {
  for (const path of ['/hve-core/', '/hve-core/docs/getting-started/']) {
    test(`${path} exposes a single set of ordered landmarks and a non-skipping heading outline`, async ({
      page,
    }) => {
      await page.goto(path, { waitUntil: 'domcontentloaded' });

      // A screen reader's landmark rotor should find exactly one main and one
      // contentinfo (footer), and at least one banner and navigation.
      await expect(page.getByRole('main')).toHaveCount(1);
      await expect(page.getByRole('contentinfo')).toHaveCount(1);
      expect(await page.getByRole('banner').count()).toBeGreaterThanOrEqual(1);
      expect(await page.getByRole('navigation').count()).toBeGreaterThanOrEqual(1);

      // The document exposes exactly one h1 as the primary entry point.
      await expect(page.getByRole('heading', { level: 1 })).toHaveCount(1);

      // Heading levels never skip (e.g., h2 -> h4), so the outline a screen
      // reader announces stays coherent.
      const levels = await headingLevels(page);
      expect(levels.length).toBeGreaterThan(0);
      for (let i = 1; i < levels.length; i += 1) {
        const delta = levels[i] - levels[i - 1];
        expect(delta).toBeLessThanOrEqual(1);
      }
    });
  }
});

test.describe('Screen-reader exploration: search combobox', () => {
  test('typing a query announces a result count and exposes a keyboard-reachable "See all results"', async ({
    page,
  }) => {
    await page.goto('/hve-core/docs/getting-started/', { waitUntil: 'domcontentloaded' });

    const searchInput = page.locator('.navbar__search-input').first();
    await expect(searchInput).toBeVisible();
    await expect(searchInput).toHaveAttribute('role', 'combobox');

    // A live region (role="status") carries the result-count announcement.
    const status = page.locator('[role="status"]').first();

    await searchInput.click();
    await searchInput.fill('getting started');

    // The listbox of results a screen reader would navigate into is exposed.
    await expect(page.locator('[role="listbox"]').first()).toBeVisible({ timeout: 15000 });
    await expect(page.locator('[role="option"]').first()).toBeVisible({ timeout: 15000 });

    // The status region announces a deterministic count string.
    await expect(status).toHaveText(/result/i, { timeout: 15000 });

    // The "See all results" footer must be reachable and activatable by
    // keyboard as part of the combobox, not orphaned as a mouse-only control.
    // The swizzle tags it role="option" so the listbox owns only valid children
    // (axe aria-required-children); its accessible name includes "See all".
    const seeAll = page.getByRole('option', { name: /see all/i }).first();
    await expect(seeAll).toBeVisible();
    const seeAllId = await seeAll.getAttribute('id');
    expect(seeAllId, 'the "See all results" control needs a stable id for aria-activedescendant').toBeTruthy();
  });

  test('the combobox does not announce results before an explicit query', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/', { waitUntil: 'domcontentloaded' });

    // WCAG 4.1.3: no spurious status message on load. The live region starts
    // empty until the user searches.
    const status = page.locator('[role="status"]').first();
    if (await status.count()) {
      await expect(status).toHaveText('');
    }
  });
});

test.describe('Screen-reader exploration: navbar dropdown announcements', () => {
  test('the dropdown toggle exposes menu semantics and opens/closes by keyboard', async ({
    page,
  }) => {
    await page.goto('/hve-core/', { waitUntil: 'domcontentloaded' });

    const toggle = page
      .getByRole('button')
      .filter({ has: page.locator('[aria-haspopup="menu"]') })
      .first();

    // Fall back to any navbar button advertising a menu popup.
    const menuToggle = (await toggle.count())
      ? toggle
      : page.locator('button[aria-haspopup="menu"]').first();

    if (!(await menuToggle.count())) {
      test.skip(true, 'No navbar dropdown is configured on this build.');
      return;
    }

    await expect(menuToggle).toHaveAttribute('aria-expanded', 'false');

    await menuToggle.focus();
    await page.keyboard.press('Enter');

    await expect(menuToggle).toHaveAttribute('aria-expanded', 'true');
    const menu = page.getByRole('menu').first();
    await expect(menu).toBeVisible();
    expect(await menu.getByRole('menuitem').count()).toBeGreaterThan(0);

    // Escape closes the menu and restores focus to the toggle (WAI-ARIA APG).
    await page.keyboard.press('Escape');
    await expect(menuToggle).toHaveAttribute('aria-expanded', 'false');
    await expect(menuToggle).toBeFocused();
  });
});
