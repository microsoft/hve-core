// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { afterEach, describe, expect, it, jest } from '@jest/globals';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import '@testing-library/jest-dom';
import { axe, toHaveNoViolations } from 'jest-axe';
import DemoMaterialCatalog from '../index';

expect.extend(toHaveNoViolations);

const mockFetch = jest.fn();
Object.defineProperty(globalThis, 'fetch', { configurable: true, value: mockFetch });

function response(body: object): Response {
  return {
    ok: true,
    json: async () => body,
  } as Response;
}

function indexWithL100() {
  return {
    schema_version: 'demo-material-site/v2',
    levels: {
      L100: {
        renderer: 'hve-slides', format: 'html', render_schema_version: 2, manifest_schema_version: 6,
        files: {
          page: 'L100/index.html',
          html: 'L100/hve-demo-L100.html',
          mp4: 'L100/hve-demo-L100.mp4',
          vtt: 'L100/hve-demo-L100.vtt',
        },
      },
      L400: {
        last_failed_attempt: { checks: { 'T-07': { result: 'fail' } } },
      },
    },
  };
}

afterEach(() => mockFetch.mockReset());

describe('DemoMaterialCatalog', () => {
  it('compiles the documentation page as a React catalog with the site configuration', () => {
    const result = spawnSync(process.execPath, ['--input-type=commonjs', '-e', `
      const assert = require('node:assert/strict');
      const fs = require('node:fs');
      const path = require('node:path');
      const { DEFAULT_PARSE_FRONT_MATTER } = require('@docusaurus/utils');
      const { loadSiteConfig } = require('@docusaurus/core/lib/server/config');
      const { compileToJSX } = require('@docusaurus/mdx-loader/lib/utils');

      (async () => {
        const siteDir = process.cwd();
        const { siteConfig } = await loadSiteConfig({ siteDir });
        const filePath = path.resolve(siteDir, '../demo-material/README.md');
        const fileContent = fs.readFileSync(filePath, 'utf8');
        const { frontMatter } = await DEFAULT_PARSE_FRONT_MATTER({ fileContent });
        const compiled = await compileToJSX({
          filePath,
          fileContent,
          frontMatter,
          options: {
            ...siteConfig.presets[0][1].docs,
            siteDir,
            staticDirs: siteConfig.staticDirectories.map(directory => path.resolve(siteDir, directory)),
            markdownConfig: siteConfig.markdown,
          },
        });
        assert.ok(compiled.content.includes('_jsx(DemoMaterialCatalog,'));
        assert.ok(!compiled.content.includes('DemoMaterialCatalog'.toLowerCase()));
        console.log('catalog compiled');
      })().catch(error => { console.error(error); process.exitCode = 1; });
    `], { cwd: path.resolve(__dirname, '../../../..'), encoding: 'utf8', timeout: 30_000 });

    expect(result.error).toBeUndefined();
    expect(result.stderr).toBe('');
    expect(result.status).toBe(0);
    expect(result.stdout.trim()).toBe('catalog compiled');
  });

  it('renders links only for levels with a complete published file map', async () => {
    mockFetch.mockResolvedValue(response(indexWithL100()));

    render(<DemoMaterialCatalog />);

    expect(await screen.findByText('Showing currently published demo material.')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Download MP4' })).toHaveAttribute(
      'href',
      '/demo-material/L100/hve-demo-L100.mp4',
    );
    expect(screen.getByText('Not published (T-07 did not pass)')).toBeInTheDocument();
    expect(screen.getByText('L400').closest('tr')).not.toContainElement(
      screen.getByRole('link', { name: 'Download MP4' }),
    );
  });

  it('hides every download link when publication status cannot be loaded', async () => {
    mockFetch.mockRejectedValue(new Error('offline'));

    render(<DemoMaterialCatalog />);

    expect(
      await screen.findByText(
        'Publication status is temporarily unavailable. Download links are hidden.',
      ),
    ).toBeInTheDocument();
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
  });

  it('has no accessibility violations after loading', async () => {
    mockFetch.mockResolvedValue(response(indexWithL100()));
    const { container } = render(<DemoMaterialCatalog />);
    await waitFor(() => expect(screen.getByText('Not published (T-07 did not pass)')).toBeInTheDocument());

    const results = await axe(container, { rules: { region: { enabled: false } } });

    expect(results).toHaveNoViolations();
  });

  it('hides links for a bundle missing its required WebVTT', async () => {
    const index = indexWithL100();
    Reflect.deleteProperty(index.levels.L100.files, 'vtt');
    mockFetch.mockResolvedValue(response(index));

    render(<DemoMaterialCatalog />);

    await screen.findByText('Showing currently published demo material.');
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
  });

  it.each([null, [], 'invalid'])('handles malformed nested checks (%s)', async (check) => {
    mockFetch.mockResolvedValue(response({
      schema_version: 'demo-material-site/v2',
      levels: { L400: { last_failed_attempt: { checks: { 'T-07': check } } } },
    }));

    render(<DemoMaterialCatalog />);

    await screen.findByRole('alert');
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
  });
});
