// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { axe } from 'jest-axe';
import SlidesPage from '../slides';

let mockDecks: unknown;
let mockBaseUrl: string;

jest.mock('@docusaurus/useDocusaurusContext', () => ({
  __esModule: true,
  default: () => ({ siteConfig: { customFields: { slideDecks: mockDecks } } }),
}));
jest.mock('@docusaurus/useBaseUrl', () => ({
  __esModule: true,
  default: (url: string) => `${mockBaseUrl}${url}`,
}));

beforeEach(() => {
  mockBaseUrl = '/hve-core';
  mockDecks = [
    { slug: 'hve-updates', title: 'HVE Core updates', description: 'Recent workflow changes.' },
    { slug: 'hve-full', title: 'Full HVE overview', description: 'An introduction to every workflow.' },
  ];
});

test('lists every deck with base-path-aware native navigation and download links', async () => {
  const { container } = render(<SlidesPage />);
  expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
  expect(screen.getByRole('main')).toBeInTheDocument();
  for (const [slug, title, description] of [
    ['hve-updates', 'HVE Core updates', 'Recent workflow changes.'],
    ['hve-full', 'Full HVE overview', 'An introduction to every workflow.'],
  ]) {
    expect(screen.getByRole('heading', { name: title, level: 3 })).toBeInTheDocument();
    expect(screen.getByText(description)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: `Open ${title}` }))
      .toHaveAttribute('href', `/hve-core/slides/${slug}.html`);
    expect(screen.getByRole('link', { name: `Download ${title} (HTML)` }))
      .toHaveAttribute('download');
  }
  expect((await axe(container)).violations).toEqual([]);
});

test('also resolves links for a site hosted at the domain root', () => {
  mockBaseUrl = '';
  render(<SlidesPage />);
  expect(screen.getByRole('link', { name: 'Open HVE Core updates' }))
    .toHaveAttribute('href', '/slides/hve-updates.html');
});

test('reports an empty catalog without broken links', () => {
  mockDecks = [];
  render(<SlidesPage />);
  expect(screen.getByText('No presentations have been published yet.')).toBeInTheDocument();
  expect(screen.queryAllByRole('link')).toHaveLength(0);
});

test.each([
  { decks: undefined },
  { decks: [{ slug: '../outside' }] },
  { decks: [{ slug: 42 }] },
  { decks: [{ slug: 'no-title', description: 'Description' }] },
  { decks: [{ slug: 'no-description', title: 'Title', description: ' ' }] },
  { decks: [null] },
])(
  'rejects an invalid catalog rather than silently omitting it: $decks',
  ({ decks }) => {
    mockDecks = decks;
    expect(() => render(<SlidesPage />)).toThrow('slide catalog is missing or invalid');
  },
);

test('renders generated labels as text and does not derive routes from titles', () => {
  mockDecks = [{ slug: 'custom-guide', title: 'HVE <guide> & examples', description: 'Example "quotes".' }];
  const { container } = render(<SlidesPage />);
  expect(screen.getByRole('heading', { name: 'HVE <guide> & examples' })).toBeInTheDocument();
  expect(screen.getByRole('link', { name: 'Open HVE <guide> & examples' }))
    .toHaveAttribute('href', '/hve-core/slides/custom-guide.html');
  expect(container.querySelector('guide')).toBeNull();
});
