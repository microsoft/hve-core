import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import BoxCard from '../BoxCard';

describe('BoxCard', () => {
  const defaultProps = {
    title: 'Box Title',
    links: [
      { label: 'Link One', href: '/link-1' },
      { label: 'Link Two', href: '/link-2' },
    ],
  };

  it('renders title', () => {
    render(<BoxCard {...defaultProps} />);
    expect(screen.getByText('Box Title')).toBeInTheDocument();
  });

  it('renders all links', () => {
    render(<BoxCard {...defaultProps} />);
    expect(screen.getByText('Link One')).toBeInTheDocument();
    expect(screen.getByText('Link Two')).toBeInTheDocument();
  });

  it('renders description when provided', () => {
    render(<BoxCard {...defaultProps} description="A box description" />);
    expect(screen.getByText('A box description')).toBeInTheDocument();
  });

  it('omits description when not provided', () => {
    const { container } = render(<BoxCard {...defaultProps} />);
    expect(container.querySelector('.cardDescription')).toBeNull();
  });

  it('renders icon when provided', () => {
    const { container } = render(<BoxCard {...defaultProps} icon="/img/test.svg" />);
    const img = container.querySelector('img');
    expect(img).toBeInTheDocument();
    expect(img).toHaveAttribute('src', '/img/test.svg');
  });

  it('omits icon when not provided', () => {
    const { container } = render(<BoxCard {...defaultProps} />);
    expect(container.querySelector('img')).toBeNull();
  });
});
