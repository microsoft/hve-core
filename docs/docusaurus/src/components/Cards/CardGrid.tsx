import React from 'react';
import styles from './styles.module.css';

interface CardGridProps {
  children: React.ReactNode;
  columns?: 2 | 3 | 4;
}

export default function CardGrid({
  children,
  columns = 3,
}: CardGridProps): React.ReactElement {
  const columnClass = columns === 2 ? styles.cardGridTwo : columns === 4 ? styles.cardGridFour : '';
  return (
    <div className={`${styles.cardGrid} ${columnClass}`}>
      {children}
    </div>
  );
}
