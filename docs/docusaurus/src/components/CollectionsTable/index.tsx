import React from 'react';
import { collectionCards } from '../../data/collectionCards';
import collectionData from './collectionData.json';
import styles from './styles.module.css';

export default function CollectionsTable(): React.ReactElement {
  // Merge the collectionCards data with the deep summary from collectionData.json
  const tableData = collectionCards.map(card => {
    const extendedInfo = collectionData.find(c => c.name === card.name);
    return {
      ...card,
      extendedDescription: extendedInfo?.summary || ''
    };
  });

  return (
    <div className={styles.tableWrapper}>
      <table className={styles.collectionsTable}>
        <thead>
          <tr>
            <th>Collection</th>
            <th>Description</th>
            <th>Artifacts</th>
            <th>Maturity</th>
          </tr>
        </thead>
        <tbody>
          {tableData.map(row => (
            <React.Fragment key={row.name}>
              <tr className={styles.mainRow}>
                <td><strong>{row.name}</strong></td>
                <td>{row.description}</td>
                <td className={styles.centerAlign}>{row.artifacts}</td>
                <td>
                  <span className={`${styles.badge} ${styles['badge' + row.maturity]}`}>
                    {row.maturity}
                  </span>
                </td>
              </tr>
              {row.extendedDescription && (
                <tr className={styles.detailsRow}>
                  <td colSpan={4}>
                    <details className={styles.details}>
                      <summary>View details</summary>
                      <div className={styles.detailsContent}>
                        <p>{row.extendedDescription}</p>
                      </div>
                    </details>
                  </td>
                </tr>
              )}
            </React.Fragment>
          ))}
        </tbody>
      </table>
    </div>
  );
}
