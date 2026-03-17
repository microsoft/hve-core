import React from 'react';
import Link from '@docusaurus/Link';
import type { CollectionCardData } from '../../data/collectionCards';
import styles from './styles.module.css';

const maturityClass: Record<CollectionCardData['maturity'], string> = {
  Stable: styles.maturityStable,
  Preview: styles.maturityPreview,
  Experimental: styles.maturityExperimental,
};

export default function CollectionCard({
  name,
  description,
  artifacts,
  maturity,
  href,
}: CollectionCardData): React.ReactElement {
  return (
    <article className={styles.collectionCard}>
      <div className={styles.collectionHeader}>
        <Link to={href} className={styles.collectionName}>{name}</Link>
        <span className={`${styles.maturityBadge} ${maturityClass[maturity]}`}>
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
