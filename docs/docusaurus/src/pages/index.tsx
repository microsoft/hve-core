import React from 'react';
import Layout from '@theme/Layout';
import HeroSection from '../components/HeroSection';
import { IconCard, BoxCard, CardGrid } from '../components/Cards';
import CollectionCard from '../components/CollectionCards';
import { iconCards, boxCards } from '../data/hubCards';
import { collectionCards } from '../data/collectionCards';
import styles from './styles.module.css';

export default function Home(): React.ReactElement {
  return (
    <Layout title="HVE Core" description="AI-Driven Software Development Across the Full Lifecycle">
      <HeroSection
        title="HVE Core"
        subtitle="AI-Driven Software Development Across the Full Lifecycle"
      />

      <main>
        <section className={styles.sectionCompact}>
          <CardGrid>
            {iconCards.map((card) => (
              <IconCard key={card.href} icon={card.icon} supertitle={card.supertitle} title={card.title} href={card.href} />
            ))}
          </CardGrid>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Deep dive</h2>
          <p className={styles.sectionSubtitle}>
            Explore best practices and patterns for AI-assisted development.
          </p>
          <CardGrid columns={4}>
            {boxCards.map((card) => (
              <BoxCard key={card.title} {...card} />
            ))}
          </CardGrid>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Collections</h2>
          <p className={styles.sectionSubtitle}>
            Browse domain-specific artifact bundles.
          </p>
          <CardGrid>
            {collectionCards.map((card) => (
              <CollectionCard key={card.name} {...card} />
            ))}
          </CardGrid>
        </section>
      </main>
    </Layout>
  );
}
