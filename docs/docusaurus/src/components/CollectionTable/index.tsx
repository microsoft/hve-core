import React, { useState } from 'react';
import type { CollectionDetailData } from '../../data/collectionDetails';
import styles from './styles.module.css';

const maturityClass: Record<CollectionDetailData['maturity'], string> = {
  Stable: styles.maturityStable,
  Preview: styles.maturityPreview,
  Experimental: styles.maturityExperimental,
};

/**
 * CollectionTableWithDescriptions - A table component displaying HVE collections
 * with hover tooltips showing detailed descriptions from collection files.
 * 
 * Implements the feature request from issue #1266: adding collection description
 * tooltips to the Docusaurus collections page.
 */
export default function CollectionTableWithDescriptions({
  collections,
}: {
  collections: CollectionDetailData[];
}): React.ReactElement {
  const [expandedRow, setExpandedRow] = useState<string | null>(null);

  const toggleRow = (name: string) => {
    setExpandedRow(expandedRow === name ? null : name);
  };

  return (
    <div className={styles.tableWrapper}>
      <table className={styles.collectionTable}>
        <thead>
          <tr>
            <th>Collection</th>
            <th>Description</th>
            <th>Artifacts</th>
            <th>Maturity</th>
          </tr>
        </thead>
        <tbody>
          {collections.map((collection) => (
            <React.Fragment key={collection.name}>
              <tr
                className={`${styles.tableRow} ${expandedRow === collection.name ? styles.expanded : ''}`}
                onClick={() => toggleRow(collection.name)}
                title={collection.detailedDescription}
              >
                <td>
                  <span className={styles.collectionName}>{collection.name}</span>
                  <span className={styles.expandIcon}>
                    {expandedRow === collection.name ? '▼' : '▶'}
                  </span>
                </td>
                <td>{collection.shortDescription}</td>
                <td className={styles.artifacts}>{collection.artifacts}</td>
                <td>
                  <span className={`${styles.maturityBadge} ${maturityClass[collection.maturity]}`}>
                    {collection.maturity}
                  </span>
                </td>
              </tr>
              {expandedRow === collection.name && (
                <tr className={styles.detailRow}>
                  <td colSpan={4}>
                    <div className={styles.detailContent}>
                      <h4>Detailed Description</h4>
                      <p>{collection.detailedDescription}</p>
                      {collection.includes && collection.includes.length > 0 && (
                        <div className={styles.includesSection}>
                          <h5>Key Features:</h5>
                          <ul>
                            {collection.includes.slice(0, 5).map((item, idx) => (
                              <li key={idx}>{item}</li>
                            ))}
                          </ul>
                        </div>
                      )}
                    </div>
                  </td>
                </tr>
              )}
            </React.Fragment>
          ))}
        </tbody>
      </table>
      <p className={styles.hint}>
        💡 Click on a row to expand and see more details, or hover over the collection name for a quick tooltip.
      </p>
    </div>
  );
}