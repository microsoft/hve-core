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
  return (
    <Link to={href} className={styles.card}>
      <div className={styles.iconCardLayout}>
        <div className={styles.iconContainer}>{icon}</div>
        <div className={styles.iconCardContent}>
          <span className={styles.supertitle}>{supertitle}</span>
          <span className={styles.cardTitle}>{title}</span>
          {description && <p className={styles.cardDescription}>{description}</p>}
        </div>
      </div>
    </Link>
  );
}
