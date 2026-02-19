import React from 'react';
import Link from '@docusaurus/Link';
import styles from './styles.module.css';

interface BoxCardLink {
  label: string;
  href: string;
}

interface BoxCardProps {
  title: string;
  description?: string;
  links: BoxCardLink[];
}

export default function BoxCard({
  title,
  description,
  links,
}: BoxCardProps): React.ReactElement {
  return (
    <div className={styles.boxCard}>
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
