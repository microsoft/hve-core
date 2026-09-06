// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, { useId, useState } from 'react';
import Link from '@docusaurus/Link';
import type { PackageCardData } from '../../data/packageCards';
import MaturityBadge from '../MaturityBadge';
import styles from './styles.module.css';

export default function PackageCard({
  name,
  title,
  description,
  artifacts,
  contents,
  maturity,
  href,
}: PackageCardData): React.ReactElement {
  const [isExpanded, setIsExpanded] = useState(false);
  const contentsId = useId();

  return (
    <article className={styles.packageCard} data-name={name}>
      <div className={styles.packageHeader}>
        <h3>
          <Link to={href} className={styles.packageName}>
            {title}
          </Link>
        </h3>
        <MaturityBadge maturity={maturity} />
      </div>
      <p className={styles.packageDescription}>{description}</p>
      <p className={styles.artifactCount}>
        <strong>{artifacts}</strong> artifacts
      </p>
      <div className={styles.disclosure}>
        <button
          type="button"
          className={styles.disclosureButton}
          aria-expanded={isExpanded}
          aria-controls={contentsId}
          onClick={() => setIsExpanded((expanded) => !expanded)}
        >
          {isExpanded ? 'Hide package contents' : 'Show package contents'}
        </button>
        <div
          id={contentsId}
          className={styles.contentsPanel}
          hidden={!isExpanded}
        >
          <p className={styles.contentsHeading}>Included content</p>
          <ul className={styles.contentsList}>
            {contents.map((content) => (
              <li key={content.kind}>
                <strong>{content.count}</strong>{' '}
                <Link to={content.href}>{content.label}</Link>
              </li>
            ))}
          </ul>
          <Link to={href} className={styles.packageOverviewLink}>
            View package overview
          </Link>
        </div>
      </div>
    </article>
  );
}
