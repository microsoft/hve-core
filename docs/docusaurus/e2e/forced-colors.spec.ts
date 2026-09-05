// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { PAGES } from './_helpers/pages';
import { openSearchWidget, waitForHydration } from './_helpers/a11yInvariants';

const WCAG_TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'];

test.use({ contextOptions: { forcedColors: 'active' } });

test.describe('Forced-colors accessibility regression locks', () => {
  for (const { name, path } of PAGES) {
    test(`${name} passes an axe scan in forced-colors mode`, async ({ page }) => {
      // An axe scan is a single CPU-bound `page.evaluate` over the whole
      // document, so its cost depends on machine load rather than on this
      // page. `site-crawl.spec.ts` already budgets 60s for the same work; this
      // suite did the same scan at the default 30s and sat close enough to the
      // limit to time out when the suite ran heavier.
      test.setTimeout(60000);
      await page.goto(path, { waitUntil: 'domcontentloaded' });
      await waitForHydration(page);

      const results = await new AxeBuilder({ page }).withTags(WCAG_TAGS).analyze();
      expect(results.violations).toEqual([]);
    });
  }

  test('keeps the selected search result distinguishable from its selection background', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/', { waitUntil: 'domcontentloaded' });
    await waitForHydration(page);

    // Precondition: without emulation actually in effect the comparisons below
    // would be measuring ordinary author colors and would pass trivially.
    const emulationActive = await page.evaluate(
      () => window.matchMedia('(forced-colors: active)').matches,
    );
    expect(emulationActive, 'forced-colors emulation must be in effect for this check to mean anything').toBe(true);

    const searchInput = await openSearchWidget(page);
    await searchInput.fill('getting');
    await expect(page.locator('[role="listbox"] [role="option"]').first()).toBeVisible({ timeout: 15000 });
    await searchInput.press('ArrowDown');
    await expect(page.locator('[role="option"][aria-selected="true"]').first()).toHaveCount(1);

    // System color keywords resolve from the operating system palette, so the
    // absolute values are unpredictable. The contract is expressed as
    // inequalities: the cue must not be painted in the color it sits on.
    const resolved = await page.evaluate(() => {
      const node = document.querySelector('[role="option"][aria-selected="true"]');
      if (!node) {
        return null;
      }
      const style = window.getComputedStyle(node);
      return {
        background: style.backgroundColor,
        foreground: style.color,
        outline: style.outlineColor,
        outlineWidth: style.outlineWidth,
      };
    });

    expect(resolved, 'a selected option must be present').not.toBeNull();
    expect(
      resolved!.outline,
      `The selection outline must not resolve to the selection background (${JSON.stringify(resolved)})`,
    ).not.toBe(resolved!.background);
    expect(
      resolved!.foreground,
      `The selected text must not resolve to the selection background (${JSON.stringify(resolved)})`,
    ).not.toBe(resolved!.background);
    expect(
      Number.parseFloat(resolved!.outlineWidth),
      'The selection outline must have a non-zero width',
    ).toBeGreaterThan(0);
  });
});
