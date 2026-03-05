import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import { axe, toHaveNoViolations } from 'jest-axe';
import CardGrid from '../CardGrid';

expect.extend(toHaveNoViolations);

describe('CardGrid', () => {
  it('renders children', () => {
    render(<CardGrid><div>child content</div></CardGrid>);
    expect(screen.getByText('child content')).toBeInTheDocument();
  });

  it('applies default cardGrid class', () => {
    const { container } = render(<CardGrid><div>child</div></CardGrid>);
    expect(container.firstChild).toHaveClass('cardGrid');
  });

  it('applies 2-column class', () => {
    const { container } = render(<CardGrid columns={2}><div>child</div></CardGrid>);
    expect(container.firstChild).toHaveClass('cardGridTwo');
  });

  it('applies 4-column class', () => {
    const { container } = render(<CardGrid columns={4}><div>child</div></CardGrid>);
    expect(container.firstChild).toHaveClass('cardGridFour');
  });

  it('has no accessibility violations', async () => {
    const { container } = render(<CardGrid><div>child</div></CardGrid>);
    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });
    expect(results).toHaveNoViolations();
  });
});
