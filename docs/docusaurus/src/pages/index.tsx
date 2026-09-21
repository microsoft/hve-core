// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Layout from '@theme/Layout';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import HeroSection from '../components/HeroSection';
import { IconCard, BoxCard, CardGrid } from '../components/Cards';
import PackageCard from '../components/PackageCards';
import { iconCards, boxCards } from '../data/hubCards';
import type { PackageCardData } from '../data/packageCards';
import { labelRegistry } from '../data/labelRegistry';
import styles from './styles.module.css';

export default function Home(): React.ReactElement {
  const { siteConfig } = useDocusaurusContext();
  const packageCards = (siteConfig.customFields?.packageCards
    ?? []) as PackageCardData[];

  return (
    <Layout
      title="HVE Core"
      description="AI-Driven Software Development Across the Full Lifecycle"
    >
      <HeroSection
        title={labelRegistry.hveCoreExpanded}
        subtitle="AI-Driven Software Development Across the Full Lifecycle"
        cta={[
          {
            label: "Install the Extension",
            href: "https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core",
            primary: true,
          },
          {
            label: "Browse Marketplace Packages",
            href: "/docs/getting-started/packages",
          },
        ]}
      />

      <main>
        <p className={styles.heroPurpose}>
          HVE Core helps teams move from an idea to a shipped solution with
          shared guidance, reusable assets, and accessible documentation.
        </p>

        <section
          className={styles.sectionCompact}
          aria-labelledby="featured-title"
        >
          <h2 id="featured-title" className={styles.srOnly}>
            Featured resources
          </h2>
          <CardGrid>
            {iconCards.map((card) => (
              <IconCard
                key={card.href}
                icon={card.icon}
                supertitle={card.supertitle}
                title={card.title}
                href={card.href}
              />
            ))}
          </CardGrid>
        </section>

        <section className={styles.section} aria-labelledby="deep-dive-title">
          <h2 id="deep-dive-title" className={styles.sectionTitle}>
            {labelRegistry.deepDive}
          </h2>
          <p className={styles.sectionSubtitle}>
            Explore best practices and patterns for AI-assisted development.
          </p>
          <p className={styles.sectionDescription}>
            Deep dive groups practical guidance and reference material that
            helps you apply the workflow in real projects.
          </p>
          <CardGrid columns={4}>
            {boxCards.map((card) => (
              <BoxCard key={card.title} {...card} />
            ))}
          </CardGrid>
        </section>

        <section className={styles.section} aria-labelledby="packages-title">
          <h2 id="packages-title" className={styles.sectionTitle}>
            {labelRegistry.packages}
          </h2>
          <p className={styles.sectionDescription}>
            Browse the HVE Core plugin and extension packages and pick the
            focused or full choice that fits your team.
          </p>
          <CardGrid>
            {packageCards.map((card) => (
              <PackageCard key={card.name} {...card} />
            ))}
          </CardGrid>
        </section>
      </main>
    </Layout>
  );
}
