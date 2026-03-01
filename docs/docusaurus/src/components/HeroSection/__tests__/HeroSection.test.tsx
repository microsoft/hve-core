import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import HeroSection from '..';

describe('HeroSection', () => {
  it('renders title and subtitle', () => {
    render(<HeroSection title="Hello World" subtitle="A subtitle" />);
    expect(screen.getByText('Hello World')).toBeInTheDocument();
    expect(screen.getByText('A subtitle')).toBeInTheDocument();
  });

  it('renders title in an h1 element', () => {
    render(<HeroSection title="Heading" subtitle="Sub" />);
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Heading');
  });
});
