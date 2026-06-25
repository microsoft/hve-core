import React, { useState, useId } from 'react';
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
  extendedDescription,
  artifacts,
  maturity,
  href,
}: CollectionCardData): React.ReactElement {
  
  const [isExpanded, setIsExpanded] = useState(false);
  const detailsId = useId(); 

  return (
    <article className={styles.collectionCard}>
      {/* Holds all core information grouped tightly */}
      <div className={styles.cardBody}>
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
      </div>

      {extendedDescription && (
        <div className={styles.disclosureContainer}>
          <button
            type="button"
            className={styles.toggleButton}
            onClick={(e) => {
              e.stopPropagation(); 
              setIsExpanded((prev) => !prev);
            }}
            aria-expanded={isExpanded}
            aria-controls={detailsId}
          >
            {isExpanded ? 'Hide details ▲' : 'Show details ▼'}
          </button>
          
          {isExpanded && (
            <div id={detailsId} className={styles.extendedDescription}>
              <p>{extendedDescription}</p>
            </div>
          )}
        </div>
      )}
    </article>
  );
}
