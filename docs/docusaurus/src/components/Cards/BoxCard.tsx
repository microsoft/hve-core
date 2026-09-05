// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

interface BoxCardLink {
  label: string;
  href: string;
}

interface BoxCardProps {
  title: string;
  description?: string;
  links: BoxCardLink[];
  icon?: string;
}

export default function BoxCard({
  title,
  description,
  links,
  icon,
}: BoxCardProps): React.ReactElement {
  const resolvedIcon = useBaseUrl(icon ?? '');
  const iconUrl = icon ? resolvedIcon : undefined;
  return (
    <div className={styles.boxCard}>
      {iconUrl && (
        <div className={styles.boxCardIcon}>
          <img src={iconUrl} alt="" aria-hidden="true" width="48" height="48" />
        </div>
      )}
      <h3 className={styles.boxCardTitle}>{title}</h3>
      {description && <p className={styles.cardDescription}>{description}</p>}
      <ul className={styles.boxCardLinks}>
        {links.map((link) => (
          <li key={link.href}>
            <Link to={link.href}>{link.label}</Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
