// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import type { Page } from '@playwright/test';
import { PAGES, type PageSpec } from './pages';

export interface PageSnapshot {
  title: string;
  landmarks: {
    banner: number;
    navigation: number;
    main: number;
    footer: number;
  };
  headingLevels: number[];
  headingCount: number;
  searchRoles: string[];
  tocHeading: string;
  footerTitles: string[];
}

export const SITE_PAGES: readonly PageSpec[] = PAGES;

// Docusaurus sets `<html data-has-hydrated="true">` once React has hydrated the
// server-rendered markup. Before that point the attribute is "false": client
// event handlers are not attached and theme state is not applied, so keyboard
// activation, focus styling, and ARIA state assertions race the client bundle.
// Waiting for the attribute makes those assertions deterministic regardless of
// how much CPU the page is competing for.
export async function waitForHydration(page: Page): Promise<void> {
  await page.waitForFunction(
    () => document.documentElement.dataset.hasHydrated === 'true',
    undefined,
    { timeout: 30000 },
  );
}

export async function visitInvariantPage(page: Page, spec: PageSpec): Promise<void> {
  await page.goto(spec.path, { waitUntil: 'domcontentloaded' });
  await waitForHydration(page);
}

// Opens the navbar search widget and waits for the upstream library to attach.
//
// `role="combobox"` is NOT a valid readiness signal. The local SearchBar swizzle
// applies that role itself on its first observer pass, so waiting for it only
// confirms that our own code ran. Verified at runtime: at rest the input carries
// only role/aria-expanded/aria-label from the swizzle, and upstream
// @easyops-cn/autocomplete.js attaches lazily on first interaction, at which
// point it adds aria-autocomplete, aria-owns, and aria-controls and re-parents
// the input. `aria-autocomplete` is set exclusively by upstream, so it gates on
// real readiness and times out when the widget fails to attach.
export async function openSearchWidget(page: Page, timeout = 30000) {
  const input = page.locator('input.navbar__search-input').first();
  await input.waitFor({ state: 'visible' });
  await input.click();
  await page.waitForFunction(
    () => {
      const el = document.querySelector('input.navbar__search-input');
      return Boolean(el?.hasAttribute('aria-autocomplete'));
    },
    undefined,
    { timeout },
  );
  return input;
}

export async function collectPageSnapshot(page: Page): Promise<PageSnapshot> {
  return await page.evaluate(() => {
    // A native <header>/<footer> is only exposed as the banner/contentinfo
    // landmark when it is not scoped inside article/aside/main/nav/section
    // (HTML-AAM). Counting raw elements would miscount the nested
    // footer.theme-doc-footer and the doc article <header>, so filter to
    // top-level elements and de-duplicate against explicit ARIA roles.
    const isTopLevel = (element: Element) =>
      element.closest('article, aside, main, nav, section') === null;
    const bannerLandmarks = new Set<Element>([
      ...Array.from(document.querySelectorAll('header')).filter(isTopLevel),
      ...Array.from(document.querySelectorAll('[role="banner"]')),
    ]);
    const contentinfoLandmarks = new Set<Element>([
      ...Array.from(document.querySelectorAll('footer')).filter(isTopLevel),
      ...Array.from(document.querySelectorAll('[role="contentinfo"]')),
    ]);
    const landmarks = {
      banner: bannerLandmarks.size,
      navigation: document.querySelectorAll('nav, [role="navigation"]').length,
      main: document.querySelectorAll('main, [role="main"]').length,
      footer: contentinfoLandmarks.size,
    };

    const headingLevels = Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6')).map((heading) => Number(heading.tagName.charAt(1)));
    const searchRoles = Array.from(document.querySelectorAll('[role="combobox"], [role="status"], [role="listbox"], .navbar__search-input')).map((element) => {
      const role = element.getAttribute?.('role');
      if (role) {
        return role;
      }

      return element.className || element.tagName.toLowerCase();
    });

    return {
      title: document.title,
      landmarks,
      headingLevels,
      headingCount: headingLevels.length,
      searchRoles,
      tocHeading: document.querySelector('.table-of-contents__title')?.textContent?.trim() ?? '',
      footerTitles: Array.from(document.querySelectorAll('.footer__title')).map((element) => element.textContent?.trim() ?? ''),
    };
  });
}
