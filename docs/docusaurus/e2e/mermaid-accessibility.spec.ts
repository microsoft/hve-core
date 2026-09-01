// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { expect, test } from '@playwright/test';
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
});
