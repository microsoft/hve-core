// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect, type Page } from '@playwright/test';

// WCAG 1.4.10 Reflow: content must stay usable when the viewport is scaled.
//
// This spec emulates browser page zoom via deviceScaleFactor, which scales the
// whole layout rather than text alone, so it verifies 1.4.10 Reflow at
// intermediate zoom levels rather than 1.4.4 Resize Text. The reflow spec covers
// the 320 CSS px endpoint; this one covers the zoom steps in between, where the
// reported clipping occurred.
//
// Browser page zoom scales the CSS pixel against the device pixel, so a 1280
// device-pixel window at 200% zoom lays out as a 640 CSS pixel viewport at a
// device scale factor of 2. That equivalence makes real browser zoom
// reproducible from Playwright context options alone, without the CDP
// text-scale emulation that never reproduced the reported symptom.
//
// The reported defect was the navbar search placeholder being clipped to
// "Sear" at 200%: the field narrows while the Ctrl+K badges inside it do not
// yield, leaving less room for the placeholder than the placeholder needs.
const ZOOM_LEVELS = [
  { label: '100%', width: 1280, height: 768, deviceScaleFactor: 1 },
  { label: '150%', width: 853, height: 512, deviceScaleFactor: 1.5 },
  { label: '200%', width: 640, height: 384, deviceScaleFactor: 2 },
  { label: '250%', width: 512, height: 307, deviceScaleFactor: 2.5 },
];

interface PlaceholderFit {
  present: boolean;
  collapsed: boolean;
  requiredWidth: number;
  usableWidth: number;
  badgeCount: number;
}

// Measures the space actually available for placeholder text against the width
// that text needs. A badge rendered inside the field reduces the available
// space, so the badge edge is the right boundary whenever one is present.
async function measurePlaceholderFit(page: Page): Promise<PlaceholderFit> {
  // Focus through a real click rather than a programmatic focus() inside the
  // page.evaluate below. The SearchBar swizzle wraps the input's focus method to
  // suppress the upstream package's index-load refocus (the WCAG 2.1.2 guard
  // asserted in search-keyboard.spec.ts), and that guard drops any focus()
  // issued while no user gesture is in flight. A programmatic focus() therefore
  // leaves the field at its collapsed at-rest width, so the measurement below
  // described a state no user ever types into. Measured on the built site: the
  // field stays 46 CSS px under programmatic focus and expands to 144 CSS px on
  // a real click at 250% zoom.
  const input = page.locator('input.navbar__search-input').first();
  if ((await input.count()) > 0) {
    await input.click();
    await expect(input).toBeFocused();
  }

  return page.evaluate(() => {
    const input = document.querySelector<HTMLInputElement>('input.navbar__search-input');
    if (!input) {
      return {
        present: false,
        collapsed: false,
        requiredWidth: 0,
        usableWidth: 0,
        badgeCount: 0,
      };
    }

    const rect = input.getBoundingClientRect();
    const computed = window.getComputedStyle(input);

    const probe = document.createElement('span');
    probe.style.cssText = `position:absolute;visibility:hidden;white-space:pre;font:${computed.font}`;
    probe.textContent = input.getAttribute('placeholder') ?? '';
    document.body.appendChild(probe);
    const requiredWidth = probe.getBoundingClientRect().width;
    probe.remove();

    const badgeEdges = Array.from(document.querySelectorAll('.navbar__search kbd'))
      .map((badge) => badge.getBoundingClientRect())
      .filter((badge) => badge.width > 0)
      .map((badge) => badge.left);

    const paddingLeft = Number.parseFloat(computed.paddingLeft) || 0;
    const paddingRight = Number.parseFloat(computed.paddingRight) || 0;
    const rightBoundary = badgeEdges.length > 0
      ? Math.min(Math.min(...badgeEdges), rect.right - paddingRight)
      : rect.right - paddingRight;

    return {
      present: true,
      collapsed: rect.width < 48,
      requiredWidth,
      usableWidth: rightBoundary - (rect.left + paddingLeft),
      badgeCount: badgeEdges.length,
    };
  });
}

test.describe('Browser page zoom reflow (WCAG 1.4.10)', () => {
  for (const level of ZOOM_LEVELS) {
    test(`navbar search placeholder is not clipped at ${level.label} browser zoom`, async ({ browser }) => {
      const context = await browser.newContext({
        viewport: { width: level.width, height: level.height },
        deviceScaleFactor: level.deviceScaleFactor,
      });
      const page = await context.newPage();

      try {
        await page.goto('/hve-core/', { waitUntil: 'domcontentloaded' });
        await page.waitForFunction(
          () => document.documentElement.dataset.hasHydrated === 'true',
          undefined,
          { timeout: 30000 },
        );

        const fit = await measurePlaceholderFit(page);
        expect(fit.present, 'the navbar search input should render').toBe(true);
        expect(fit.collapsed, `the search field should expand on focus at ${level.label}`).toBe(false);

        // The reported defect was badges crowding the placeholder, and the fix
        // removes them from layout below the theme's 996 px breakpoint. Every
        // zoom level above 100% lays out below that breakpoint, so without this
        // assertion the badge boundary is simply absent and the measurement no
        // longer covers the condition the test names. Assert the badge state
        // directly so a regression that restores them is detected.
        if (level.width <= 996) {
          expect(
            fit.badgeCount,
            `at ${level.label} the shortcut badges must be removed from layout so they cannot crowd the placeholder`,
          ).toBe(0);
        } else {
          expect(
            fit.badgeCount,
            `at ${level.label} the shortcut badges should still be rendered`,
          ).toBeGreaterThan(0);
        }

        expect(
          Math.round(fit.usableWidth),
          `at ${level.label} the placeholder needs ${Math.round(fit.requiredWidth)} CSS px but only ${Math.round(fit.usableWidth)} CSS px is available`,
        ).toBeGreaterThanOrEqual(Math.round(fit.requiredWidth));

        // SC 1.4.10 also forbids losing content to a second scroll axis.
        const horizontalScroll = await page.evaluate(
          () => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
        );
        expect(horizontalScroll, `${level.label} should not introduce horizontal scrolling`).toBe(false);
      } finally {
        await context.close();
      }
    });
  }
});
