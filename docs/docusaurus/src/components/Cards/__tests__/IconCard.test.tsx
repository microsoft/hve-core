import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import IconCard from '../IconCard';

describe('IconCard', () => {
  const defaultProps = {
    icon: <span data-testid="test-icon">🚀</span>,
    supertitle: 'Category',
    title: 'Card Title',
    href: '/test-link',
  };

  it('renders supertitle and title', () => {
    render(<IconCard {...defaultProps} />);
    expect(screen.getByText('Category')).toBeInTheDocument();
    expect(screen.getByText('Card Title')).toBeInTheDocument();
  });

  it('links to the correct href', () => {
    render(<IconCard {...defaultProps} />);
    const link = screen.getByText('Card Title').closest('a');
    expect(link).toHaveAttribute('href', '/test-link');
  });

  it('renders the icon', () => {
    render(<IconCard {...defaultProps} />);
    expect(screen.getByTestId('test-icon')).toBeInTheDocument();
  });

  it('renders description when provided', () => {
    render(<IconCard {...defaultProps} description="A description" />);
    expect(screen.getByText('A description')).toBeInTheDocument();
  });

  it('omits description when not provided', () => {
    const { container } = render(<IconCard {...defaultProps} />);
    expect(container.querySelector('.cardDescription')).toBeNull();
  });
});
