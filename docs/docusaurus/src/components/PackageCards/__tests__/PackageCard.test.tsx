// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { axe, toHaveNoViolations } from 'jest-axe';
import PackageCard from '../index';

expect.extend(toHaveNoViolations);

const defaultProps = {
  name: 'hve-core',
  title: 'HVE Core',
  description: 'RPI workflow, planning, and implementation',
  artifacts: 59,
  maturity: 'Stable' as const,
  href: '/docs/getting-started/packages',
};

describe('PackageCard', () => {
  it('renders the human-readable title and description', () => {
    render(<PackageCard {...defaultProps} />);

    expect(screen.getByText('HVE Core')).toBeInTheDocument();
    expect(
      screen.getByText('RPI workflow, planning, and implementation'),
    ).toBeInTheDocument();
  });

  it('renders as an article exposing the package id as a data attribute', () => {
    const { container } = render(<PackageCard {...defaultProps} />);

    const article = container.querySelector('article');
    expect(article).toBeInTheDocument();
    expect(article).toHaveAttribute('data-name', 'hve-core');
  });

  it('links the title to the packages route', () => {
    render(<PackageCard {...defaultProps} />);

    expect(screen.getByText('HVE Core').closest('a')).toHaveAttribute(
      'href',
      '/docs/getting-started/packages',
    );
  });

  it('renders the artifact count', () => {
    render(<PackageCard {...defaultProps} />);

    expect(screen.getByText('59')).toBeInTheDocument();
    expect(screen.getByText('artifacts')).toBeInTheDocument();
  });

  it.each([
    ['Stable', 'maturityStable', 'Stable means the package is broadly available and validated for everyday use.'],
    ['Preview', 'maturityPreview', 'Preview means the package is available for early adoption and feedback.'],
    ['Experimental', 'maturityExperimental', 'Experimental means the package is early-stage and may change quickly.'],
  ] as const)(
    'renders the %s maturity badge with its own class and glossary text',
    (maturity, maturityClass, glossary) => {
      render(<PackageCard {...defaultProps} maturity={maturity} />);

      const badge = screen.getByText(maturity);
      expect(badge).toHaveClass('maturityBadge', maturityClass);
      expect(badge).toHaveAttribute('title', glossary);
      expect(badge).toHaveAttribute('aria-label', `${maturity}: ${glossary}`);
    },
  );

  it('places the title link inside a level-3 heading', () => {
    render(<PackageCard {...defaultProps} />);

    expect(screen.getByRole('heading', { level: 3 })).toHaveTextContent('HVE Core');
  });

  it('has no accessibility violations', async () => {
    const { container } = render(<PackageCard {...defaultProps} />);

    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });

    expect(results).toHaveNoViolations();
  });
});
