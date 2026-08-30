// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { test, expect } from '@playwright/test';
import { SITE_PAGES, openSearchWidget, visitInvariantPage, waitForHydration } from './_helpers/a11yInvariants';

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

      // SC 1.4.1 is a per-link guarantee, so every prose link is measured rather
      // than a single sample. A link satisfies the criterion when it carries a
      // visible underline, or when it is distinguishable from surrounding text
      // by a non-color means (weight or style) in addition to color.
      const offenders = await proseLinks.evaluateAll((elements) =>
        elements
          .map((element) => {
            const computed = window.getComputedStyle(element);
            const parent = element.parentElement
              ? window.getComputedStyle(element.parentElement)
              : null;
            const underlined = /underline/i.test(computed.textDecorationLine);
            const weightDelta = parent
              ? Math.abs(
                Number.parseInt(computed.fontWeight || '400', 10)
                  - Number.parseInt(parent.fontWeight || '400', 10),
              )
              : 0;
            const styleDelta = parent ? computed.fontStyle !== parent.fontStyle : false;
            const nonColorCue = underlined || weightDelta >= 300 || styleDelta;
            return nonColorCue
              ? null
              : {
                text: (element.textContent || '').trim().slice(0, 40),
                decoration: computed.textDecorationLine,
                fontWeight: computed.fontWeight,
              };
          })
          .filter(Boolean),
      );

      expect(
        offenders,
        `${pageCase.name} has prose links distinguished by color alone: ${JSON.stringify(offenders)}`,
      ).toEqual([]);
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

  test('measures the selected search result contrast in light and dark mode', async ({ page }) => {
    await page.goto('/hve-core/docs/getting-started/', { waitUntil: 'domcontentloaded' });
    await waitForHydration(page);

    const toggle = page.getByRole('button', { name: /switch between dark and light mode/i });
    await expect(toggle).toBeVisible();

    for (const mode of ['light', 'dark'] as const) {
      if (mode === 'dark') {
        await toggle.click();
        await page.keyboard.press('Enter');
        await expect.poll(async () => page.locator('html').getAttribute('data-theme')).toBe('dark');
      }

      const searchInput = await openSearchWidget(page);
      await searchInput.fill('getting');
      await expect(page.locator('[role="listbox"] [role="option"]').first()).toBeVisible({ timeout: 15000 });

      // Rove the selection onto the first option so the measured state is the one
      // a keyboard user actually reads.
      await searchInput.press('ArrowDown');
      const selected = page.locator('[role="option"][aria-selected="true"]').first();
      await expect(selected).toHaveCount(1);

      const option = await measureContrast(page, '[role="option"][aria-selected="true"]');
      const optionRatio = calculateContrastRatio(option.foreground, option.backgroundColor);
      expect(
        optionRatio,
        `${describeContrastCase('Selected search result', '[role="option"][aria-selected="true"]')} should meet SC 1.4.3 AA (4.5:1) in ${mode} mode`,
      ).toBeGreaterThanOrEqual(4.5);

      // The matched term is a <mark> descendant that upstream paints in its own
      // color. A container-only measurement misses it entirely, and the defect
      // was the mark resolving to the option's own background.
      const markCount = await page.locator('[role="option"][aria-selected="true"] mark').count();
      expect(markCount, 'the query should highlight a matched term inside the selected option').toBeGreaterThan(0);

      const mark = await measureContrast(page, '[role="option"][aria-selected="true"] mark');
      const markRatio = calculateContrastRatio(mark.foreground, mark.backgroundColor);
      expect(
        markRatio,
        `${describeContrastCase('Selected search result matched term', '[role="option"][aria-selected="true"] mark')} should meet SC 1.4.3 AA (4.5:1) in ${mode} mode`,
      ).toBeGreaterThanOrEqual(4.5);

      // SC 1.4.1: the match must stay distinguishable from adjacent option text by
      // something other than color, so the affordance survives for users who
      // cannot perceive the color difference. Compared against a sibling text run
      // rather than the background, which would pass even if the mark became
      // indistinguishable from its neighbors.
      const distinction = await page.evaluate(() => {
        const markNode = document.querySelector('[role="option"][aria-selected="true"] mark');
        if (!markNode || !markNode.parentElement) {
          return null;
        }
        const siblingText = Array.from(markNode.parentElement.childNodes).find(
          (node) => node.nodeType === Node.TEXT_NODE && (node.textContent || '').trim().length > 0,
        );
        if (!siblingText) {
          return null;
        }
        const markStyle = window.getComputedStyle(markNode);
        const parentStyle = window.getComputedStyle(markNode.parentElement);
        return {
          markWeight: markStyle.fontWeight,
          siblingWeight: parentStyle.fontWeight,
          markDecoration: markStyle.textDecorationLine,
          siblingDecoration: parentStyle.textDecorationLine,
          markStyleName: markStyle.fontStyle,
          siblingStyleName: parentStyle.fontStyle,
        };
      });

      expect(distinction, 'the selected option should contain a matched term beside plain text').not.toBeNull();
      const differsByNonColor =
        distinction!.markWeight !== distinction!.siblingWeight ||
        distinction!.markDecoration !== distinction!.siblingDecoration ||
        distinction!.markStyleName !== distinction!.siblingStyleName;
      expect(
        differsByNonColor,
        `The matched term must differ from adjacent option text by a non-color property in ${mode} mode: ${JSON.stringify(distinction)}`,
      ).toBe(true);

      await searchInput.press('Escape');
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
