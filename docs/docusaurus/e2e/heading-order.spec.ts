// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import { SITE_PAGES, visitInvariantPage } from './_helpers/a11yInvariants';

test.describe('Heading-order accessibility regression locks', () => {
  for (const { name, path } of SITE_PAGES) {
    test(`${name} does not skip heading levels`, async ({ page }) => {
      await visitInvariantPage(page, { name, path });

      const levels = await page.$$eval('h1, h2, h3, h4, h5, h6', (headings) =>
        headings.map((heading) => Number(heading.tagName.charAt(1))),
      );

      let previousLevel: number | null = null;
      for (const level of levels) {
        if (previousLevel !== null) {
          expect(
            level,
            `Heading level jumped from ${previousLevel} to ${level} on ${name}`,
          ).toBeLessThanOrEqual(previousLevel + 1);
        }
        previousLevel = level;
      }
    });

    test(`${name} uses real heading tags for prominent in-page and footer titles`, async ({ page }) => {
      await visitInvariantPage(page, { name, path });

      // Selecting h2/h3/h4 and then asserting the tag is a heading is a
      // tautology. A faux heading is prominent text that is NOT a heading, so
      // find visually heading-sized text and assert it carries heading
      // semantics, which is the property this test names.
      const fauxHeadings = await page.evaluate(() => {
        const isHeadingSemantic = (element: Element) =>
          /^H[1-6]$/.test(element.tagName)
          || element.getAttribute('role') === 'heading';

        // Zero-width and formatting characters are not visible text. The theme's
        // anchor "hash-link" contains only a zero-width space and inherits its
        // parent heading's typography, so it must not count as prominent text.
        const visibleText = (element: Element) =>
          (element.textContent ?? '').replace(/[\s\u200b-\u200f\u2060\ufeff]/g, '');

        return Array.from(document.querySelectorAll<HTMLElement>('.theme-doc-markdown *, .footer__title'))
          .filter((element) => element.getClientRects().length > 0)
          // Content inside a heading is already covered by that heading.
          .filter((element) => element.closest('h1, h2, h3, h4, h5, h6') === null)
          .filter((element) => {
            // Only consider leaf-ish text nodes so a large container does not
            // count as prominent text on behalf of its children.
            if (!visibleText(element) || element.querySelector('h1, h2, h3, h4, h5, h6, p, li')) {
              return false;
            }
            const computed = window.getComputedStyle(element);
            const fontSize = Number.parseFloat(computed.fontSize) || 0;
            const fontWeight = Number.parseInt(computed.fontWeight, 10) || 400;
            return fontSize >= 20 && fontWeight >= 600;
          })
          .filter((element) => !isHeadingSemantic(element))
          .map((element) => ({
            tag: element.tagName.toLowerCase(),
            className: String(element.className || '').split(' ')[0],
            text: visibleText(element).slice(0, 60),
          }));
      });

      expect(
        fauxHeadings,
        `${name} renders prominent text without heading semantics: ${JSON.stringify(fauxHeadings)}`,
      ).toEqual([]);
    });
  }
});
