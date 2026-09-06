// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import styles from './styles.module.css';

export type MaturityLevel = 'Stable' | 'Preview' | 'Experimental';

//  Normalize casing from YAML (lowercase) to Title-case
export function normalizeMaturity(maturity: string): MaturityLevel {
  const lower = maturity.toLowerCase();
  if (lower === 'stable') return 'Stable';
  if (lower === 'preview') return 'Preview';
  return 'Experimental';
}

const maturityConfig: Record<MaturityLevel, { icon: string; glossary: string; className: string }> = {
  Stable: {
    icon: '✅',
    glossary: 'Stable means the package is broadly available and validated for everyday use.',
    className: styles.maturityStable,
  },
  Preview: {
    icon: '🔶',
    glossary: 'Preview means the package is available for early adoption and feedback.',
    className: styles.maturityPreview,
  },
  Experimental: {
    icon: '🧪',
    glossary: 'Experimental means the package is early-stage and may change quickly.',
    className: styles.maturityExperimental,
  },
};

interface MaturityBadgeProps {
  maturity: string;
  size?: 'sm' | 'md';
}

export default function MaturityBadge({ maturity, size = 'sm' }: MaturityBadgeProps): React.ReactElement {
  const normalized = normalizeMaturity(maturity);
  const config = maturityConfig[normalized];

  return (
    <span
      className={`${styles.maturityBadge} ${config.className} ${size === 'md' ? styles.maturityBadgeMd : ''}`}
      title={config.glossary}
      aria-label={`${normalized}: ${config.glossary}`}
    >
      <span className={styles.maturityIcon} aria-hidden="true">{config.icon}</span>
      {normalized}
    </span>
  );
}
