// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { waitForHydration } from './_helpers/a11yInvariants';

interface MermaidFence {
  file: string;
  startLine: number;
  source: string;
  title: string;
  description: string;
}

const packageRoot = path.resolve(__dirname, '..');
const inventory = JSON.parse(execFileSync(
  process.execPath,
  ['scripts/validate-mermaid-accessibility.mjs', '--json'],
  { cwd: packageRoot, encoding: 'utf8' },
)) as MermaidFence[];
const routeCases = JSON.parse(execFileSync(
  process.execPath,
  ['scripts/validate-mermaid-accessibility.mjs', '--routes-json'],
  { cwd: packageRoot, encoding: 'utf8' },
)) as { name: string; path: string; diagramCount: number }[];
const mermaidBrowserBundle = path.join(packageRoot, 'node_modules/mermaid/dist/mermaid.min.js');

const ssscPlannerPath = '/hve-core/docs/planning/prds/sssc-planner';
const ssscDiagramCount = 5;

async function captureMermaidState(page: Page) {
  const diagrams = page.locator('svg[role~="graphics-document"]');
  await expect(diagrams).toHaveCount(ssscDiagramCount, { timeout: 15000 });
  const session = await page.context().newCDPSession(page);
  const fullTree = await session.send('Accessibility.getFullAXTree');
  await session.detach();
  const accessibilityTree = fullTree.nodes
    .filter((node) => node.role?.value === 'graphics-document')
    .map((node) => ({
      description: node.description?.value ?? '',
      name: node.name?.value ?? '',
      role: node.role?.value ?? '',
    }));
  const geometry = await diagrams.evaluateAll((elements) => elements.map((element) => {
    const svg = element as SVGSVGElement;
    const container = svg.parentElement;
    const rect = svg.getBoundingClientRect();
    const containerRect = container?.getBoundingClientRect();
    const labelledBy = svg.getAttribute('aria-labelledby');
    const describedBy = svg.getAttribute('aria-describedby');
    return {
      description: describedBy ? svg.querySelector(`desc[id="${describedBy}"]`)?.textContent?.trim() ?? '' : '',
      height: rect.height,
      labelCount: Array.from(svg.querySelectorAll('text, foreignObject'))
        .filter((label) => (label.textContent ?? '').trim().length > 0).length,
      name: labelledBy ? svg.querySelector(`title[id="${labelledBy}"]`)?.textContent?.trim() ?? '' : '',
      notClipped: Boolean(containerRect && rect.left >= containerRect.left - 1
        && rect.right <= containerRect.right + 1 && rect.top >= containerRect.top - 1
        && rect.bottom <= containerRect.bottom + 1),
      width: rect.width,
    };
  }));
  return {
    accessibilityTree,
    documentHeight: await page.evaluate(() => document.documentElement.scrollHeight),
    geometry,
    markup: await diagrams.evaluateAll((elements) => elements.map((element) => element.outerHTML).join('\n')),
  };
}

async function reachThemeToggleByKeyboard(page: Page) {
  for (let index = 0; index < 30; index += 1) {
    await page.keyboard.press('Tab');
    const activeName = await page.evaluate(() => {
      const active = document.activeElement;
      return active instanceof HTMLElement
        ? `${active.getAttribute('aria-label') ?? ''} ${active.textContent ?? ''}`.trim()
        : '';
    });
    if (/switch between dark and light mode/i.test(activeName)) {
      return page.getByRole('button', { name: /switch between dark and light mode/i });
    }
  }
  throw new Error('Theme toggle was not reachable through keyboard traversal.');
}

// The source inventory also drives deployed-route coverage so every Mermaid
// fence passes through the production Docusaurus rendering pipeline.
test.describe('Mermaid accessibility', () => {
  test('all deployed source fences render with associated metadata', async ({ page }) => {
    test.setTimeout(120000);
    expect(inventory).toHaveLength(64);

    await page.goto('/hve-core/', { waitUntil: 'domcontentloaded' });
    await page.addScriptTag({ path: mermaidBrowserBundle });

    const result = await page.evaluate(async (fences) => {
      type MermaidApi = {
        initialize: (config: Record<string, unknown>) => void;
        render: (id: string, source: string) => Promise<{ svg: string }>;
      };
      const mermaid = (globalThis as unknown as { mermaid: MermaidApi }).mermaid;
      const failures: string[] = [];
      const families = new Set<string>();

      mermaid.initialize({
        deterministicIds: true,
        deterministicIDSeed: 'hve-core-mermaid-accessibility',
        securityLevel: 'strict',
        startOnLoad: false,
      });

      const inspectSvg = (svgCode: string) => {
        const parsed = new DOMParser().parseFromString(svgCode, 'image/svg+xml');
        const svg = parsed.querySelector('svg');
        if (!svg) {
          throw new Error('rendered output has no SVG root');
        }

        const labelledBy = svg.getAttribute('aria-labelledby')?.trim() ?? '';
        const describedBy = svg.getAttribute('aria-describedby')?.trim() ?? '';
        const title = labelledBy
          ? Array.from(svg.querySelectorAll('title')).find((element) => element.id === labelledBy)
          : null;
        const description = describedBy
          ? Array.from(svg.querySelectorAll('desc')).find((element) => element.id === describedBy)
          : null;

        if (!svg.getAttribute('role')?.split(/\s+/).includes('graphics-document')) {
          throw new Error('SVG is not exposed as a graphics-document');
        }
        if (!title?.textContent?.trim()) {
          throw new Error(`aria-labelledby does not resolve to a non-empty title: ${labelledBy || '<missing>'}`);
        }
        if (!description?.textContent?.trim()) {
          throw new Error(`aria-describedby does not resolve to a non-empty desc: ${describedBy || '<missing>'}`);
        }

        return {
          description: description.textContent.trim(),
          svg,
          title: title.textContent.trim(),
        };
      };

      for (let index = 0; index < fences.length; index += 1) {
        const fence = fences[index];
        const declaration = fence.source.split(/\r?\n/, 1)[0].trim();
        families.add(declaration === 'stateDiagram-v2' ? 'stateDiagram' : declaration.split(/\s+/, 1)[0]);

        try {
          // Mermaid names its temporary render container by prefixing the render id with "d".
          // cspell:disable-next-line
          document.querySelectorAll('[id^="dmermaid_inventory_"]').forEach((element) => element.remove());
          const { svg } = await mermaid.render(`mermaid_inventory_${index + 1}`, fence.source);
          const generated = inspectSvg(svg);
          if (generated.title !== fence.title) {
            throw new Error(`generated title ${JSON.stringify(generated.title)} does not match accTitle`);
          }
          if (generated.description !== fence.description) {
            throw new Error('generated description does not match accDescr');
          }
        } catch (error) {
          failures.push(`${fence.file}:${fence.startLine}: ${error instanceof Error ? error.message : String(error)}`);
        }
      }

      let parseInvalidRejected = false;
      try {
        await mermaid.render('mermaid_invalid_control', `stateDiagram-v2
          accTitle: Invalid transition fixture
          accDescr: Review should move to passed after checks succeed.
          review_requested --> review_passed: Checks pass;<br/>review-passed added`);
      } catch {
        parseInvalidRejected = true;
      }

      let brokenAssociationRejected = false;
      try {
        inspectSvg('<svg role="graphics-document" aria-labelledby="missing-title" aria-describedby="diagram-desc"><title id="other-title">Title</title><desc id="diagram-desc">Description</desc></svg>');
      } catch {
        brokenAssociationRejected = true;
      }

      return {
        brokenAssociationRejected,
        failures,
        families: Array.from(families).sort(),
        parseInvalidRejected,
      };
    }, inventory);

    expect(result.families).toEqual(['erDiagram', 'flowchart', 'graph', 'journey', 'stateDiagram']);
    expect(result.parseInvalidRejected, 'Chrome should reject the locked parse-invalid control').toBe(true);
    expect(result.brokenAssociationRejected, 'The browser assertion should reject a broken title association').toBe(true);
    expect(result.failures, `Complete Mermaid inventory failures:\n${result.failures.join('\n')}`).toEqual([]);
  });

  for (const routeCase of routeCases) {
    test(`${routeCase.name} renders accessible diagrams`, async ({ page }) => {
      await page.goto(routeCase.path, { waitUntil: 'domcontentloaded' });
      await waitForHydration(page);

      const diagrams = page.locator('svg[role~="graphics-document"]');
      await expect(diagrams).toHaveCount(routeCase.diagramCount, { timeout: 15000 });
      await expect(page.locator('pre code.language-mermaid')).toHaveCount(0);

      for (let index = 0; index < routeCase.diagramCount; index += 1) {
        const diagram = diagrams.nth(index);
        const context = `${routeCase.name} diagram ${index + 1}`;

        await expect(diagram, `${context} should have an accessible name`).toHaveAccessibleName(/\S/);
        await expect(diagram, `${context} should have an accessible description`).toHaveAccessibleDescription(/\S/);

        const associations = await diagram.evaluate((svg) => {
          const labelledBy = svg.getAttribute('aria-labelledby');
          const describedBy = svg.getAttribute('aria-describedby');
          const title = labelledBy ? svg.querySelector(`title[id="${labelledBy}"]`) : null;
          const description = describedBy ? svg.querySelector(`desc[id="${describedBy}"]`) : null;
          return {
            describedBy,
            description: description?.textContent?.trim() ?? '',
            labelledBy,
            title: title?.textContent?.trim() ?? '',
          };
        });

        expect(associations.labelledBy, `${context} should reference a title`).toBeTruthy();
        expect(associations.title, `${context} should resolve a non-empty title`).toBeTruthy();
        expect(associations.describedBy, `${context} should reference a description`).toBeTruthy();
        expect(associations.description, `${context} should resolve a non-empty description`).toBeTruthy();
      }
    });
  }

  test('preserves five accessible graphics throughout a keyboard theme transition', async ({ page }) => {
    await page.goto(ssscPlannerPath, { waitUntil: 'domcontentloaded' });
    await waitForHydration(page);
    const before = await captureMermaidState(page);
    expect(before.accessibilityTree).toHaveLength(ssscDiagramCount);
    expect(before.accessibilityTree.map(({ name }) => name)).toEqual(before.geometry.map(({ name }) => name));
    expect(before.geometry.every(({ height, name, description, width }) =>
      height > 0 && width > 0 && name.length > 0 && description.length > 0)).toBe(true);

    await page.evaluate(() => {
      const samples = { diagramCounts: [] as number[], documentHeights: [] as number[], animationFrame: 0 };
      const sample = () => {
        samples.diagramCounts.push(document.querySelectorAll('svg[role~="graphics-document"]').length);
        samples.documentHeights.push(document.documentElement.scrollHeight);
        samples.animationFrame = requestAnimationFrame(sample);
      };
      sample();
      (globalThis as typeof globalThis & { __mermaidTransition?: typeof samples }).__mermaidTransition = samples;
    });

    const toggle = await reachThemeToggleByKeyboard(page);
    await expect(toggle).toBeFocused();
    const initialTheme = await page.locator('html').getAttribute('data-theme');
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const titleBefore = await toggle.getAttribute('title');
      await toggle.press('Enter');
      await expect.poll(() => toggle.getAttribute('title')).not.toBe(titleBefore);
      if (await page.locator('html').getAttribute('data-theme') !== initialTheme) {
        break;
      }
    }
    const during = await captureMermaidState(page);
    expect(during.accessibilityTree).toHaveLength(ssscDiagramCount);
    expect(during.accessibilityTree.map(({ name }) => name)).toEqual(during.geometry.map(({ name }) => name));
    expect(during.geometry.map(({ name }) => name)).toEqual(before.geometry.map(({ name }) => name));
    expect(during.geometry.map(({ description }) => description)).toEqual(before.geometry.map(({ description }) => description));

    await expect.poll(() => page.locator('html').getAttribute('data-theme')).not.toBe(initialTheme);
    await expect.poll(async () => page.locator('svg[role~="graphics-document"]').evaluateAll(
      (elements) => elements.map((element) => element.outerHTML).join('\n'))).not.toBe(before.markup);
    const after = await captureMermaidState(page);
    await expect(toggle).toBeFocused();
    expect(after.accessibilityTree).toHaveLength(ssscDiagramCount);
    expect(after.accessibilityTree.map(({ name }) => name)).toEqual(after.geometry.map(({ name }) => name));
    expect(after.geometry.map(({ name }) => name)).toEqual(before.geometry.map(({ name }) => name));
    expect(after.geometry.map(({ description }) => description)).toEqual(before.geometry.map(({ description }) => description));

    const transition = await page.evaluate(() => {
      const state = (globalThis as typeof globalThis & { __mermaidTransition?: {
        diagramCounts: number[]; documentHeights: number[]; animationFrame: number;
      } }).__mermaidTransition;
      if (state) {
        cancelAnimationFrame(state.animationFrame);
      }
      return state ? { diagramCounts: state.diagramCounts, documentHeights: state.documentHeights } : null;
    });
    expect(transition).not.toBeNull();
    expect(Math.min(...transition!.diagramCounts)).toBe(ssscDiagramCount);
    expect(Math.min(...transition!.documentHeights)).toBeGreaterThanOrEqual(Math.floor(before.documentHeight * 0.9));
  });

  test('keeps the five-diagram route intact across Mermaid adaptive states', async ({ browser }) => {
    const states = [
      { name: '320 CSS pixels', viewport: { width: 320, height: 856 }, deviceScaleFactor: 1 },
      { name: '200% browser zoom', viewport: { width: 640, height: 384 }, deviceScaleFactor: 2 },
      { name: 'WCAG text spacing', viewport: { width: 1280, height: 768 }, deviceScaleFactor: 1, textSpacing: true },
    ];
    for (const state of states) {
      const context = await browser.newContext({ viewport: state.viewport, deviceScaleFactor: state.deviceScaleFactor });
      const page = await context.newPage();
      try {
        await page.goto(ssscPlannerPath, { waitUntil: 'domcontentloaded' });
        await waitForHydration(page);
        if (state.textSpacing) {
          await page.addStyleTag({
            content: '* { line-height: 1.5 !important; letter-spacing: 0.12em !important; word-spacing: 0.16em !important; } p { margin-bottom: 2em !important; }',
          });
        }
        const captured = await captureMermaidState(page);
        expect(captured.geometry.every(({ height, width }) => height > 0 && width > 0), state.name).toBe(true);
        expect(captured.geometry.every(({ notClipped }) => notClipped), `${state.name} container clipping`).toBe(true);
        expect(captured.geometry.every(({ labelCount }) => labelCount > 0), `${state.name} rendered labels`).toBe(true);
        expect(await page.evaluate(() => document.documentElement.scrollWidth
          <= document.documentElement.clientWidth + 1), `${state.name} document-level horizontal scrolling`).toBe(true);
      } finally {
        await context.close();
      }
    }
  });
});
