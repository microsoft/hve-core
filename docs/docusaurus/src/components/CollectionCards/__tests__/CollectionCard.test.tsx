import React from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import '@testing-library/jest-dom';
import { axe, toHaveNoViolations } from 'jest-axe';
import CollectionCard from '../index';

// Mock test 
jest.mock('@docusaurus/Link', () => {
  return ({ children, to, ...rest }: any) => (
    <a href={to} {...rest}>{children}</a>
  );
});

expect.extend(toHaveNoViolations);

describe('CollectionCard', () => {
  const defaultProps = {
    name: 'hve-core',
    description: 'RPI workflow, planning, and implementation',
    extendedDescription: 'Full details about HVE Core',
    artifacts: 40,
    maturity: 'Stable' as const,
    href: '/docs/getting-started/collections',
  };

  it('renders name and description', () => {
    render(<CollectionCard {...defaultProps} />);
    expect(screen.getByText('hve-core')).toBeInTheDocument();
    expect(
      screen.getByText('RPI workflow, planning, and implementation')
    ).toBeInTheDocument();
  });

  it('links to the correct href', () => {
    render(<CollectionCard {...defaultProps} />);
    const link = screen.getByText('hve-core').closest('a');
    expect(link).toHaveAttribute(
      'href',
      '/docs/getting-started/collections'
    );
  });

  it('renders artifact count', () => {
    render(<CollectionCard {...defaultProps} />);
    expect(screen.getByText('40')).toBeInTheDocument();
    expect(screen.getByText('artifacts')).toBeInTheDocument();
  });

  it('renders maturity badges', () => {
    const { rerender } = render(
      <CollectionCard {...defaultProps} maturity="Stable" />
    );
    expect(screen.getByText('Stable')).toBeInTheDocument();

    rerender(<CollectionCard {...defaultProps} maturity="Preview" />);
    expect(screen.getByText('Preview')).toBeInTheDocument();

    rerender(<CollectionCard {...defaultProps} maturity="Experimental" />);
    expect(screen.getByText('Experimental')).toBeInTheDocument();
  });

  it('renders as an article element', () => {
    const { container } = render(<CollectionCard {...defaultProps} />);
    expect(container.querySelector('article')).toBeInTheDocument();
  });

  /*  NEW TESTS */

  it('does NOT show extended description by default', () => {
    render(<CollectionCard {...defaultProps} />);
    expect(
      screen.queryByText('Full details about HVE Core')
    ).not.toBeInTheDocument();
  });

  it('shows toggle button when extendedDescription exists', () => {
    render(<CollectionCard {...defaultProps} />);
    expect(
      screen.getByRole('button', { name: /show details/i })
    ).toBeInTheDocument();
  });

  it('toggles extended description on click', async () => {
    const user = userEvent.setup();
    render(<CollectionCard {...defaultProps} />);

    const button = screen.getByRole('button', {
      name: /show details/i,
    });

    // Expand
    await user.click(button);
    expect(
      screen.getByText('Full details about HVE Core')
    ).toBeInTheDocument();
    expect(button).toHaveAttribute('aria-expanded', 'true');

    // Collapse
    await user.click(button);
    expect(
      screen.queryByText('Full details about HVE Core')
    ).not.toBeInTheDocument();
    expect(button).toHaveAttribute('aria-expanded', 'false');
  });

  it('supports keyboard interaction (Enter)', async () => {
    const user = userEvent.setup();
    render(<CollectionCard {...defaultProps} />);

    const button = screen.getByRole('button');

    button.focus();
    await user.keyboard('{Enter}');

    expect(
      screen.getByText('Full details about HVE Core')
    ).toBeInTheDocument();
  });

  /* ACCESSIBILITY */

  it('has no accessibility violations (collapsed)', async () => {
    const { container } = render(<CollectionCard {...defaultProps} />);
    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });
    expect(results).toHaveNoViolations();
  });

  it('has no accessibility violations (expanded)', async () => {
    const user = userEvent.setup();
    const { container } = render(<CollectionCard {...defaultProps} />);

    const button = screen.getByRole('button');
    await user.click(button);

    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });

    expect(results).toHaveNoViolations();
  });
});
