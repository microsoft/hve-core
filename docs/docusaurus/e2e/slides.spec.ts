// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';
import path from 'node:path';
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

  // A container that hides its own overflow discards content outright, which
  // horizontal page width alone cannot detect.
  const truncated = await page.locator('section.present').evaluate(section =>
    [...section.querySelectorAll('*')].filter(node => {
      const style = getComputedStyle(node);
      const hides = (value: string) => value === 'hidden' || value === 'clip';
      if (!hides(style.overflowX) && !hides(style.overflowY)) return false;
      // A text field scrolls its own value and the caret still reaches all of
      // it, so an overflowing field is not discarded content.
      if (['INPUT', 'TEXTAREA', 'SELECT'].includes(node.tagName)) return false;
      // Visually hidden text clips deliberately and stays in the accessibility
      // tree, so a collapsed box is the intended pattern rather than lost content.
      const collapsed = node.clientWidth <= 1 && node.clientHeight <= 1;
      if (collapsed || style.clip === 'rect(0px, 0px, 0px, 0px)' || style.clipPath === 'inset(50%)') return false;
      return (hides(style.overflowX) && node.scrollWidth > node.clientWidth + 1)
        || (hides(style.overflowY) && node.scrollHeight > node.clientHeight + 1);
    }).map(node => node.className || node.tagName));
  expect(truncated).toEqual([]);
}

// Controls must not be hidden behind, or stacked on top of, slide content once
// zoom shrinks the CSS viewport. Sampling the full rectangle rather than one
// centre point catches a control that is only partially covered.
async function expectNoOverlap(page: Page) {
  const overlapping = await page.evaluate(() => {
    const inset = 2;
    return [...document.querySelectorAll('.deck-controls button, section.present [data-action]')]
      .filter(node => node.getBoundingClientRect().width > 0)
      .filter(node => {
        const box = node.getBoundingClientRect();
        const points: [number, number][] = [
          [box.left + box.width / 2, box.top + box.height / 2],
          [box.left + inset, box.top + inset],
          [box.right - inset, box.top + inset],
          [box.left + inset, box.bottom - inset],
          [box.right - inset, box.bottom - inset],
        ];
        return points.some(([x, y]) => {
          // Reflow permits vertical scrolling, so a control below the fold is
          // reachable rather than obscured. Only sample points on screen.
          if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) return false;
          const hit = document.elementFromPoint(x, y);
          return hit !== null && !node.contains(hit) && !hit.contains(node);
        });
      })
      .map(node => node.getAttribute('id') || node.getAttribute('data-action') || node.className);
  });
  expect(overlapping).toEqual([]);
}

// A focused control the user cannot fully see is not operable, even when the
// page reports no horizontal overflow.
async function expectFullyVisible(page: Page, target: ReturnType<Page['getByRole']>) {
  const visible = await target.evaluate(element => {
    const box = element.getBoundingClientRect();
    return box.width > 0 && box.height > 0
      && box.top >= -1 && box.left >= -1
      && box.bottom <= innerHeight + 1 && box.right <= innerWidth + 1;
  });
  expect(visible).toBe(true);
}

async function expectFocusRingVisible(page: Page, target: ReturnType<Page['getByRole']>) {
  const outline = await target.evaluate(element => {
    const style = getComputedStyle(element);
    return { style: style.outlineStyle, width: parseFloat(style.outlineWidth) };
  });
  expect(outline.style).not.toBe('none');
  expect(outline.width).toBeGreaterThanOrEqual(2);
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
  await expect(page.getByRole('main', { name: 'Presentation' })).toHaveAttribute('aria-roledescription', 'presentation');
  await expect(page.locator('section.present')).toHaveAttribute('role', 'group');
  await expect(page.locator('section.present')).toHaveAttribute('aria-roledescription', 'slide');
  await expect(page.locator('section.present')).toHaveAttribute('aria-label', 'HVE Core updates, 1 of 26');
  await expect(page.locator('section.present')).toHaveAttribute('aria-current', 'page');
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
  await expect(page.locator('#opening')).toHaveAttribute('aria-hidden', 'true');
  await expect(page.locator('#opening')).not.toHaveAttribute('aria-current', 'page');
  await expect(page.locator('section.present')).toHaveAttribute('aria-label', 'Changes since April, 2 of 26');
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

test('presentation controls follow a reversible order without keyboard traps', async ({ page }) => {
  await page.setViewportSize({ width: 1600, height: 900 });
  await openDeck(page);

  const presenterOrder = [
    'overview-button',
    'sources',
    'notes',
    'help',
    'reading-button',
    'motion-button',
    'fullscreen-button',
    'next-slide',
  ];
  await page.locator('#overview-button').focus();
  const forwardOrder: string[] = [];
  for (const expected of presenterOrder) {
    forwardOrder.push(await page.evaluate(() => {
      const active = document.activeElement as HTMLElement | null;
      return active?.id || active?.dataset.dialog || '';
    }));
    expect(await page.evaluate(() => document.activeElement?.closest('[inert]') === null)).toBe(true);
    if (expected !== presenterOrder[presenterOrder.length - 1]) await page.keyboard.press('Tab');
  }
  expect(forwardOrder).toEqual(presenterOrder);

  const backwardOrder: string[] = [];
  for (const expected of [...presenterOrder].reverse()) {
    backwardOrder.push(await page.evaluate(() => {
      const active = document.activeElement as HTMLElement | null;
      return active?.id || active?.dataset.dialog || '';
    }));
    if (expected !== presenterOrder[0]) await page.keyboard.press('Shift+Tab');
  }
  expect(backwardOrder).toEqual([...presenterOrder].reverse());

  const sources = page.locator('[data-dialog="sources"]');
  await sources.press('Enter');
  const dialog = page.getByRole('dialog');
  const close = page.getByRole('button', { name: 'Close dialog' });
  const lastDialogControl = dialog.locator('button:visible, a[href]:visible, summary:visible, [tabindex]:not([tabindex="-1"]):visible').last();
  await expect(close).toBeFocused();
  await page.keyboard.press('Shift+Tab');
  await expect(lastDialogControl).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(close).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(sources).toBeFocused();

  const overview = page.locator('#overview-button');
  await overview.press('Enter');
  await page.getByRole('button', { name: /Changes since April/ }).press('Enter');
  await expect(overview).toBeFocused();
  await expect(page.locator('section.present')).toHaveAttribute('id', 'timeline');
  expect(await page.evaluate(() => document.activeElement?.closest('[inert]') === null)).toBe(true);
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

// WCAG 1.4.10 at 200% browser zoom. Browser page zoom scales the CSS pixel
// against the device pixel, so a 1280 device-pixel window at 200% lays out as a
// 640 CSS pixel viewport at a device scale factor of 2. This is a distinct
// obligation from the 320 CSS px reflow endpoint and from text-spacing.
test('every slide and walkthrough stays usable at 200 percent browser zoom', async ({ browser }) => {
  test.setTimeout(180_000);
  const context = await browser.newContext({
    viewport: { width: 640, height: 384 },
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();
  try {
    await openDeck(page);
    const ids = await page.locator('.slides > section').evaluateAll(nodes => nodes.map(node => node.id));
    expect(ids.length).toBeGreaterThan(0);
    for (const id of ids) {
      await page.evaluate(id => location.hash = `#/${id}`, id);
      await expect(page.locator('section.present')).toHaveAttribute('id', id);
      await expectReflow(page);
      await expectNoOverlap(page);
      expect((await new AxeBuilder({ page }).include('section.present').analyze()).violations).toEqual([]);
      const next = page.locator('section.present [data-action="next"]');
      if (await next.count()) {
        while (await next.isEnabled()) {
          await next.press('Enter');
          await expectReflow(page);
          await expectNoOverlap(page);
        }
        await page.locator('section.present [data-action="reset"]').press('Enter');
        await expect(page.locator('section.present [data-action="back"]')).toBeDisabled();
      }
    }

    // Controls stay reachable, focusable and operable at the same zoom level.
    const nextSlide = page.getByRole('button', { name: 'Next slide', exact: true });
    await page.evaluate(() => location.hash = '');
    await nextSlide.focus();
    await expect(nextSlide).toBeFocused();
    await expectFocusRingVisible(page, nextSlide);
    await expectFullyVisible(page, nextSlide);
    await nextSlide.press('Enter');
    await expect(page.locator('#announcement')).toHaveText(/Slide 2 of 26/);

    // The slide index dialog is a distinct zoomed state, not an inference.
    const overview = page.getByRole('button', { name: 'Slides', exact: true });
    await overview.press('Enter');
    const dialog = page.getByRole('dialog', { name: 'Slide index' });
    await expect(dialog).toBeVisible();
    await expectReflow(page);
    expect((await new AxeBuilder({ page }).withTags(tags).analyze()).violations).toEqual([]);
    await page.keyboard.press('Escape');
    await expect(overview).toBeFocused();
  } finally {
    await context.close();
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

test('fullscreen control reports state and returns focus', async ({ page }) => {
  await openDeck(page);
  const fullscreen = page.getByRole('button', { name: 'Full screen' });
  await fullscreen.press('Enter');
  await expect(fullscreen).toHaveAttribute('aria-pressed', 'true');
  await expect.poll(() => page.evaluate(() => document.fullscreenElement?.tagName)).toBe('HTML');
  await page.getByRole('button', { name: 'Exit full screen' }).press('Enter');
  await expect(fullscreen).toHaveAttribute('aria-pressed', 'false');
  await expect(fullscreen).toBeFocused();
});

test('presentation controls remain perceivable in forced colors', async ({ browser }) => {
  const context = await browser.newContext({ forcedColors: 'active' });
  const page = await context.newPage();
  try {
    await openDeck(page);
    await expect.poll(() => page.evaluate(() => matchMedia('(forced-colors: active)').matches)).toBe(true);
    const next = page.getByRole('button', { name: 'Next slide', exact: true });
    await next.focus();
    const outline = await next.evaluate(element => {
      const style = getComputedStyle(element);
      return { style: style.outlineStyle, width: parseFloat(style.outlineWidth) };
    });
    expect(outline.style).not.toBe('none');
    expect(outline.width).toBeGreaterThanOrEqual(2);
    expect((await new AxeBuilder({ page }).withTags(tags).analyze()).violations).toEqual([]);
  } finally {
    await context.close();
  }
});

test('committed, staged and served slide bundles have byte parity', async ({ request }) => {
  const repositoryRoot = path.resolve(__dirname, '../../..');
  const committed = readFileSync(path.join(repositoryRoot, 'docs/slides/hve-updates.html'), 'utf8');
  const staged = readFileSync(path.join(repositoryRoot, 'docs/docusaurus/static/slides/hve-updates.html'), 'utf8');
  const response = await request.get(deckPath);
  expect(response.ok()).toBe(true);
  expect(staged).toBe(committed);
  expect(await response.text()).toBe(committed);
});
