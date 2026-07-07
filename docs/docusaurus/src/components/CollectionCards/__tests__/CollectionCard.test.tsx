// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { axe, toHaveNoViolations } from 'jest-axe';
import CollectionCard from '../index';

expect.extend(toHaveNoViolations);

describe('CollectionCard', () => {
  const defaultProps = {
    name: 'hve-core',
    title: 'HVE Core',
    description: 'RPI workflow, planning, and implementation',
    artifacts: 40,
    maturity: 'Stable' as const,
    href: '/docs/getting-started/collections',
  };

  it('renders the human-readable title and description', () => {
    render(<CollectionCard {...defaultProps} />);
    expect(screen.getByText('HVE Core')).toBeInTheDocument();
    expect(screen.getByText('RPI workflow, planning, and implementation')).toBeInTheDocument();
  });

  it('exposes the machine name as a data attribute', () => {
    const { container } = render(<CollectionCard {...defaultProps} />);
    expect(container.querySelector('[data-name="hve-core"]')).toBeInTheDocument();
  });

  it('links to the correct href', () => {
    render(<CollectionCard {...defaultProps} />);
    const link = screen.getByText('HVE Core').closest('a');
    expect(link).toHaveAttribute('href', '/docs/getting-started/collections');
  });

  it('renders artifact count', () => {
    render(<CollectionCard {...defaultProps} />);
    expect(screen.getByText('40')).toBeInTheDocument();
    expect(screen.getByText('artifacts')).toBeInTheDocument();
  });

  it('renders Stable maturity badge', () => {
    render(<CollectionCard {...defaultProps} maturity="Stable" />);
    expect(screen.getByText('Stable')).toBeInTheDocument();
  });

  it('renders Preview maturity badge', () => {
    render(<CollectionCard {...defaultProps} maturity="Preview" />);
    expect(screen.getByText('Preview')).toBeInTheDocument();
  });

  it('renders Experimental maturity badge', () => {
    render(<CollectionCard {...defaultProps} maturity="Experimental" />);
    expect(screen.getByText('Experimental')).toBeInTheDocument();
  });

  it('renders as an article element', () => {
    const { container } = render(<CollectionCard {...defaultProps} />);
    expect(container.querySelector('article')).toBeInTheDocument();
  });

  it('has no accessibility violations', async () => {
    const { container } = render(<CollectionCard {...defaultProps} />);
    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });
    expect(results).toHaveNoViolations();
  });
});
