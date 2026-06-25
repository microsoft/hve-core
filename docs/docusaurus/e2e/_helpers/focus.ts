// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import type { Page } from '@playwright/test';

// Shared behavioral focus helpers for keyboard/focus-management specs. These
// drive real keyboard interaction against the rendered Docusaurus DOM, covering
// WCAG criteria (2.1.1, 2.1.2, 2.4.3) that static axe-based scans cannot reach.

/** A snapshot of the active element captured at one step of a focus traversal. */
export interface FocusSnapshot {
  tag: string | undefined;
  text: string | undefined;
  ariaLabel: string | null | undefined;
  id: string | undefined;
}

/**
 * Drive Tab / Shift+Tab and snapshot the active element at each step.
 *
 * @param page - The Playwright page under test.
 * @param direction - Traversal direction; 'forward' presses Tab, 'backward' presses Shift+Tab.
 * @param count - Number of steps (snapshots) to collect.
 * @returns The ordered sequence of active-element snapshots.
 */
export async function collectFocusOrder(
  page: Page,
  direction: 'forward' | 'backward' = 'forward',
  count = 5,
): Promise<FocusSnapshot[]> {
  const sequence: FocusSnapshot[] = [];
  for (let i = 0; i < count; i++) {
    sequence.push(
      await page.evaluate(() => {
        const el = document.activeElement;
        return {
          tag: el?.tagName,
          text: el?.textContent?.slice(0, 50),
          ariaLabel: el?.getAttribute('aria-label'),
          id: el?.id,
        };
      }),
    );
    await page.keyboard.press(direction === 'forward' ? 'Tab' : 'Shift+Tab');
  }
  return sequence;
}

/**
 * Focus the first focusable element inside a container, press the escape key,
 * and report whether focus left the container.
 *
 * @param page - The Playwright page under test.
 * @param containerSelector - CSS selector for the container that should release focus.
 * @param escapeKey - The key expected to release the trap (default 'Escape').
 * @returns True when the active element is no longer within the container.
 */
export async function testFocusTrapEscape(
  page: Page,
  containerSelector: string,
  escapeKey = 'Escape',
): Promise<boolean> {
  const container = page.locator(containerSelector);
  await container.locator('button, a, input').first().focus();
  await page.keyboard.press(escapeKey);
  return await page.evaluate(
    (sel) => document.activeElement?.closest(sel) === null,
    containerSelector,
  );
}

/**
 * Validate a roving-tabindex container: exactly one element with tabindex="0"
 * and every other tabindex element set to "-1".
 *
 * @param page - The Playwright page under test.
 * @param containerSelector - CSS selector for the roving-tabindex container.
 * @returns True when the container satisfies the roving-tabindex invariant.
 */
export async function validateRovingTabindex(
  page: Page,
  containerSelector: string,
): Promise<boolean> {
  const items = page.locator(`${containerSelector} [tabindex]`);
  const count = await items.count();
  const zero = await page.locator(`${containerSelector} [tabindex="0"]`).count();
  const negOne = await page.locator(`${containerSelector} [tabindex="-1"]`).count();
  return zero === 1 && negOne === count - 1;
}
