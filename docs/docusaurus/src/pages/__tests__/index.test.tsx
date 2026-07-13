// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import Home from '../index';

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
    expect(main?.querySelector('[aria-labelledby="collections-title"]')).toBeInTheDocument();
  });

  it('renders the purpose statement inside the main landmark', () => {
    const { container } = render(<Home />);
    const main = container.querySelector('main');
    expect(main?.textContent).toContain('idea to a shipped solution');
  });

  it('renders a visually-hidden Featured resources heading', () => {
    render(<Home />);
    expect(screen.getByText('Featured resources')).toBeInTheDocument();
  });
});
