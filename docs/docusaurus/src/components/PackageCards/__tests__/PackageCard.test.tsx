// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { axe, toHaveNoViolations } from 'jest-axe';
import PackageCard from '../index';

expect.extend(toHaveNoViolations);

const defaultProps = {
  name: 'hve-core',
  title: 'HVE Core',
  description: 'RPI workflow, planning, and implementation',
  artifacts: 59,
  contents: [
    { kind: 'agents' as const, label: 'Agents', count: 20, href: '/docs/reference/agents' },
    { kind: 'prompts' as const, label: 'Prompts', count: 15, href: '/docs/reference/prompts' },
    { kind: 'instructions' as const, label: 'Instructions', count: 14, href: '/docs/reference/instructions' },
    { kind: 'skills' as const, label: 'Skills', count: 10, href: '/docs/reference/skills' },
  ],
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

  it('associates a collapsed contents panel with the disclosure button', () => {
    render(<PackageCard {...defaultProps} />);

    const button = screen.getByRole('button', { name: 'Show package contents' });
    const panel = document.getElementById(button.getAttribute('aria-controls') ?? '');

    expect(button).toHaveAttribute('aria-expanded', 'false');
    expect(panel).toHaveAttribute('hidden');
  });

  it('toggles package contents while retaining trigger focus', () => {
    render(<PackageCard {...defaultProps} />);

    const button = screen.getByRole('button', { name: 'Show package contents' });
    const panel = document.getElementById(button.getAttribute('aria-controls') ?? '');
    button.focus();
    fireEvent.click(button);

    expect(button).toHaveAccessibleName('Hide package contents');
    expect(button).toHaveAttribute('aria-expanded', 'true');
    expect(button).toHaveFocus();
    expect(panel).not.toHaveAttribute('hidden');

    fireEvent.click(button);
    expect(button).toHaveAccessibleName('Show package contents');
    expect(button).toHaveAttribute('aria-expanded', 'false');
    expect(button).toHaveFocus();
    expect(panel).toHaveAttribute('hidden');
  });

  it('links expanded summaries and the package overview', () => {
    render(<PackageCard {...defaultProps} />);

    fireEvent.click(screen.getByRole('button', { name: 'Show package contents' }));

    expect(screen.getByRole('link', { name: 'Agents' })).toHaveAttribute(
      'href',
      '/docs/reference/agents',
    );
    expect(screen.getByRole('link', { name: 'Prompts' })).toHaveAttribute(
      'href',
      '/docs/reference/prompts',
    );
    expect(screen.getByRole('link', { name: 'Instructions' })).toHaveAttribute(
      'href',
      '/docs/reference/instructions',
    );
    expect(screen.getByRole('link', { name: 'Skills' })).toHaveAttribute(
      'href',
      '/docs/reference/skills',
    );
    expect(screen.getByRole('link', { name: 'View package overview' })).toHaveAttribute(
      'href',
      '/docs/getting-started/packages',
    );
  });

  it('has no accessibility violations when collapsed', async () => {
    const { container } = render(<PackageCard {...defaultProps} />);

    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });

    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations when expanded', async () => {
    const { container } = render(<PackageCard {...defaultProps} />);
    fireEvent.click(screen.getByRole('button', { name: 'Show package contents' }));

    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });

    expect(results).toHaveNoViolations();
  });
});
