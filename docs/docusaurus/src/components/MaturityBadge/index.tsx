// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, { useId } from 'react';
import styles from './styles.module.css';

export type KnownMaturity = 'Stable' | 'Preview' | 'Experimental';
export type MaturityLevel = KnownMaturity | 'Unknown';

export interface MaturityDefinition {
  label: MaturityLevel;
  icon: string;
  glossary: string;
  className: string;
}

export const MATURITY_DEFINITIONS: Record<KnownMaturity, MaturityDefinition> = {
  Stable: {
    label: 'Stable',
    icon: '✅',
    glossary: 'Production-ready, fully supported, and generally available (GA) for everyday use.',
    className: styles.maturityStable,
  },
  Preview: {
    label: 'Preview',
    icon: '🔶',
    glossary: 'Available for early adoption and testing, but may contain breaking changes.',
    className: styles.maturityPreview,
  },
  Experimental: {
    label: 'Experimental',
    icon: '🧪',
    glossary: 'Early-stage proof of concept. Not recommended for production environments.',
    className: styles.maturityExperimental,
  },
};

export const UNKNOWN_MATURITY_DEFINITION: MaturityDefinition = {
  label: 'Unknown',
  icon: '❓',
  glossary: 'This maturity level is not recognized. Please check the collection manifest.',
  className: styles.maturityUnknown,
};

/**
 * Normalize external YAML strings. Includes a dev-only guardrail.
 */
export function normalizeMaturity(rawMaturity: string): MaturityLevel {
  if (!rawMaturity || typeof rawMaturity !== 'string') return 'Unknown';

  const normalized = rawMaturity.toLowerCase().trim();
  if (normalized === 'stable') return 'Stable';
  if (normalized === 'preview') return 'Preview';
  if (normalized === 'experimental') return 'Experimental';

  if (process.env.NODE_ENV === 'development') {
    console.warn(
      `[MaturityBadge] Unrecognized maturity value: "${rawMaturity}". Falling back to Unknown.`
    );
  }
  return 'Unknown';
}

interface MaturityBadgeProps {
  maturity: string;
  size?: 'sm' | 'md';
  href?: string;
}

export default function MaturityBadge({ maturity, size = 'sm', href }: MaturityBadgeProps): React.ReactElement {
  const normalized = normalizeMaturity(maturity);
  const config = normalized === 'Unknown' ? UNKNOWN_MATURITY_DEFINITION : MATURITY_DEFINITIONS[normalized as KnownMaturity];
  const tooltipId = useId();

  const Component = href ? 'a' : 'span';
  const componentProps = href 
    ? { href, className: styles.badgeLink } 
    : { tabIndex: 0, role: 'button' as const, className: styles.badgeLink };

  return (
    // badgeWrapper handles visual styling but passes clicks through to the card
    <span className={`${styles.badgeWrapper} ${config.className} ${size === 'md' ? styles.maturityBadgeMd : ''}`}>
      <Component {...componentProps} aria-describedby={tooltipId}>
        <span className={styles.maturityIcon} aria-hidden="true">{config.icon}</span>
        {config.label}
      </Component>
      
      {/* CSS-Only Tooltip for A11y (Hover/Focus) */}
      <span id={tooltipId} role="tooltip" className={styles.tooltip}>
        {config.glossary}
      </span>
    </span>
  );
}
