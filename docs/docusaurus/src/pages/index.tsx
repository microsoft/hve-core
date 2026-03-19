import React from 'react';
import Layout from '@theme/Layout';
import Mermaid from '@theme/Mermaid';
import HeroSection from '../components/HeroSection';
import { IconCard, BoxCard, CardGrid } from '../components/Cards';
import CollectionCard from '../components/CollectionCards';
import { iconCards, boxCards } from '../data/hubCards';
import { collectionCards } from '../data/collectionCards';
import styles from './styles.module.css';

const collectionDiagram = `graph TD
    HCA["hve-core-all<br/>(163 artifacts)"]
    INS["installer<br/>(2 artifacts)"]
    ADO["ado"] CS["coding-standards"] DS["data-science"]
    DT["design-thinking"] EXP["experimental"] GH["github"]
    HC["hve-core"] PP["project-planning"] SP["security"]
    HCA --> ADO
    HCA --> CS
    HCA --> DS
    HCA --> DT
    HCA --> EXP
    HCA --> GH
    HCA --> HC
    HCA --> PP
    HCA --> SP`;

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
          <div className={styles.diagramContainer}>
            <Mermaid value={collectionDiagram} />
          </div>
        </section>
      </main>
    </Layout>
  );
}
