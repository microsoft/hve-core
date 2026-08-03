// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import Home from '../index';
import { packageCardDefinitions } from '../../data/packageCards';
import { labelRegistry } from '../../data/labelRegistry';

describe('Home page', () => {
  it('renders a single level-1 hero heading', () => {
    render(<Home />);

    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
  });

  it('wraps content in a main landmark with the three labelled sections', () => {
    const { container } = render(<Home />);

    const main = container.querySelector('main');
    expect(main).toBeInTheDocument();
    expect(main?.querySelector('[aria-labelledby="featured-title"]')).toBeInTheDocument();
    expect(main?.querySelector('[aria-labelledby="deep-dive-title"]')).toBeInTheDocument();
    expect(main?.querySelector('[aria-labelledby="packages-title"]')).toBeInTheDocument();
  });

  it('renders the purpose statement inside the main landmark', () => {
    const { container } = render(<Home />);

    expect(container.querySelector('main')?.textContent).toContain(
      'idea to a shipped solution',
    );
  });

  it('renders a visually-hidden Featured resources heading', () => {
    render(<Home />);

    expect(screen.getByText('Featured resources')).toBeInTheDocument();
  });

  it('titles the packages section from the label registry', () => {
    const { container } = render(<Home />);

    expect(container.querySelector('#packages-title')).toHaveTextContent(
      labelRegistry.packages,
    );
  });

  it('offers a hero call to action that browses the marketplace packages', () => {
    render(<Home />);

    const cta = screen.getByRole('link', { name: 'Browse Marketplace Packages' });
    expect(cta).toHaveAttribute('href', '/docs/getting-started/packages');
  });

  it('renders exactly one package card for the hve-core identity', () => {
    const { container } = render(<Home />);

    const section = container.querySelector('[aria-labelledby="packages-title"]');
    const cards = section?.querySelectorAll('article[data-name]') ?? [];
    const names = Array.from(cards).map((card) => card.getAttribute('data-name'));
    expect(names).toEqual(packageCardDefinitions.map((definition) => definition.name));
    expect(names).toEqual(['hve-core']);
  });

  it('points the package card at the packages route', () => {
    const { container } = render(<Home />);

    const section = container.querySelector('[aria-labelledby="packages-title"]');
    const links = section?.querySelectorAll('article[data-name] a') ?? [];
    expect(links.length).toBe(packageCardDefinitions.length);
    for (const link of Array.from(links)) {
      expect(link).toHaveAttribute('href', '/docs/getting-started/packages');
    }
  });
});
