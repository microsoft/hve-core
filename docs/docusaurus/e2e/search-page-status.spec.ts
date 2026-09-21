// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import { waitForHydration } from './_helpers/a11yInvariants';

test.describe('Search page status announcements', () => {
  test('announces matching and non-matching query counts', async ({ page }) => {
    await page.goto('/hve-core/search/?q=agent');
    await waitForHydration(page);

    const status = page.locator('#search-results-status[role="status"]');
    await expect(status).toHaveAttribute('aria-live', 'polite');
    await expect(status).toHaveText(/\d+ document(?:s)? found/, { timeout: 15000 });

    // The region is owned by the component. It was previously appended to <body>
    // as a singleton and removed unconditionally on unmount, so a second mount
    // left the survivor writing to a detached node. Ownership is what closes that
    // defect: a single node, rendered by the component rather than parked on the
    // document body. Its position relative to the main landmark is not asserted,
    // because a live region announces from anywhere in the document and axe's
    // landmark-containment rule exempts role="status" and aria-live regions.
    await expect(status).toHaveCount(1);
    await expect(page.locator('body > #search-results-status')).toHaveCount(0);

    const searchInput = page.locator('input[name="q"]');
    // cspell:disable-next-line -- deliberate nonsense token so the query matches nothing
    await searchInput.fill('zzzzzzzzqqqq');
    await expect(status).toHaveText(/No documents found/, { timeout: 15000 });
  });

  test('never announces a definitive no-results count while a query is unresolved', async ({ page }) => {
    // Waiting for the final text alone cannot detect a premature announcement:
    // the end state is correct either way. Record every distinct value the live
    // region publishes, then assert that a query which does have results never
    // passed through a definitive "no documents" claim on the way there.
    await page.goto('/hve-core/search/');
    await waitForHydration(page);

    const status = page.locator('#search-results-status[role="status"]');
    await expect(status).toHaveCount(1);

    await page.evaluate(() => {
      const node = document.querySelector('#search-results-status');
      if (!node) {
        return;
      }
      const seen: string[] = [];
      (window as unknown as { __statusLog: string[] }).__statusLog = seen;
      new MutationObserver(() => {
        const text = (node.textContent ?? '').trim();
        if (text && seen[seen.length - 1] !== text) {
          seen.push(text);
        }
      }).observe(node, { childList: true, characterData: true, subtree: true });
    });

    await page.locator('input[name="q"]').fill('agent');
    await expect(status).toHaveText(/\d+ document(?:s)? found/, { timeout: 15000 });

    const announcements = await page.evaluate(
      () => (window as unknown as { __statusLog: string[] }).__statusLog ?? [],
    );
    const prematureNoResults = announcements.filter((text) => /No documents found/i.test(text));

    expect(
      prematureNoResults,
      `the status announced no results for a query that has results: ${JSON.stringify(announcements)}`,
    ).toEqual([]);
  });
});
