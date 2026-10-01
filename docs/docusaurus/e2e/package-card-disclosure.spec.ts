// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect, type Page } from '@playwright/test';
import { waitForHydration } from './_helpers/a11yInvariants';

const HOME = '/hve-core/';

async function openPackageContents(page: Page) {
  await page.goto(HOME);
  await waitForHydration(page);

  const card = page.locator('article[data-name="hve-core"]');
  const button = card.locator('button[aria-controls]');
  await expect(button).toHaveAccessibleName('Show package contents');
  const panelId = await button.getAttribute('aria-controls');

  expect(panelId).toBeTruthy();
  const panel = card.locator(`[id="${panelId}"]`);
  await expect(panel).toBeHidden();
  await button.click();
  await expect(button).toHaveAttribute('aria-expanded', 'true');
  await expect(panel).toBeVisible();

  return { card, button, panel };
}

const hasNoHorizontalScroll = () =>
  document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1;

test.describe('Package card disclosure', () => {
  test('exposes and dismisses the maturity tooltip accessibly', async ({ page }) => {
    await page.goto(HOME);
    await waitForHydration(page);

    const card = page.locator('article[data-name="hve-core"]');
    const badge = card.getByRole('link', { name: 'Stable', exact: true });
    const tooltip = card.getByRole('tooltip');
    const glossary =
      'Production-ready, fully supported, and generally available (GA) for everyday use.';

    await expect(badge).toHaveAccessibleDescription(glossary);
    await expect(tooltip).toBeHidden();

    await badge.focus();
    await expect(badge).toBeFocused();
    await expect(tooltip).toBeVisible();
    await expect(badge).toHaveCSS('outline-style', 'solid');

    await page.keyboard.press('Escape');
    await expect(badge).toBeFocused();
    await expect(tooltip).toBeHidden();

    await badge.evaluate((element) => (element as HTMLElement).blur());
    await badge.hover();
    await expect(tooltip).toBeVisible();
    await tooltip.hover();
    await expect(tooltip).toBeVisible();
  });

  test('supports keyboard interaction without following the stretched title link', async ({ page }) => {
    await page.goto(HOME);
    await waitForHydration(page);

    const card = page.locator('article[data-name="hve-core"]');
    const button = card.locator('button[aria-controls]');
    await expect(button).toHaveAccessibleName('Show package contents');
    const urlBefore = page.url();

    await button.focus();
    await page.keyboard.press('Enter');
    await expect(button).toHaveAttribute('aria-expanded', 'true');
    await expect(button).toBeFocused();
    expect(page.url()).toBe(urlBefore);

    const panelId = await button.getAttribute('aria-controls');
    expect(panelId).toBeTruthy();
    const panel = card.locator(`[id="${panelId}"]`);
    await expect(panel).toBeVisible();

    await page.keyboard.press('Space');
    await expect(button).toHaveAttribute('aria-expanded', 'false');
    await expect(button).toBeFocused();
    await expect(panel).toBeHidden();
    expect(page.url()).toBe(urlBefore);

    await page.keyboard.press('Enter');
    const agentsLink = panel.getByRole('link', { name: 'Agents' });
    await expect(agentsLink).toHaveAttribute('href', /\/hve-core\/docs\/reference\/agents\/?$/);
    await agentsLink.click();
    await expect(page).toHaveURL(/\/hve-core\/docs\/reference\/agents\/?$/);
  });

  for (const scenario of [
    { name: 'desktop', width: 1280, textScale: false, screenshot: true },
    { name: '996px breakpoint', width: 996, textScale: false, screenshot: false },
    { name: '768px breakpoint', width: 768, textScale: false, screenshot: false },
    { name: '320px reflow', width: 320, textScale: false, screenshot: true },
    { name: '200% text', width: 1280, textScale: true, screenshot: false },
  ]) {
    test(`keeps expanded contents usable at ${scenario.name}`, async ({ page }, testInfo) => {
      await page.setViewportSize({ width: scenario.width, height: 900 });
      const { card, button, panel } = await openPackageContents(page);

      if (scenario.textScale) {
        await page.evaluate(() => {
          document.documentElement.style.fontSize = '200%';
        });
      }

      await expect(button).toBeVisible();
      await expect(panel.getByRole('link', { name: 'View package overview' })).toBeVisible();
      expect(await page.evaluate(hasNoHorizontalScroll)).toBeTruthy();

      const panelId = await button.getAttribute('aria-controls');
      expect(panelId).toBeTruthy();
      const geometry = await card.evaluate((element, controlledPanelId) => {
        const buttonElement = element.querySelector('button');
        const panelElement = element.querySelector(
          `#${CSS.escape(controlledPanelId)}`,
        );
        if (!buttonElement || !panelElement) {
          return null;
        }

        const cardRect = element.getBoundingClientRect();
        const buttonRect = buttonElement.getBoundingClientRect();
        const panelRect = panelElement.getBoundingClientRect();
        return {
          panelWithinCard: panelRect.left >= cardRect.left - 1
            && panelRect.right <= cardRect.right + 1,
          controlsDoNotOverlap: buttonRect.bottom <= panelRect.top + 1,
          panelDoesNotClip: panelElement.scrollWidth <= panelElement.clientWidth + 1
            && panelElement.scrollHeight <= panelElement.clientHeight + 1,
        };
      }, panelId as string);

      expect(geometry).toEqual({
        panelWithinCard: true,
        controlsDoNotOverlap: true,
        panelDoesNotClip: true,
      });

      if (scenario.width === 320 || scenario.textScale) {
        const badge = card.getByRole('link', { name: 'Stable', exact: true });
        const tooltip = card.getByRole('tooltip');
        await badge.focus();
        await expect(tooltip).toBeVisible();

        const tooltipBox = await tooltip.boundingBox();
        expect(tooltipBox).not.toBeNull();
        expect(tooltipBox?.x).toBeGreaterThanOrEqual(0);
        expect((tooltipBox?.x ?? 0) + (tooltipBox?.width ?? 0))
          .toBeLessThanOrEqual(scenario.width + 1);
        expect(await page.evaluate(hasNoHorizontalScroll)).toBeTruthy();
      }

      if (scenario.screenshot) {
        const screenshotPath = testInfo.outputPath(
          `package-card-${scenario.width}px-expanded.png`,
        );
        await page.screenshot({ path: screenshotPath, fullPage: true });
        await testInfo.attach(`package-card-${scenario.width}px-expanded`, {
          path: screenshotPath,
          contentType: 'image/png',
        });
      }
    });
  }
});
