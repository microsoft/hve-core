// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { waitForHydration } from './_helpers/a11yInvariants';

const deckPath = '/hve-core/slides/hve-updates.html';
const tags = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];

async function openDeck(page: Page) {
  await page.goto(deckPath);
  await expect(page.locator('html')).toHaveAttribute('data-deck-ready', 'true');
}

async function expectReflow(page: Page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
  const clipped = await page.locator('section.present').evaluate(section =>
    [...section.querySelectorAll('*')].filter(node => {
      const box = node.getBoundingClientRect();
      return box.width > 0 && (box.left < -1 || box.right > innerWidth + 1);
    }).map(node => node.className));
  expect(clipped).toEqual([]);
}

test('gallery supports themes, reflow, skip navigation and deck links', async ({ page }) => {
  await page.goto('/hve-core/slides/');
  await waitForHydration(page);
  await page.getByRole('link', { name: 'Skip to main content', exact: true }).press('Enter');
  await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Open HVE Core updates', exact: true })).toBeFocused();
  await expect(page.getByRole('link', { name: 'Download HVE Core updates (HTML)' })).toHaveAttribute('download');
  for (const theme of ['light', 'dark']) {
    await page.evaluate(theme => document.documentElement.dataset.theme = theme, theme);
    await page.setViewportSize({ width: 320, height: 800 });
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true);
    expect((await new AxeBuilder({ page }).withTags(tags).analyze()).violations).toEqual([]);
  }
  await page.getByRole('link', { name: 'Open HVE Core updates', exact: true }).press('Enter');
  await expect(page.locator('html')).toHaveAttribute('data-deck-ready', 'true');
  await page.goBack();
  await expect(page.getByRole('heading', { name: 'Slides', exact: true })).toBeVisible();
});

test('deck keeps document semantics, scoped shortcuts and dialog focus', async ({ page }) => {
  await page.setViewportSize({ width: 1600, height: 900 });
  await openDeck(page);
  await expect(page.locator('[role="application"], .aria-status')).toHaveCount(0);
  await page.keyboard.press('s');
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await page.getByRole('main').focus();
  await page.keyboard.press('s');
  await expect(page.getByRole('dialog')).toHaveAccessibleName('Sources / HVE Core updates');
  await expect(page.getByRole('button', { name: 'Close dialog' })).toBeFocused();
  await page.keyboard.press('Shift+Tab');
  expect(await page.locator('dialog').evaluate(node => node.contains(document.activeElement))).toBe(true);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('main')).toBeFocused();
  await page.getByRole('button', { name: 'Next slide', exact: true }).press('Enter');
  await expect(page.locator('#opening')).toHaveAttribute('inert', '');
  await expect(page.getByRole('heading', { name: 'HVE Core updates', exact: true })).toHaveCount(0);
  await expect(page.locator('#announcement')).toHaveText('Slide 2 of 26. Changes since April');
  await expect(page.locator('#slide-count')).toHaveAttribute('aria-live', 'off');
  await page.getByRole('button', { name: 'Slides', exact: true }).press('Enter');
  await page.getByRole('button', { name: /Try a skill on your next task/ }).press('Enter');
  await expect(page.getByRole('button', { name: 'Next slide', exact: true })).toBeDisabled();
  await expect(page.locator('dialog')).not.toBeVisible();
  expect(await page.evaluate(() => !!document.activeElement?.closest('[inert]'))).toBe(false);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('#motion-button')).toBeDisabled();
  await expect(page.locator('#motion-button')).toHaveAttribute('aria-pressed', 'false');
  await page.setViewportSize({ width: 320, height: 800 });
  for (const view of ['sources', 'notes', 'help']) {
    await page.locator(`[data-dialog="${view}"]`).press('Enter');
    await expect(page.locator('#dialog-content')).toHaveAttribute('tabindex', '0');
    expect((await new AxeBuilder({ page }).include('dialog').analyze()).violations).toEqual([]);
    await page.locator('#dialog-content').focus();
    if (view === 'help') {
      await page.keyboard.press('PageDown');
      await expect.poll(() => page.locator('#dialog-content').evaluate(node => node.scrollTop)).toBeGreaterThan(0);
    }
    await page.keyboard.press('Escape');
  }
});

test('every slide and walkthrough reflows with increased text spacing', async ({ page }) => {
  test.setTimeout(120_000);
  await page.setViewportSize({ width: 320, height: 800 });
  await openDeck(page);
  await expect(page.getByRole('button', { name: 'Reading view' })).toHaveAttribute('aria-pressed', 'true');
  await page.addStyleTag({ content: '* { line-height: 1.5 !important; letter-spacing: .12em !important; word-spacing: .16em !important; } p { margin-bottom: 2em !important; }' });
  const ids = await page.locator('.slides > section').evaluateAll(nodes => nodes.map(node => node.id));
  for (const id of ids) {
    await page.evaluate(id => location.hash = `#/${id}`, id);
    await expect(page.locator('section.present')).toHaveAttribute('id', id);
    await expectReflow(page);
    expect((await new AxeBuilder({ page }).include('section.present').analyze()).violations).toEqual([]);
    const next = page.locator('section.present [data-action="next"]');
    if (await next.count()) {
      while (await next.isEnabled()) {
        await next.press('Enter');
        await expectReflow(page);
      }
      await page.locator('section.present [data-action="reset"]').press('Enter');
      await expect(page.locator('section.present [data-action="back"]')).toBeDisabled();
    }
  }
});

test('reading mode retains diagram meaning and visible focus', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openDeck(page);
  await page.goto(`${deckPath}#/rpi-demo`);
  await expect(page.locator('html')).toHaveAttribute('data-deck-ready', 'true');
  const next = page.locator('section.present [data-action="next"]');
  while (await page.locator('section.present .demo-body').getAttribute('data-component') !== 'graph') {
    await expect(next).toBeEnabled();
    await next.press('Enter');
  }
  const description = page.locator('section.present .graph-description');
  await description.locator('summary').press('Enter');
  await expect(description).toHaveAttribute('open', '');
  expect(await description.locator('li').count()).toBeGreaterThan(2);
  await expectReflow(page);
  await page.setViewportSize({ width: 1600, height: 900 });
  await expect(page.locator('#reading-button')).toHaveAttribute('aria-pressed', 'false');
  await page.locator('#reading-button').press('Enter');
  await expect(page.locator('#reading-button')).toHaveAttribute('aria-pressed', 'true');
  await expect(page.locator('#reading-button')).toBeFocused();
});

test('reading view permits vertical touch scrolling', async ({ browser }) => {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  try {
    await page.goto(`http://127.0.0.1:3001${deckPath}#/timeline`);
    await expect(page.locator('html')).toHaveAttribute('data-deck-ready', 'true');
    await expect(page.locator('.reveal')).toHaveCSS('touch-action', 'auto');
    const session = await page.context().newCDPSession(page);
    await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 180, y: 700 }] });
    for (const position of [650, 550, 450, 350]) {
      await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 180, y: position }] });
    }
    await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(0);
    await expect(page.locator('section.present')).toHaveAttribute('id', 'timeline');
  } finally {
    await page.close();
  }
});
