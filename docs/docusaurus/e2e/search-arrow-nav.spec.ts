// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect, type Page } from '@playwright/test';
import { openSearchWidget, waitForHydration } from './_helpers/a11yInvariants';

// Locks the user-visible outcome of arrow navigation in the navbar search
// dropdown: focus stays on the combobox input and the visible highlight moves
// through the options. search-keyboard.spec.ts covers the ARIA wiring and the
// footer hand-off; this spec covers the visual highlight, which that spec does
// not assert.

async function activeState(page: Page) {
  return page.evaluate(() => {
    const input = document.querySelector('input.navbar__search-input') as HTMLInputElement | null;
    const lb = document.querySelector('[role="listbox"]');
    const opts = lb ? Array.from(lb.querySelectorAll('[role="option"]')) : [];
    // The highlight lives on the upstream hashed "cursor" class for result
    // options, and on this repository's own class once the roving position
    // reaches the external footer link. Querying only the upstream class would
    // report "no highlight" for the footer, which is a state this branch
    // introduces and therefore must be able to observe.
    const highlighted = lb
      ? lb.querySelector('[class*="cursor"], .search-footer-active')
        ?? document.querySelector('.search-footer-active')
      : null;
    return {
      activeDescendant: input?.getAttribute('aria-activedescendant') ?? null,
      optionCount: opts.length,
      highlightedText: highlighted ? (highlighted.textContent || '').trim().slice(0, 40) : null,
      focusIsInput: document.activeElement === input,
    };
  });
}

test('navbar search: ArrowDown/ArrowUp navigate the dropdown list', async ({ page }) => {
  await page.goto('/hve-core/docs/getting-started/');
  await page.waitForLoadState('domcontentloaded');
  await waitForHydration(page);

  const input = await openSearchWidget(page);
  await input.fill('agent');
  await page.locator('[role="listbox"]').first().waitFor({ state: 'visible', timeout: 15000 });

  const steps: Array<Record<string, unknown>> = [];
  steps.push({ key: 'start', ...(await activeState(page)) });

  for (let n = 0; n < 5; n += 1) {
    await input.press('ArrowDown');
    await page.waitForTimeout(120);
    steps.push({ key: 'ArrowDown#' + (n + 1), ...(await activeState(page)) });
  }
  for (let n = 0; n < 2; n += 1) {
    await input.press('ArrowUp');
    await page.waitForTimeout(120);
    steps.push({ key: 'ArrowUp#' + (n + 1), ...(await activeState(page)) });
  }

  const downs = steps.filter((s) => String(s.key).startsWith('ArrowDown'));

  // User-visible criteria for "arrows navigate the list":
  // 1. Focus must stay on the combobox input (baseline bug: it fell to <body>).
  const focusEscapes = downs.filter((s) => s.focusIsInput !== true).map((s) => s.key);
  // 2. The visible highlight must move through options (baseline bug: it stuck).
  const distinctHighlights = new Set(downs.map((s) => s.highlightedText).filter(Boolean));

  expect(
    focusEscapes,
    `focus must stay on the search input while arrowing (not fall to <body>): ${focusEscapes.join(', ')}`,
  ).toEqual([]);
  expect(
    distinctHighlights.size,
    `the visible option highlight must move as ArrowDown is pressed; observed ${JSON.stringify([...distinctHighlights])}`,
  ).toBeGreaterThanOrEqual(2);
});
