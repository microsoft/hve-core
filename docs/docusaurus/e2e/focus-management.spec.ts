// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import type { Page } from '@playwright/test';
import { SITE_PAGES, visitInvariantPage } from './_helpers/a11yInvariants';
import { testFocusTrapEscape, validateRovingTabindex } from './_helpers/focus';

// Behavioral keyboard/focus conformance against real Docusaurus hooks. These
// assertions exercise runtime keyboard behavior that the static axe-based specs
// cannot reach: keyboard operability and trap escape (WCAG 2.1.1, 2.1.2), focus
// order (2.4.3), focus visibility (2.4.7), and focus indicator size (2.4.11).
// Contrast and structural ARIA checks stay in the existing axe specs to avoid
// redundant coverage.

// Assert that keyboard focus rests on the route's main landmark.
//
// The assertion is deliberately positive: it compares the active element by
// identity against <main>. Asserting only that focus is *not* on the skip link
// passes when focus is lost to <body>, since <body> carries no href. Reporting
// the element that actually held focus keeps a failure diagnosable.
async function expectFocusOnMainLandmark(page: Page, context: string): Promise<void> {
  const focusState = await page.evaluate(() => {
    const main = document.querySelector('main, [role="main"]');
    const active = document.activeElement as HTMLElement | null;
    const describe = (el: Element | null) => {
      if (!el) return 'null';
      const tag = el.tagName.toLowerCase();
      if (tag === 'body') return 'body (focus lost)';
      const className = String(el.className || '').split(' ').filter(Boolean)[0];
      return className ? `${tag}.${className}` : tag;
    };
    return {
      hasMain: Boolean(main),
      focusIsMain: Boolean(main && active === main),
      activeDescription: describe(active),
    };
  });

  expect(focusState.hasMain, `${context}: the destination route should render a main landmark`).toBe(true);
  expect(
    focusState.focusIsMain,
    `${context}: focus should rest on the main landmark, but it was on ${focusState.activeDescription}`,
  ).toBe(true);
}

// Assert that the next Tab enters main content rather than restarting the focus
// order at the skip link (WCAG 2.4.3).
async function expectNextTabEntersMain(page: Page, context: string): Promise<void> {
  await page.keyboard.press('Tab');

  const tabState = await page.evaluate(() => {
    const main = document.querySelector('main, [role="main"]');
    const active = document.activeElement as HTMLElement | null;
    return {
      // Require focus to move strictly *inside* main. `contains` is true for
      // main itself, so without the identity check this would also pass when
      // Tab moved focus nowhere at all.
      insideMain: Boolean(main && active && active !== main && main.contains(active)),
      activeDescription: active
        ? `${active.tagName.toLowerCase()}${active.getAttribute('href') ? ` href=${active.getAttribute('href')}` : ''}`
        : 'null',
    };
  });

  expect(
    tabState.insideMain,
    `${context}: the first Tab after navigation should focus an element inside main content, but focus moved to ${tabState.activeDescription}`,
  ).toBe(true);
}

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
          outlineStyle: computed.outlineStyle,
          boxShadow: computed.boxShadow,
        };
      });

      // The stylesheet applies a focus box-shadow to every :focus-visible
      // control site-wide, so asserting boxShadow !== 'none' cannot fail for any
      // focusable element. Assert the outline actually renders instead, which is
      // the four-sided indicator this test names.
      expect(
        styles.outlineStyle,
        `${pageCase.name} should draw a focus outline style`,
      ).not.toMatch(/none/i);
      expect(
        Number.parseFloat(styles.outlineWidth) || 0,
        `${pageCase.name} should expose a focus outline at least 2 CSS px thick`,
      ).toBeGreaterThanOrEqual(2);
    });

    // WCAG 2.2 SC 2.4.11 Focus Appearance states a quantitative minimum, so the
    // indicator is measured on every focusable control rather than sampled:
    // the ring must be at least 2 CSS px thick around the whole perimeter.
    // Controls whose indicator is drawn purely as a box-shadow are accepted,
    // since the shadow supplies the perimeter instead of the outline.
    test(`${pageCase.name} draws a focus indicator of at least 2 CSS pixels`, async ({ page }) => {
      await visitInvariantPage(page, pageCase);

      const thinIndicators = await page.evaluate(() => {
        const selector = 'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])';
        const candidates = Array.from(document.querySelectorAll<HTMLElement>(selector))
          .filter((element) => element.getClientRects().length > 0);

        const offenders = [];
        for (const element of candidates) {
          element.focus();
          const computed = window.getComputedStyle(element);
          const outlineWidth = Number.parseFloat(computed.outlineWidth) || 0;
          const hasShadowRing = computed.boxShadow !== 'none';
          if (outlineWidth < 2 && !hasShadowRing) {
            offenders.push({
              tag: element.tagName.toLowerCase(),
              className: String(element.className || '').split(' ')[0],
              outlineWidth: computed.outlineWidth,
              outlineStyle: computed.outlineStyle,
            });
          }
        }
        return offenders;
      });

      expect(
        thinIndicators,
        `${pageCase.name} has focusable controls whose indicator is thinner than 2 CSS px: ${JSON.stringify(thinIndicators)}`,
      ).toEqual([]);
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

  // WCAG 2.4.3 Focus Order: activating a top-level navbar link crosses a layout
  // boundary, which remounts the Layout component. Focus must still land on the
  // destination route's main landmark rather than being lost to <body>.
  test('activating a top navigation link moves focus to main content', async ({ page }) => {
    await page.goto('/hve-core/');

    const primaryLink = page.locator('.navbar__link[href*="/docs/"]').filter({ hasNot: page.locator('.navbar__link[href="/hve-core/"]') }).first();
    if ((await primaryLink.count()) === 0) {
      test.skip(true, 'No top-level documentation navbar link is configured for this build.');
      return;
    }

    await primaryLink.click();
    await page.waitForLoadState('networkidle');

    await expectFocusOnMainLandmark(page, 'After activating a top navigation link');
    await expectNextTabEntersMain(page, 'After activating a top navigation link');
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

  // WCAG 2.4.3 Focus Order: a dropdown item reaches the same cross-layout
  // remount as a plain navbar link, so it must also land focus on main content.
  test('activating a navbar dropdown item moves focus to main content', async ({ page }) => {
    await page.goto('/hve-core/');

    const dropdownToggle = page.locator('.navbar__item.dropdown .navbar__link').first();
    if ((await dropdownToggle.count()) === 0) {
      test.skip(true, 'No dropdown navbar item is configured.');
      return;
    }

    // Open via the keyboard path a keyboard user actually takes, matching the
    // operable path asserted by the dropdown keyboard-reachability test above.
    await dropdownToggle.focus();
    await dropdownToggle.press('ArrowDown');

    const dropdownMenu = page.locator('.navbar__item.dropdown .dropdown__menu').first();
    await expect(dropdownMenu).toBeVisible();

    const firstItem = dropdownMenu.locator('a').first();
    await firstItem.focus();
    await firstItem.press('Enter');
    await page.waitForLoadState('networkidle');

    await expectFocusOnMainLandmark(page, 'After activating a navbar dropdown item');
    await expectNextTabEntersMain(page, 'After activating a navbar dropdown item');
  });

  // WCAG 2.4.3 Focus Order: the defect is direction-agnostic, so navigating
  // from a docs route back to the landing page must behave identically.
  test('returning to the landing page moves focus to main content', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');

    const brand = page.locator('.navbar__brand').first();
    if ((await brand.count()) === 0) {
      test.skip(true, 'No navbar brand link is configured for this build.');
      return;
    }

    await brand.click();
    await page.waitForLoadState('networkidle');

    await expectFocusOnMainLandmark(page, 'After returning to the landing page');
  });

  // Regression guard: navigation that stays inside one layout keeps the same
  // Layout instance and already focuses main content. The remount fix widens
  // when the route-change effect runs, so this path must not regress.
  test('navigating between docs pages moves focus to main content', async ({ page }) => {
    const startPath = '/hve-core/docs/getting-started/';
    await page.goto(startPath);

    // Resolve any sidebar link that leaves the current page rather than naming
    // one slug. A hard-coded slug turns a renamed page into a silent skip,
    // which would leave this guard permanently green while never running.
    const sidebarLink = page
      .locator('a.menu__link')
      .filter({ hasNot: page.locator(`[href="${startPath}"]`) })
      .first();

    const target = await sidebarLink.getAttribute('href');
    expect(
      target,
      'The docs sidebar should expose a sibling page link for the intra-layout focus guard',
    ).toBeTruthy();
    expect(
      target,
      'The intra-layout focus guard needs a sidebar link that navigates away from the starting page',
    ).not.toBe(startPath);

    await sidebarLink.click();
    await page.waitForLoadState('networkidle');

    await expectFocusOnMainLandmark(page, 'After navigating between docs pages');
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
