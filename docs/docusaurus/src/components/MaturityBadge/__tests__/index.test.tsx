// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { describe, it, expect, jest } from '@jest/globals';
import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom/jest-globals'; 
import { axe, toHaveNoViolations } from 'jest-axe';
import MaturityBadge, { normalizeMaturity } from '../index';

expect.extend(toHaveNoViolations);

describe('normalizeMaturity', () => {
  it('converts lowercase YAML string to Title-case', () => {
    expect(normalizeMaturity('stable')).toBe('Stable');
    expect(normalizeMaturity('preview')).toBe('Preview');
    expect(normalizeMaturity('experimental')).toBe('Experimental');
  });

  it('handles already Title-cased string', () => {
    expect(normalizeMaturity('Stable')).toBe('Stable');
  });

  it('returns Unknown for invalid, empty, or missing values (Fallback Pattern)', () => {
    expect(normalizeMaturity('unknown')).toBe('Unknown');
    expect(normalizeMaturity('typo')).toBe('Unknown');
    expect(normalizeMaturity('')).toBe('Unknown');
  });
  
  it('logs a warning in dev environment for unknown values (Guardrail Pattern)', () => {
    const originalEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'development';
    const consoleSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    
    normalizeMaturity('invalid-yaml-value');
    
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Unrecognized maturity value')
    );
    
    consoleSpy.mockRestore();
    process.env.NODE_ENV = originalEnv;
  });
});

describe('MaturityBadge', () => {
  it.each([
    ['stable', 'Stable', '✅', 'maturityStable', 'Production-ready, fully supported, and generally available (GA) for everyday use.'],
    ['preview', 'Preview', '🔶', 'maturityPreview', 'Available for early adoption and testing, but may contain breaking changes.'],
    ['experimental', 'Experimental', '🧪', 'maturityExperimental', 'Early-stage proof of concept. Not recommended for production environments.'],
  ] as const)(
    'renders the %s maturity badge with correct icon, class, and tooltip text',
    (input, expectedText, expectedIcon, expectedClass, glossary) => {
      render(<MaturityBadge maturity={input} />);

      const badgeLink = screen.getByText(expectedText);
      expect(badgeLink).toBeInTheDocument();
      
      const wrapper = badgeLink.parentElement;
      expect(wrapper).toHaveClass('badgeWrapper', expectedClass);
      
      expect(screen.getByText(expectedIcon)).toBeInTheDocument();
      
      const tooltip = screen.getByRole('tooltip');
      expect(tooltip).toBeInTheDocument();
      expect(tooltip).toHaveTextContent(glossary);
    },
  );

  it('renders the Unknown fallback UI for unrecognized values', () => {

    const consoleSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    
    render(<MaturityBadge maturity="completely-invalid" />);
    
    const badgeLink = screen.getByText('Unknown');
    expect(badgeLink).toBeInTheDocument();
    
    const wrapper = badgeLink.parentElement;
    expect(wrapper).toHaveClass('badgeWrapper', 'maturityUnknown');
    
    expect(screen.getByText('❓')).toBeInTheDocument();
    expect(screen.getByRole('tooltip')).toHaveTextContent('This maturity level is not recognized');
    
    consoleSpy.mockRestore();
  });

  it('renders as an anchor tag when href is provided', () => {
    render(<MaturityBadge maturity="stable" href="/docs/stable" />);
    const link = screen.getByRole('link', { name: /Stable/i });
    expect(link.tagName.toLowerCase()).toBe('a');
    expect(link).toHaveAttribute('href', '/docs/stable');
  });

  it('renders as a focusable span when no href is provided', () => {
    render(<MaturityBadge maturity="stable" />);
    const interactiveElement = screen.getByRole('button', { name: /Stable/i });
    expect(interactiveElement.tagName.toLowerCase()).toBe('span');
    expect(interactiveElement).toHaveAttribute('tabIndex', '0');
  });

  it('has no accessibility violations', async () => {
    const { container } = render(<MaturityBadge maturity="stable" />);
    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });
    expect(results).toHaveNoViolations();
  });
});
