// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Link from '@docusaurus/Link';
import styles from './styles.module.css';

interface IconCardProps {
  icon: React.ReactNode;
  supertitle: string;
  title: string;
  href: string;
  description?: string;
}

export default function IconCard({
  icon,
  supertitle,
  title,
  href,
  description,
}: IconCardProps): React.ReactElement {
  const titleId = React.useId();

  return (
    <article className={styles.card} aria-labelledby={titleId}>
      <div className={styles.iconCardLayout}>
        <div className={styles.iconContainer}>{icon}</div>
        <div className={styles.iconCardContent}>
          <span className={styles.supertitle}>{supertitle}</span>
          <h3 id={titleId}>
            <Link to={href} className={styles.cardTitle} aria-label={`${supertitle}: ${title}`}>
              {title}
            </Link>
          </h3>
          {description && <p className={styles.cardDescription}>{description}</p>}
        </div>
      </div>
    </article>
  );
}
