// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { SITE_PAGES, openSearchWidget, visitInvariantPage, waitForHydration } from './_helpers/a11yInvariants';

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
      // At rest the upstream widget has not attached, so the input owns no
      // popup. It must therefore NOT advertise a combobox: announcing
      // "combobox, collapsed" for a control with no aria-autocomplete,
      // aria-controls, or aria-owns describes a widget that does not exist.
      // Combobox-only attributes are equally not allowed without the role
      // (axe aria-allowed-attr), so both are absent together.
      await expect(searchInput).not.toHaveAttribute('role', 'combobox');
      await expect(searchInput).not.toHaveAttribute('aria-expanded', /.*/);
      await expect(searchInput).not.toHaveAttribute('aria-activedescendant', /.*/);
      // The input is named directly rather than by reference, so no heading is
      // injected into the banner to serve as a label target.
      await expect(searchInput).not.toHaveAttribute('aria-labelledby', /.*/);
      await expect(searchInput).toHaveAttribute('aria-label', /\S/);
      const describedBy = await searchInput.getAttribute('aria-describedby');
      expect(describedBy).toBeTruthy();
    });
  }

  test('names the input directly without injecting a heading into the banner', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');
    await waitForHydration(page);

    const searchInput = page.locator('.navbar__search-input').first();
    await expect(searchInput).toBeVisible();
    // Focus triggers the swizzle's sync(), which is where the heading used to be
    // injected. Asserting after that point is what makes the absence meaningful.
    await searchInput.click();

    // A visually hidden h2 in the banner disturbed the heading outline on every
    // page purely to name the input by reference.
    await expect(page.locator('#search-input-heading')).toHaveCount(0);
    await expect(page.locator('.navbar__search h2')).toHaveCount(0);

    // The accessible name must still resolve, now from the direct label.
    const accessibleName = await searchInput.evaluate(
      (node) => (node as HTMLInputElement).getAttribute('aria-label'),
    );
    expect(accessibleName?.trim().length ?? 0).toBeGreaterThan(0);

    // The description node remains and must stay clipped to a 1px box. A broken
    // hide (e.g. assigning a style object to HTMLElement.style, which is a no-op)
    // would render full-size text in the banner.
    const node = page.locator('#search-shortcut-description');
    await expect(node).toHaveCount(1);
    const box = await node.boundingBox();
    expect(box, '#search-shortcut-description should be attached to the DOM').not.toBeNull();
    expect(box!.width).toBeLessThanOrEqual(1);
    expect(box!.height).toBeLessThanOrEqual(1);
  });

  async function openResults(page: import('@playwright/test').Page) {
    await page.goto('/hve-core/docs/getting-started/');
    await waitForHydration(page);

    // Gate on the upstream-only signal. role="combobox" is supplied by this
    // repository's own swizzle at rest, so waiting for it proves nothing about
    // whether the upstream widget has attached and can render a popup.
    const searchInput = await openSearchWidget(page);
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

  test('search results are announced once per settled query, not once per keystroke', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');
    await waitForHydration(page);

    const searchInput = await openSearchWidget(page);

    // Record every mutation of the status region with the time it happened.
    // Reading only the final value cannot detect this defect: the last message
    // is correct either way, and the problem is the queue of announcements a
    // screen-reader user listens through on the way there. Counting writes alone
    // is also not enough, because duplicate suppression can hold the count down
    // while every keystroke still schedules its own announcement. The timings
    // are what distinguish a quiet period that coalesces typing from one that
    // expires between keystrokes.
    await page.evaluate(() => {
      const status = document.querySelector('[role="status"]');
      if (!status) {
        return;
      }
      (window as unknown as { __statusWrites: { text: string; at: number }[] }).__statusWrites = [];
      const observer = new MutationObserver(() => {
        const text = (status.textContent || '').trim();
        if (text) {
          (window as unknown as { __statusWrites: { text: string; at: number }[] }).__statusWrites.push({
            text,
            at: performance.now(),
          });
        }
      });
      observer.observe(status, { childList: true, characterData: true, subtree: true });
    });

    // Type character by character. The interval must sit between the old quiet
    // period and the current one: slower than the old value, so the old
    // implementation fires a timer between every character, and faster than the
    // current value, so the current implementation coalesces the whole sequence.
    const TYPING_INTERVAL_MS = 160;
    // The quiet period is 400 ms and the write delay is 60 ms. Compare against a
    // floor below that budget so timer resolution and event-loop scheduling
    // cannot fail an otherwise conformant run, while still sitting well above
    // the typing interval.
    const QUIET_FLOOR_MS = 250;

    await searchInput.pressSequentially('getting started', { delay: TYPING_INTERVAL_MS });
    const lastInputAt = await page.evaluate(() => performance.now());
    await expect(page.locator('[role="listbox"] [role="option"]').first()).toBeVisible({ timeout: 15000 });
    await page.waitForTimeout(1200);

    const writes = await page.evaluate(
      () => (window as unknown as { __statusWrites: { text: string; at: number }[] }).__statusWrites ?? [],
    );
    const rendered = JSON.stringify(writes);

    expect(writes.length, `expected at least one announcement, got ${rendered}`).toBeGreaterThan(0);
    expect(
      writes.length,
      `A settled query should produce one announcement, not one per keystroke: ${rendered}`,
    ).toBeLessThanOrEqual(3);

    // Every write costs a full quiet period that no keystroke interrupted, so
    // consecutive writes cannot be closer together than that period. Under a
    // quiet period shorter than the typing interval the writes arrive at roughly
    // the typing cadence, which this comparison rejects.
    const gaps = writes.slice(1).map((write, index) => write.at - writes[index].at);
    for (const gap of gaps) {
      expect(
        gap,
        `Announcements ${Math.round(gap)} ms apart mean the quiet period expired between keystrokes typed ${TYPING_INTERVAL_MS} ms apart: ${rendered}`,
      ).toBeGreaterThanOrEqual(QUIET_FLOOR_MS);
    }

    // No announcement may reach the user before they stop typing. Checking the
    // earliest write rather than the last is what enforces that: a run that
    // announces once mid-sequence and once after settling satisfies both the gap
    // comparison above and any final-write check, while still interrupting the
    // user part-way through the query. Because the observer records writes in
    // order, this also covers the final write.
    expect(
      writes[0].at - lastInputAt,
      `An announcement landed before the quiet period could elapse after the last keystroke: ${rendered}`,
    ).toBeGreaterThanOrEqual(QUIET_FLOOR_MS);

    expect(writes[writes.length - 1].text).toMatch(/No results|\d+ results?/i);
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

  test('Escape clears combobox state when the query returns no results', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/');
    await waitForHydration(page);

    const searchInput = await openSearchWidget(page);
    // A query with no matches renders no footer link. Escape handling used to sit
    // below a gate that returned early without one, so cleanup was skipped in
    // exactly this state.
    // cspell:disable-next-line
    await searchInput.fill('zzzzqqqxnotarealdocumentterm');
    await page.waitForTimeout(600);

    await searchInput.press('Escape');

    await expect(searchInput).not.toHaveAttribute('aria-activedescendant', /.*/);
    await expect(page.locator('[role="listbox"] [role="option"]')).toHaveCount(0);
  });
});
