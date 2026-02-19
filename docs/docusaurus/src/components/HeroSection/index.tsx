import React from 'react';
import styles from './styles.module.css';

interface HeroSectionProps {
  title: string;
  subtitle: string;
}

export default function HeroSection({
  title,
  subtitle,
}: HeroSectionProps): React.ReactElement {
  return (
    <header className={styles.hero}>
      <div className={styles.heroPattern} />
      <div className={styles.heroContent}>
        <h1 className={styles.heroTitle}>{title}</h1>
        <p className={styles.heroSubtitle}>{subtitle}</p>
      </div>
    </header>
  );
}
