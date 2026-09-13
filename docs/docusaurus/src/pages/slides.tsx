// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React from 'react';
import Layout from '@theme/Layout';
import useBaseUrl from '@docusaurus/useBaseUrl';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import { labelRegistry } from '../data/labelRegistry';

type SlideDeck = { slug: string; title: string; description: string };

function isSlideDeck(value: unknown): value is SlideDeck {
  return typeof value === 'object' && value !== null && 'slug' in value
    && typeof value.slug === 'string' && /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(value.slug)
    && 'title' in value && typeof value.title === 'string' && value.title.trim().length > 0
    && 'description' in value && typeof value.description === 'string' && value.description.trim().length > 0;
}

function SlideLinks({ slug, title, description }: SlideDeck): React.ReactElement {
  const href = useBaseUrl(`/slides/${slug}.html`);
  return (
    <li className="margin-bottom--md">
      <h3>{title}</h3>
      <p>{description}</p>
      <p>
        <a href={href}>Open {title}</a>
        {' · '}
        <a href={href} download>Download {title} (HTML)</a>
      </p>
    </li>
  );
}

export default function SlidesPage(): React.ReactElement {
  const { siteConfig } = useDocusaurusContext();
  const decks = siteConfig.customFields?.slideDecks;
  if (!Array.isArray(decks) || !decks.every(isSlideDeck)) {
    throw new Error('The slide catalog is missing or invalid. Rebuild the documentation site.');
  }

  return (
    <Layout title={labelRegistry.slides} description="Browse and download standalone HVE Core presentations.">
      <main className="container margin-vert--lg">
        <h1>{labelRegistry.slides}</h1>
        <p>
          Open a presentation in your browser, or download its self-contained HTML file
          to present offline. Use your browser&apos;s Back button to return to this page.
        </p>
        <p>
          Walkthroughs use scripted examples, not live agent runs. Downloaded files include
          presenter notes; external source links require an internet connection.
        </p>
        <h2>Available presentations</h2>
        {decks.length > 0
          ? <ul>{decks.map(deck => <SlideLinks key={deck.slug} {...deck} />)}</ul>
          : <p>No presentations have been published yet.</p>}
      </main>
    </Layout>
  );
}
