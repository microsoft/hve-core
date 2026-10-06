// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import * as path from 'path';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import Home from '../index';
import type { PackageCardData } from '../../data/packageCards';
import { loadPackageCards } from '../../data/pluginManifestCards';
import { labelRegistry } from '../../data/labelRegistry';
import {
  __resetPackageCards,
  __setPackageCards,
} from '../../__mocks__/@docusaurus/useDocusaurusContext';

const marketplacePath = path.resolve(
  __dirname,
  '../../../../../.github/plugin/marketplace.json',
);

function card(name: string, overrides: Partial<PackageCardData> = {}): PackageCardData {
  return {
    name,
    title: `HVE Core - ${name}`,
    description: `${name} description`,
    artifacts: 3,
    contents: [
      { kind: 'agents', label: 'Agents', count: 3, href: '/docs/reference/agents' },
    ],
    maturity: 'Stable',
    href: `/docs/plugins/${name}`,
    ...overrides,
  };
}

function renderedCards(container: HTMLElement) {
  const section = container.querySelector('[aria-labelledby="packages-title"]');
  return Array.from(section?.querySelectorAll('article[data-name]') ?? []);
}

afterEach(() => {
  __resetPackageCards();
});

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

  it('describes the package section as multiple choices', () => {
    const { container } = render(<Home />);
    expect(container.querySelector('[aria-labelledby="packages-title"]')).toHaveTextContent(
      'packages',
    );
  });
});

describe('Home page package cards from customFields', () => {
  it('renders no cards when the custom field is empty', () => {
    const { container } = render(<Home />);
    expect(renderedCards(container)).toHaveLength(0);
  });

  it('renders every supplied card in order and removes absent cards', () => {
    __setPackageCards([card('alpha'), card('beta')]);
    const first = render(<Home />);
    expect(renderedCards(first.container).map((node) => node.getAttribute('data-name'))).toEqual([
      'alpha', 'beta',
    ]);
    first.unmount();

    __setPackageCards([card('alpha')]);
    const second = render(<Home />);
    expect(renderedCards(second.container).map((node) => node.getAttribute('data-name'))).toEqual([
      'alpha',
    ]);
  });

  it('renders card title, maturity, count, and documentation link', () => {
    __setPackageCards([card('preview-one', {
      title: 'Preview Package', artifacts: 12, maturity: 'Preview',
    })]);
    const { container } = render(<Home />);
    const [node] = renderedCards(container);
    expect(node).toHaveTextContent('Preview Package');
    expect(node).toHaveTextContent('Preview');
    expect(node).toHaveTextContent('12');
    expect(node.querySelector('a')).toHaveAttribute('href', '/docs/plugins/preview-one');
  });

  it('renders the current canonical catalog cards', () => {
    const cards = loadPackageCards(marketplacePath);
    __setPackageCards(cards);
    const { container } = render(<Home />);
    expect(renderedCards(container).map((node) => node.getAttribute('data-name'))).toEqual(
      cards.map((entry) => entry.name),
    );
  });
});
