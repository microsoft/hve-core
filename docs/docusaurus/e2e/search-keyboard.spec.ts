// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect, type Page } from '@playwright/test';
import { openSearchWidget, waitForHydration } from './_helpers/a11yInvariants';

async function openNavbarSearch(page: Page) {
  await page.goto('/hve-core/docs/getting-started/');
  await page.waitForLoadState('domcontentloaded');
  await waitForHydration(page);

  // Gate on upstream attachment rather than role="combobox", which this
  // repository's swizzle supplies at rest.
  const input = await openSearchWidget(page);
  await input.fill('agent');
  await page.locator('[role="listbox"]').first().waitFor({ state: 'visible', timeout: 30000 });

  return input;
}

async function getFooterId(page: Page) {
  const footer = page.locator('[role="listbox"] [class*="hitFooter"] a').first();
  await footer.waitFor({ state: 'attached' });
  return footer.getAttribute('id');
}

async function getResultOptionIds(page: Page) {
  return page.$$eval('[role="listbox"] [role="option"]', (els) =>
    els
      .filter((el) => !el.closest('[class*="hitFooter"]'))
      .map((el) => el.id),
  );
}

// Arrow down until the active descendant is the given id, or the cap is hit.
async function arrowDownUntilActive(page: Page, input: ReturnType<Page['locator']>, targetId: string, cap: number) {
  for (let index = 0; index < cap; index += 1) {
    const previousActiveDescendant = await input.getAttribute('aria-activedescendant');
    if (previousActiveDescendant === targetId) {
      return true;
    }
    await input.press('ArrowDown');
    await expect
      .poll(
        () => input.getAttribute('aria-activedescendant'),
        {
          message: 'ArrowDown should update aria-activedescendant',
          timeout: 3000,
        },
      )
      .not.toBe(previousActiveDescendant);
  }
  return (await input.getAttribute('aria-activedescendant')) === targetId;
}

// Describes where focus currently sits, distinguishing the input, <body>, and
// whether the destination is inside the search widget. A signature is included
// so two observations can be compared for "focus did not move".
async function describeActiveElement(page: Page) {
  return page.evaluate(() => {
    const active = document.activeElement;
    if (!active || active === document.body) {
      return { role: 'body', insideWidget: false, signature: 'body' };
    }
    const widget = document.querySelector('.navbar__search');
    const insideWidget = Boolean(widget && widget.contains(active));
    const role = active.classList.contains('navbar__search-input') ? 'search-input' : 'other';
    const signature = [
      active.tagName.toLowerCase(),
      active.id || '',
      String(active.className || ''),
      (active.textContent || '').trim().slice(0, 40),
    ].join('|');
    return { role, insideWidget, signature };
  });
}

test.describe('Search keyboard navigation', () => {
  test('exposes an accessible name on the search clear button', async ({ page }) => {
    await openNavbarSearch(page);

    // The clear control carries a camelCase CSS-module class and no type
    // attribute, so the substring match needs the case-insensitive flag.
    const clearButton = page.locator('button[type="reset"], button[class*="clear" i]').first();
    await expect(clearButton).toBeVisible();

    const accessibleName = await clearButton.evaluate((element) => {
      const ariaLabel = element.getAttribute('aria-label');
      if (ariaLabel) {
        return ariaLabel;
      }

      return element.textContent?.trim() ?? '';
    });

    expect(accessibleName, 'The search clear button should expose an accessible name').toMatch(/clear|reset/i);
  });

  test('associates the search input with an existing label or description', async ({ page }) => {
    const input = await openNavbarSearch(page);

    const labelledBy = await input.getAttribute('aria-labelledby');
    const describedBy = await input.getAttribute('aria-describedby');
    const ids = [...new Set([...(labelledBy?.split(/\s+/) ?? []), ...(describedBy?.split(/\s+/) ?? [])])];

    expect(ids.length, 'The search input should carry an aria-labelledby or aria-describedby association').toBeGreaterThan(0);

    for (const id of ids) {
      const associatedElement = page.locator(`#${id}`).first();
      const count = await associatedElement.count();
      expect(count, `Expected the associated element #${id} to exist`).toBeGreaterThan(0);
      const text = await associatedElement.textContent();
      expect(text?.trim().length ?? 0, `Expected the associated element #${id} to contain text`).toBeGreaterThan(0);
    }
  });

  test('reaches the footer option via arrow keys without moving focus from the input', async ({ page }) => {
    const input = await openNavbarSearch(page);

    const footerId = await getFooterId(page);
    const optionCount = (await getResultOptionIds(page)).length;

    let reachedFooter = false;
    // Accumulate every iteration's result. Assigning on each pass would let a
    // final conformant iteration erase an earlier violation, so the assertion
    // would report only the last step rather than the whole walk.
    const focusEscapes: string[] = [];

    for (let index = 0; index < optionCount + 4; index += 1) {
      await input.press('ArrowDown');
      await page.waitForTimeout(80);

      const activeDescendant = await input.getAttribute('aria-activedescendant');
      const activeElement = await page.evaluate(() => {
        const active = document.activeElement;
        if (!active || active === document.body) {
          // Focus dropping to <body> is a real failure, not a neutral state:
          // the user loses their place in the widget entirely.
          return 'body';
        }
        return String(active.className || active.tagName);
      });
      if (!activeElement.includes('navbar__search-input')) {
        focusEscapes.push(`step ${index + 1}: focus moved to "${activeElement}"`);
      }
      if (activeDescendant && footerId && activeDescendant === footerId) {
        reachedFooter = true;
        break;
      }
    }

    expect(reachedFooter, 'ArrowDown should reach the footer option').toBe(true);
    expect(
      focusEscapes,
      `Focus should stay on the combobox input while arrowing: ${focusEscapes.join('; ')}`,
    ).toEqual([]);
  });

  test('ArrowDown from the last result reaches the footer instead of wrapping to the top', async ({ page }) => {
    const input = await openNavbarSearch(page);

    const footerId = await getFooterId(page);
    const optionIds = await getResultOptionIds(page);
    expect(optionIds.length, 'expected at least one result option').toBeGreaterThan(0);
    const firstId = optionIds[0];
    const lastId = optionIds[optionIds.length - 1];

    const onLast = await arrowDownUntilActive(page, input, lastId, optionIds.length + 2);
    expect(onLast, 'should be able to reach the last result option').toBe(true);

    await input.press('ArrowDown');
    await page.waitForTimeout(80);
    const active = await input.getAttribute('aria-activedescendant');

    expect(active, 'ArrowDown from the last option should activate the footer').toBe(footerId);
    expect(active, 'ArrowDown from the last option must not wrap to the first option').not.toBe(firstId);

    const footerActive = await page
      .locator('[role="listbox"] [class*="hitFooter"] a.search-footer-active')
      .count();
    expect(footerActive, 'the footer should carry the active highlight class').toBe(1);
  });

  test('ArrowUp from the footer returns to the last result option', async ({ page }) => {
    const input = await openNavbarSearch(page);

    const footerId = await getFooterId(page);
    const optionIds = await getResultOptionIds(page);
    const lastId = optionIds[optionIds.length - 1];

    const reachedFooter = await arrowDownUntilActive(page, input, footerId as string, optionIds.length + 4);
    expect(reachedFooter, 'should reach the footer before testing ArrowUp').toBe(true);

    await input.press('ArrowUp');
    await page.waitForTimeout(80);

    expect(await input.getAttribute('aria-activedescendant')).toBe(lastId);
  });

  test('Enter on the footer navigates to the full search results page', async ({ page }) => {
    const input = await openNavbarSearch(page);

    const footerId = await getFooterId(page);
    const optionIds = await getResultOptionIds(page);

    const reachedFooter = await arrowDownUntilActive(page, input, footerId as string, optionIds.length + 4);
    expect(reachedFooter, 'should reach the footer before pressing Enter').toBe(true);

    await Promise.all([
      page.waitForURL(/\/search\/?/, { timeout: 10000 }),
      input.press('Enter'),
    ]);

    expect(page.url()).toContain('/search');
  });

  test('Tab from the open popup follows native focus order out of the widget', async ({ page }) => {
    const input = await openNavbarSearch(page);

    await getFooterId(page);

    const urlBefore = page.url();

    // The interceptor previously discarded every in-widget candidate as a class,
    // which made the clear button unreachable. The contract is native sequential
    // focus: Tab reaches the next control in document order, which is the clear
    // button where the plugin renders one and an element outside the widget
    // otherwise. Asserting only "not the input" would pass either way, and
    // asserting only "inside the widget" would pass for any other in-widget
    // control, so the rendered clear button is identified explicitly.
    //
    // It is identified by the attributes the plugin itself renders. Matching on
    // the accessible name instead would depend on this repository's own wrapper
    // having applied it: if the name were not yet set, the locator would resolve
    // to nothing and the weaker "somewhere in the widget" branch below would run
    // in its place, reporting a pass without ever checking the destination.
    const clearButton = page
      .locator('.navbar__search button[type="reset"], .navbar__search button[class*="clear" i]')
      .first();
    const clearButtonCount = await clearButton.count();
    const widgetControlCount = await page.evaluate(() => {
      const root = document.querySelector('.navbar__search');
      if (!root) {
        return 0;
      }
      return root.querySelectorAll(
        'button:not([disabled]):not([tabindex="-1"]), a[href]:not([tabindex="-1"])',
      ).length;
    });

    await input.press('Tab');
    await page.waitForTimeout(250);

    const first = await describeActiveElement(page);

    // Focus landing on <body> is not a valid Tab escape. The browser parks focus
    // there when a handler cancels the default move, which is the keyboard trap
    // this test exists to detect. It is also where focus ends up if the widget
    // reclaims it while tearing the popup down.
    expect(
      first.role,
      'Tab must move focus off the input (no keyboard trap, WCAG 2.1.2)',
    ).not.toBe('search-input');
    expect(
      first.role,
      'Tab dropped focus to <body>, which means the native focus move was cancelled or reclaimed (keyboard trap, WCAG 2.1.2)',
    ).not.toBe('body');

    if (clearButtonCount > 0) {
      // The widget's own control is the next stop in document order. The defect
      // being locked out is skipping past it or losing it to popup teardown.
      await expect(
        clearButton,
        'Tab must reach the search clear button rather than skipping past it',
      ).toBeFocused();

      await page.keyboard.press('Tab');
      await page.waitForTimeout(250);
      const second = await describeActiveElement(page);
      expect(
        second.insideWidget,
        'A further Tab must leave the search widget',
      ).toBe(false);
      expect(second.role, 'A further Tab must not park focus on <body>').not.toBe('body');
    } else if (widgetControlCount > 0) {
      // Some other in-widget control is rendered instead; the contract is still
      // that Tab reaches it and a further Tab leaves.
      expect(
        first.insideWidget,
        'Tab must reach the widget\'s own control rather than skipping past it',
      ).toBe(true);

      await page.keyboard.press('Tab');
      await page.waitForTimeout(250);
      const second = await describeActiveElement(page);
      expect(
        second.insideWidget,
        'A further Tab must leave the search widget',
      ).toBe(false);
      expect(second.role, 'A further Tab must not park focus on <body>').not.toBe('body');
    } else {
      // With no in-widget control rendered, Tab leaves the widget directly.
      expect(first.insideWidget, 'Tab must leave the widget when it renders no control').toBe(false);
    }

    expect(page.url()).toBe(urlBefore);
  });

  test('Shift+Tab returns through the same path and focus stays where the user put it', async ({ page }) => {
    const input = await openNavbarSearch(page);
    await getFooterId(page);

    await input.press('Tab');
    await page.waitForTimeout(250);
    const forward = await describeActiveElement(page);
    expect(forward.role).not.toBe('body');

    await page.keyboard.press('Shift+Tab');
    await page.waitForTimeout(250);
    const back = await describeActiveElement(page);
    expect(back.role, 'Shift+Tab must not park focus on <body>').not.toBe('body');
    // Reverse traversal from the widget's first control returns to the input the
    // user started from. Naming that destination is what distinguishes a real
    // round trip from focus merely landing somewhere that is not <body>.
    expect(
      back.role,
      'Shift+Tab must return to the search input the forward Tab left',
    ).toBe('search-input');

    // The removed guard reclaimed focus for 600 ms after a Tab, so a deliberate
    // reverse move was undone. Waiting past that window proves nothing contests
    // the destination any more.
    await page.waitForTimeout(900);
    const settled = await describeActiveElement(page);
    expect(
      settled.signature,
      'Focus must stay where the user put it after the former guard window elapses',
    ).toBe(back.signature);
  });

  test('completing the search index load does not steal focus back to the input', async ({ page }) => {
    const input = await openNavbarSearch(page);

    await input.press('Tab');
    await page.waitForTimeout(250);
    const before = await describeActiveElement(page);
    expect(before.role, 'the test needs focus off the input first').not.toBe('search-input');
    expect(before.role).not.toBe('body');

    // Deterministic seam: the upstream package refocuses the input from an
    // asynchronous continuation when its index finishes loading. Calling focus()
    // outside any user gesture reproduces exactly that call without depending on
    // index-load timing.
    await page.evaluate(() => {
      const node = document.querySelector('input.navbar__search-input');
      (node as HTMLInputElement | null)?.focus();
    });
    await page.waitForTimeout(250);

    const after = await describeActiveElement(page);
    expect(
      after.signature,
      'Programmatic refocus after index load must not move focus away from the user',
    ).toBe(before.signature);
  });
});

