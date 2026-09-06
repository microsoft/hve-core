// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { describe, it, expect } from '@jest/globals';
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

  it('defaults to Experimental for unknown values', () => {
    expect(normalizeMaturity('unknown')).toBe('Experimental');
  });
});

describe('MaturityBadge', () => {
  it.each([
    ['stable', 'Stable', '✅', 'maturityStable', 'Stable means the package is broadly available and validated for everyday use.'],
    ['preview', 'Preview', '🔶', 'maturityPreview', 'Preview means the package is available for early adoption and feedback.'],
    ['experimental', 'Experimental', '🧪', 'maturityExperimental', 'Experimental means the package is early-stage and may change quickly.'],
  ] as const)(
    'renders the %s maturity badge with correct icon, class, and glossary text',
    (input, expectedText, expectedIcon, expectedClass, glossary) => {
      render(<MaturityBadge maturity={input} />);

      const badge = screen.getByText(expectedText);
      
      expect(badge).toBeInTheDocument();
      expect(badge).toHaveClass('maturityBadge', expectedClass);
      expect(badge).toHaveAttribute('title', glossary);
      expect(badge).toHaveAttribute('aria-label', `${expectedText}: ${glossary}`);
      
      expect(screen.getByText(expectedIcon)).toBeInTheDocument();
    },
  );

  it('has no accessibility violations', async () => {
    const { container } = render(<MaturityBadge maturity="stable" />);
    const results = await axe(container, {
      rules: { region: { enabled: false } },
    });
    expect(results).toHaveNoViolations();
  });
});
