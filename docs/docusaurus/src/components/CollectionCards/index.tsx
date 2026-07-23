// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Link from '@docusaurus/Link';
import type { CollectionCardData } from '../../data/collectionCards';
import styles from './styles.module.css';

const maturityClass: Record<CollectionCardData['maturity'], string> = {
  Stable: styles.maturityStable,
  Preview: styles.maturityPreview,
  Experimental: styles.maturityExperimental,
};

const maturityGlossary: Record<CollectionCardData['maturity'], string> = {
  Stable: 'Stable means the collection is broadly available and validated for everyday use.',
  Preview: 'Preview means the collection is available for early adoption and feedback.',
  Experimental: 'Experimental means the collection is early-stage and may change quickly.',
};

export default function CollectionCard({
  name,
  title,
  description,
  artifacts,
  maturity,
  href,
}: CollectionCardData): React.ReactElement {
  return (
    <article className={styles.collectionCard} data-name={name}>
      <div className={styles.collectionHeader}>
        <h3>
          <Link to={href} className={styles.collectionName}>
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
      <p className={styles.collectionDescription}>{description}</p>
      <p className={styles.artifactCount}>
        <strong>{artifacts}</strong> artifacts
      </p>
    </article>
  );
}
