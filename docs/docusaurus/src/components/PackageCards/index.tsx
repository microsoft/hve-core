// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Link from '@docusaurus/Link';
import type { PackageCardData } from '../../data/packageCards';
import styles from './styles.module.css';

const maturityClass: Record<PackageCardData['maturity'], string> = {
  Stable: styles.maturityStable,
  Preview: styles.maturityPreview,
  Experimental: styles.maturityExperimental,
};

const maturityGlossary: Record<PackageCardData['maturity'], string> = {
  Stable: 'Stable means the package is broadly available and validated for everyday use.',
  Preview: 'Preview means the package is available for early adoption and feedback.',
  Experimental: 'Experimental means the package is early-stage and may change quickly.',
};

export default function PackageCard({
  name,
  title,
  description,
  artifacts,
  maturity,
  href,
}: PackageCardData): React.ReactElement {
  return (
    <article className={styles.packageCard} data-name={name}>
      <div className={styles.packageHeader}>
        <h3>
          <Link to={href} className={styles.packageName}>
            {title}
          </Link>
        </h3>
        <span
          className={`${styles.maturityBadge} ${maturityClass[maturity]}`}
          title={maturityGlossary[maturity]}
          aria-label={`${maturity}: ${maturityGlossary[maturity]}`}
        >
          {maturity}
        </span>
      </div>
      <p className={styles.packageDescription}>{description}</p>
      <p className={styles.artifactCount}>
        <strong>{artifacts}</strong> artifacts
      </p>
    </article>
  );
}
