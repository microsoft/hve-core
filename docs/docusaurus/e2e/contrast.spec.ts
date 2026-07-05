// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import { SITE_PAGES, visitInvariantPage } from './_helpers/a11yInvariants';

function parseColor(color: string): { r: number; g: number; b: number; a: number } | null {
  const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/i);
  if (!match) {
    return null;
  }

  return {
    r: Number(match[1]),
    g: Number(match[2]),
    b: Number(match[3]),
    a: match[4] === undefined ? 1 : Number(match[4]),
  };
}

function relativeLuminance(color: { r: number; g: number; b: number; a: number }): number {
  const toLinear = (channel: number) => {
    const value = channel / 255;
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  };

  return 0.2126 * toLinear(color.r) + 0.7152 * toLinear(color.g) + 0.0722 * toLinear(color.b);
}

function calculateContrastRatio(foreground: string, background: string): number {
  const fg = parseColor(foreground);
  const bg = parseColor(background);

  if (!fg || !bg) {
    throw new Error(`Unable to parse colors: ${foreground} / ${background}`);
  }

  const fgLuminance = relativeLuminance(fg);
  const bgLuminance = relativeLuminance(bg);
  const lighter = Math.max(fgLuminance, bgLuminance);
  const darker = Math.min(fgLuminance, bgLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}

function describeContrastCase(label: string, selector: string, pseudoElt?: string): string {
  if (pseudoElt) {
    return `${label} (${selector}, ${pseudoElt})`;
  }
  return `${label} (${selector})`;
}

async function measureContrast(page: any, selector: string, pseudoElt?: string) {
  return await page.evaluate(
    ({ selector, pseudoElt }) => {
      const node = document.querySelector(selector) as HTMLElement | null;
      if (!node) {
        throw new Error(`Missing contrast node: ${selector}`);
      }

      const elementStyle = window.getComputedStyle(node);
      const style = pseudoElt ? window.getComputedStyle(node, pseudoElt) : elementStyle;
      const foreground = style.color;
      let backgroundColor = pseudoElt ? elementStyle.backgroundColor : style.backgroundColor;
      let backgroundImage = pseudoElt ? elementStyle.backgroundImage : style.backgroundImage;
      let current: Element | null = node;

      while (current && current !== document.body) {
        const computed = window.getComputedStyle(current);
        if (computed.backgroundImage && computed.backgroundImage !== 'none') {
          backgroundImage = computed.backgroundImage;
          break;
        }

        if (computed.backgroundColor && computed.backgroundColor !== 'rgba(0, 0, 0, 0)' && computed.backgroundColor !== 'transparent') {
          backgroundColor = computed.backgroundColor;
          break;
        }

        current = current.parentElement;
      }

      return {
        foreground,
        backgroundColor,
        backgroundImage,
        fontSize: Number.parseFloat(style.fontSize),
        fontWeight: Number.parseInt(style.fontWeight || '400', 10),
      };
    },
    { selector, pseudoElt },
  );
}

test.describe('Contrast measurement gates', () => {
  for (const pageCase of SITE_PAGES) {
    test(`${pageCase.name} keeps links visually distinct without relying on color alone`, async ({ page }) => {
      await visitInvariantPage(page, pageCase);

      // WCAG 1.4.1 (Use of Color) targets links embedded in blocks of text.
      // Scope the check to in-content prose links (Docusaurus renders the
      // article body under .markdown); navigational chrome such as breadcrumbs,
      // cards, and hero call-to-action buttons is distinguished by non-color
      // affordances and is intentionally out of scope here. Heading anchor
      // (hash) links are decorative and excluded.
      const proseLinks = page.locator(
        '.markdown a:not(.hash-link):not([class*="card"]):not([class*="button"])',
      );
      const count = await proseLinks.count();
      test.skip(count === 0, 'No in-content prose links on this page.');

      const link = proseLinks.first();
      await expect(link).toBeVisible();

      const style = await link.evaluate((element) => {
        const computed = window.getComputedStyle(element);
        return {
          textDecorationLine: computed.textDecorationLine,
          textDecorationStyle: computed.textDecorationStyle,
          textDecorationColor: computed.textDecorationColor,
        };
      });

      expect(style.textDecorationLine, `${pageCase.name} should render a visible underline for content links`).toMatch(/underline/i);
    });
  }

  test('measures the navbar search input contrast in light and dark mode', async ({ page }) => {
    await page.goto('/hve-core/', { waitUntil: 'domcontentloaded' });

    const toggle = page.getByRole('button', { name: /switch between dark and light mode/i });
    await expect(toggle).toBeVisible();

    for (const mode of ['light', 'dark'] as const) {
      if (mode === 'dark') {
        await toggle.click();
        await page.keyboard.press('Enter');
      }

      await expect.poll(async () => page.locator('html').getAttribute('data-theme')).toBe(mode === 'dark' ? 'dark' : 'light');

      const searchText = await measureContrast(page, '.navbar__search-input');
      const searchPlaceholder = await measureContrast(page, '.navbar__search-input', '::placeholder');

      const searchTextRatio = calculateContrastRatio(searchText.foreground, searchText.backgroundColor);
      const placeholderRatio = calculateContrastRatio(searchPlaceholder.foreground, searchPlaceholder.backgroundColor);
      const threshold = 4.5;

      expect(
        searchTextRatio,
        `${describeContrastCase('Search input text', '.navbar__search-input')} should meet SC 1.4.3 AA (${threshold}:1) in ${mode} mode`,
      ).toBeGreaterThanOrEqual(threshold);
      expect(
        placeholderRatio,
        `${describeContrastCase('Search input placeholder', '.navbar__search-input', '::placeholder')} should meet SC 1.4.3 AA (${threshold}:1) in ${mode} mode`,
      ).toBeGreaterThanOrEqual(threshold);
    }
  });

  test('records the homepage hero contrast as human review where the background is a gradient', async ({ page }) => {
    await page.goto('/hve-core/', { waitUntil: 'domcontentloaded' });

    // The hero is a labelled <section aria-labelledby="hero-title">, not a
    // <header>; target the hero heading/subtitle directly. measureContrast walks
    // ancestors for the effective (gradient) background.
    const heading = await measureContrast(page, '#hero-title');
    const subtitle = await measureContrast(page, '[aria-labelledby="hero-title"] p');

    expect(
      heading.backgroundImage,
      `${describeContrastCase('Homepage hero heading', '#hero-title')} should be evaluated as a human-review case when the effective background is a gradient or image`,
    ).toBeTruthy();
    expect(
      subtitle.backgroundImage,
      `${describeContrastCase('Homepage hero subtitle', '[aria-labelledby="hero-title"] p')} should be evaluated as a human-review case when the effective background is a gradient or image`,
    ).toBeTruthy();

    const headingRatio = heading.backgroundImage && heading.backgroundImage !== 'none'
      ? null
      : calculateContrastRatio(heading.foreground, heading.backgroundColor);
    const subtitleRatio = subtitle.backgroundImage && subtitle.backgroundImage !== 'none'
      ? null
      : calculateContrastRatio(subtitle.foreground, subtitle.backgroundColor);

    expect(headingRatio).toBeNull();
    expect(subtitleRatio).toBeNull();
  });
});
