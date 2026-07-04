// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
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
  const items = React.Children.toArray(children);

  return (
    <ul className={`${styles.cardGrid} ${columnClass}`}>
      {items.map((child, index) => (
        <li key={(child as React.ReactElement)?.key ?? index} className={styles.cardGridItem}>
          {child}
        </li>
      ))}
    </ul>
  );
}
