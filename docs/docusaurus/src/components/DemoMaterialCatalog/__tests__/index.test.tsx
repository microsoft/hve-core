// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { afterEach, describe, expect, it, jest } from '@jest/globals';
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
    schema_version: 'demo-material-site/v1',
    levels: {
      L100: {
        files: {
          page: 'L100/index.html',
          html: 'L100/hve-demo-L100.html',
          pptx: 'L100/hve-demo-L100.pptx',
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
      schema_version: 'demo-material-site/v1',
      levels: { L400: { last_failed_attempt: { checks: { 'T-07': check } } } },
    }));

    render(<DemoMaterialCatalog />);

    await screen.findByRole('alert');
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
  });
});