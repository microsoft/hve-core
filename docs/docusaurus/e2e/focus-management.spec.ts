// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import { SITE_PAGES, visitInvariantPage } from './_helpers/a11yInvariants';
import { testFocusTrapEscape, validateRovingTabindex } from './_helpers/focus';

// Behavioral keyboard/focus conformance against real Docusaurus hooks. These
// assertions exercise runtime keyboard behavior (WCAG 2.1.1, 2.1.2, 2.4.3) that
// the static axe-based specs cannot reach. Contrast and structural ARIA checks
// stay in the existing axe specs to avoid redundant coverage.

test.describe('Focus management', () => {
  for (const pageCase of SITE_PAGES.filter(({ path }) => path.includes('/docs/') || path === '/hve-core/')) {
    test(`${pageCase.name} exposes a visible four-sided focus indicator on interactive controls`, async ({ page }) => {
      await visitInvariantPage(page, pageCase);

      const target = page.locator('a, button, input, select, textarea, [tabindex]:not([tabindex="-1"])').first();
      await expect(target).toBeVisible();
      await target.focus();

      const styles = await target.evaluate((element) => {
        const computed = window.getComputedStyle(element);
        return {
          outline: computed.outline,
          outlineWidth: computed.outlineWidth,
          boxShadow: computed.boxShadow,
        };
      });

      expect(styles.outline, `${pageCase.name} should expose a visible focus outline`).not.toMatch(/none|0px/i);
      expect(styles.boxShadow, `${pageCase.name} should expose a visible box-shadow focus cue`).not.toMatch(/none/i);
    });
  }

  // WCAG 2.4.3 Focus Order + 2.4.1 Bypass Blocks: the skip link must be the
  // first element to receive focus from the top of the page.
  test('skip link is first in the focus order', async ({ page }) => {
    await page.goto('/hve-core/');

    await page.keyboard.press('Tab');

    const skipLink = page.getByRole('link', { name: /skip to main content/i });
    await expect(skipLink).toBeFocused();
  });

  // WCAG 2.1.1 Keyboard: the color-mode toggle must be operable by keyboard and
  // flip the document theme on Enter.
  test('color-mode toggle is keyboard operable', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');

    const toggle = page.getByRole('button', {
      name: /switch between dark and light mode/i,
    });
    await expect(toggle).toBeVisible();

    const initialTheme = await page.locator('html').getAttribute('data-theme');

    // Click to focus the control, then activate via the keyboard. This theme's
    // toggle flips state on Enter, which is the accessibility-relevant path.
    await toggle.click();
    await page.keyboard.press('Enter');

    await expect
      .poll(async () => page.locator('html').getAttribute('data-theme'))
      .not.toBe(initialTheme);
  });

  // WCAG 2.1.1 Keyboard / 2.4.3 Focus Order: opening the navbar dropdown (when
  // present) must expose keyboard-reachable menu items. The Docusaurus default
  // theme implements its navbar dropdown as a disclosure-navigation menu where
  // every item is a naturally tabbable <a> (no roving tabindex). Roving tabindex
  // is only asserted when the menu is actually built as a roving-tabindex widget,
  // guarding against false failures as the plan requires.
  test('navbar dropdown exposes keyboard-reachable items when present', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');

    const dropdownToggle = page.locator('.navbar__item.dropdown .navbar__link').first();

    // Dropdown navbar items are optional in the site config; skip cleanly when
    // none exist rather than producing a false failure.
    if ((await dropdownToggle.count()) === 0) {
      test.skip(true, 'No dropdown navbar item is configured.');
      return;
    }

    // Open the dropdown via the keyboard path. A hover+click sequence on a
    // hoverable dropdown is ambiguous (hovering opens the menu, so the click
    // then toggles it closed); focusing the toggle and pressing ArrowDown is
    // the operable path a keyboard user takes and is what this test asserts.
    await dropdownToggle.focus();
    await dropdownToggle.press('ArrowDown');

    const dropdownMenu = page.locator('.navbar__item.dropdown .dropdown__menu').first();
    await expect(dropdownMenu).toBeVisible();

    // Branch on the widget pattern. A roving-tabindex menu carries explicit
    // tabindex attributes; a disclosure-navigation menu carries none.
    const rovingItemCount = await dropdownMenu.locator('[tabindex]').count();

    if (rovingItemCount > 0) {
      // Composite roving-tabindex widget: exactly one tabindex="0", rest -1.
      expect(await validateRovingTabindex(page, '.navbar__item.dropdown .dropdown__menu')).toBe(true);
      return;
    }

    // Disclosure-navigation menu: every link must be individually keyboard
    // focusable so the menu is fully operable without a pointer (WCAG 2.1.1).
    const menuLinks = dropdownMenu.locator('a');
    const linkCount = await menuLinks.count();
    expect(linkCount).toBeGreaterThan(0);

    for (let index = 0; index < linkCount; index += 1) {
      const link = menuLinks.nth(index);
      await link.focus();
      await expect(link).toBeFocused();
    }
  });
});

// WCAG 2.1.2 No Keyboard Trap: the mobile sidebar must let keyboard focus leave
// the container. Some themes release focus on Escape; the Docusaurus default
// theme instead provides a keyboard-operable "Close navigation bar" control.
// Either mechanism satisfies No Keyboard Trap, so the spec accepts both.
test.describe('Mobile sidebar focus trap', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('keyboard focus can leave the open mobile sidebar', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');

    const toggle = page.locator('.navbar__toggle');
    await expect(toggle).toBeVisible();

    await toggle.click();

    const mobileSidebar = page.locator('.navbar-sidebar');
    await expect(mobileSidebar).toBeVisible();

    // Preferred path: focus leaves the container on Escape when the theme wires
    // it. The Docusaurus default theme does not, so fall through when it fails.
    if (await testFocusTrapEscape(page, '.navbar-sidebar')) {
      return;
    }

    // Docusaurus default theme path: the dedicated close control must be
    // keyboard operable and must collapse the sidebar, releasing focus.
    const closeButton = page.getByRole('button', { name: /close navigation bar/i });
    await closeButton.focus();
    await expect(closeButton).toBeFocused();

    await page.keyboard.press('Enter');

    await expect(mobileSidebar).toBeHidden();
  });
});
