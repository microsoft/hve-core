import React from 'react';
import Link from '@docusaurus/Link';
import styles from './styles.module.css';

interface CtaLink {
  label: string;
  href: string;
  primary?: boolean;
}

interface HeroSectionProps {
  title: string;
  subtitle: string;
  cta?: CtaLink[];
}

export default function HeroSection({
  title,
  subtitle,
  cta,
}: HeroSectionProps): React.ReactElement {
  return (
    <header className={styles.hero}>
      <div className={styles.heroPattern} />
      <div className={styles.heroContent}>
        <h1 className={styles.heroTitle}>{title}</h1>
        <p className={styles.heroSubtitle}>{subtitle}</p>
        {cta && cta.length > 0 && (
          <div className={styles.heroCta}>
            {cta.map((link) => (
              <Link
                key={link.href}
                to={link.href}
                className={link.primary ? styles.heroCtaPrimary : styles.heroCtaSecondary}
              >
                {link.label}
              </Link>
            ))}
          </div>
        )}
      </div>
    </header>
  );
}
