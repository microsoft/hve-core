// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';

test.describe('Table accessibility regression locks', () => {
  const captionCases = [
    {
      route: '/hve-core/docs/customization/build-system/',
      caption: 'Frontmatter schemas and the files they validate',
    },
    {
      route: '/hve-core/docs/agents/code-review/',
      caption: 'Review perspectives and the subagents that own each lane',
    },
    {
      route: '/hve-core/docs/agents/accessibility/accessibility-reviewer/',
      caption: 'Review modes and the inputs each mode accepts',
    },
  ] as const;

  for (const { route, caption } of captionCases) {
    test(`${caption} is wrapped in a focusable table wrapper with column scopes`, async ({ page }) => {
      await page.goto(route, { waitUntil: 'domcontentloaded' });

      const captionLocator = page.locator('caption').filter({ hasText: caption }).first();
      await expect(captionLocator).toBeVisible();

      const table = page.locator('table').filter({ has: captionLocator }).first();
      await expect(table).toBeVisible();

      const wrapper = page.locator('.tableWrapper').filter({ has: table }).first();
      await expect(wrapper).toBeVisible();
      await expect(wrapper).toHaveAttribute('tabindex', '0');
      await expect(table).not.toHaveAttribute('tabindex');

      const headerCells = table.locator('thead th');
      await expect(headerCells.first()).toBeVisible();
      const headerCount = await headerCells.count();
      expect(headerCount).toBeGreaterThan(0);

      for (let index = 0; index < headerCount; index += 1) {
        await expect(headerCells.nth(index)).toHaveAttribute('scope', 'col');
      }
    });
  }

  test('table wrappers do not add landmarks that collide on pages with several tables', async ({ page }) => {
    // A focusable scroll container needs an accessible name, but naming it with
    // role="region" makes every table a landmark sharing one name, which axe
    // reports as landmark-unique and which fills a screen reader's landmark
    // list with indistinguishable entries.
    await page.goto('/hve-core/docs/', { waitUntil: 'domcontentloaded' });

    const wrappers = page.locator('.tableWrapper');
    const wrapperCount = await wrappers.count();
    expect(wrapperCount).toBeGreaterThan(1);

    const roles = await wrappers.evaluateAll((elements) =>
      elements.map((element) => element.getAttribute('role')),
    );
    expect(roles.every((role) => role !== 'region')).toBe(true);
  });

  test('an uncaptioned data table exposes an accessible name via aria-labelledby', async ({ page }) => {    await page.goto('/hve-core/docs/getting-started/tts-voiceover/', { waitUntil: 'domcontentloaded' });

    const uncaptionedTable = page.locator('table[aria-labelledby]').filter({ hasNot: page.locator('caption') }).first();
    await expect(uncaptionedTable).toBeVisible();

    const labelledBy = await uncaptionedTable.getAttribute('aria-labelledby');
    expect(labelledBy).toBeTruthy();

    const labelledByTarget = page.locator(`#${labelledBy}`).first();
    await expect(labelledByTarget).toBeVisible();
    const tagName = await labelledByTarget.evaluate((element) => element.tagName.toLowerCase());
    expect(tagName).toMatch(/^h[1-6]$/);
  });
});
