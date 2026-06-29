// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import React, { useEffect, useMemo, useState } from 'react';
import Layout from '@theme/Layout';
import useBaseUrl from '@docusaurus/useBaseUrl';
import { searchCatalog, type CatalogFilters, type CatalogItem } from '../lib/catalogSearch';

interface CatalogResponse {
  items: CatalogItem[];
}

const KIND_COLORS: Record<string, { background: string; color: string }> = {
  agent: { background: '#e3f0ff', color: '#0b5cad' },
  prompt: { background: '#e8f7ee', color: '#1a7f4b' },
  skill: { background: '#f3e8ff', color: '#7b2fbe' },
  instruction: { background: '#fff1e0', color: '#b5651d' },
};

function badgeStyle(kind: string): React.CSSProperties {
  const palette = KIND_COLORS[kind.toLowerCase()] ?? { background: 'var(--ifm-color-emphasis-200)', color: 'var(--ifm-color-emphasis-800)' };
  return {
    fontSize: '0.7rem',
    fontWeight: 700,
    textTransform: 'uppercase',
    letterSpacing: '0.04em',
    padding: '0.2rem 0.55rem',
    borderRadius: '0.45rem',
    background: palette.background,
    color: palette.color,
  };
}

const NEUTRAL_BADGE: React.CSSProperties = {
  fontSize: '0.7rem',
  fontWeight: 700,
  textTransform: 'uppercase',
  letterSpacing: '0.04em',
  padding: '0.2rem 0.55rem',
  borderRadius: '0.45rem',
  background: 'var(--ifm-color-emphasis-200)',
  color: 'var(--ifm-color-emphasis-800)',
};

function getUniqueValues(items: CatalogItem[], key: keyof CatalogItem): string[] {
  return Array.from(
    new Set(
      items
        .map((item) => item[key])
        .filter((value): value is string => typeof value === 'string' && value.trim().length > 0),
    ),
  ).sort((left, right) => left.localeCompare(right));
}

function getCollectionOptions(items: CatalogItem[]): string[] {
  return Array.from(
    new Set(
      items
        .map((item) => item.collection)
        .filter((value): value is string => typeof value === 'string' && value.trim().length > 0),
    ),
  ).sort((left, right) => left.localeCompare(right));
}

function CatalogPage(): React.ReactElement {
  const catalogUrl = useBaseUrl('/catalog.json');
  const [items, setItems] = useState<CatalogItem[]>([]);
  const [query, setQuery] = useState('');
  const [filters, setFilters] = useState<CatalogFilters>({});
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    let isCancelled = false;

    async function loadCatalog(): Promise<void> {
      try {
        const response = await fetch(catalogUrl);
        if (!response.ok) {
          throw new Error(`Failed to load catalog: ${response.status}`);
        }

        const payload = (await response.json()) as CatalogResponse;
        if (!isCancelled) {
          setItems(payload.items ?? []);
          setIsLoaded(true);
        }
      } catch (error) {
        if (!isCancelled) {
          console.error(error);
          setItems([]);
          setIsLoaded(true);
        }
      }
    }

    void loadCatalog();

    return () => {
      isCancelled = true;
    };
  }, [catalogUrl]);

  const kindOptions = useMemo(() => ['All', ...getUniqueValues(items, 'kind')], [items]);
  const collectionOptions = useMemo(() => ['All', ...getCollectionOptions(items)], [items]);
  const maturityOptions = useMemo(() => ['All', ...getUniqueValues(items, 'maturity')], [items]);

  const results = useMemo(() => searchCatalog(items, query, filters), [filters, items, query]);

  function updateFilter(key: keyof CatalogFilters, value: string): void {
    setFilters((current) => ({
      ...current,
      [key]: value === 'All' ? undefined : value,
    }));
  }

  return (
    <Layout title="Catalog" description="Search and browse HVE Core artifacts">
      <main style={{ padding: '2.5rem 1.5rem 4rem', maxWidth: '1180px', margin: '0 auto' }}>
        <header style={{ marginBottom: '1.5rem' }}>
          <h1 style={{ fontSize: '2.25rem', fontWeight: 700, marginBottom: '0.35rem' }}>Catalog</h1>
          <p style={{ color: 'var(--ifm-color-emphasis-700)', fontSize: '1.05rem', margin: 0 }}>
            Search agents, prompts, skills, and instructions across the HVE Core repository.
          </p>
        </header>

        <section
          aria-label="Catalog search controls"
          style={{
            position: 'sticky',
            top: 'var(--ifm-navbar-height, 60px)',
            zIndex: 5,
            background: 'var(--ifm-background-color)',
            padding: '1rem 0',
            marginBottom: '1.5rem',
            borderBottom: '1px solid var(--ifm-color-emphasis-200)',
          }}
        >
          <label htmlFor="catalog-search" style={{ display: 'block', fontWeight: 600, marginBottom: '0.5rem' }}>
            Search
          </label>
          <input
            id="catalog-search"
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search by name, description, path, or heading"
            style={{
              width: '100%',
              padding: '0.8rem 1rem',
              fontSize: '1rem',
              borderRadius: '0.6rem',
              border: '1px solid var(--ifm-color-emphasis-300)',
              background: 'var(--ifm-background-surface-color)',
              color: 'var(--ifm-font-color-base)',
            }}
          />

          <div style={{ display: 'grid', gap: '0.85rem', gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))', marginTop: '1rem' }}>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <label htmlFor="catalog-kind-filter" style={{ fontWeight: 600, fontSize: '0.85rem', marginBottom: '0.3rem' }}>
                Kind
              </label>
              <select id="catalog-kind-filter" value={filters.kind ?? 'All'} onChange={(event) => updateFilter('kind', event.target.value)}>
                {kindOptions.map((option) => (
                  <option key={option} value={option}>
                    {option}
                  </option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <label htmlFor="catalog-collection-filter" style={{ fontWeight: 600, fontSize: '0.85rem', marginBottom: '0.3rem' }}>
                Collection
              </label>
              <select id="catalog-collection-filter" value={filters.collection ?? 'All'} onChange={(event) => updateFilter('collection', event.target.value)}>
                {collectionOptions.map((option) => (
                  <option key={option} value={option}>
                    {option}
                  </option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <label htmlFor="catalog-maturity-filter" style={{ fontWeight: 600, fontSize: '0.85rem', marginBottom: '0.3rem' }}>
                Maturity
              </label>
              <select id="catalog-maturity-filter" value={filters.maturity ?? 'All'} onChange={(event) => updateFilter('maturity', event.target.value)}>
                {maturityOptions.map((option) => (
                  <option key={option} value={option}>
                    {option}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </section>

        {!isLoaded ? (
          <p>Loading catalog…</p>
        ) : results.length === 0 ? (
          <p style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--ifm-color-emphasis-600)' }}>No matching artifacts found.</p>
        ) : (
          <section aria-label="Catalog results">
            <p style={{ color: 'var(--ifm-color-emphasis-700)', fontSize: '0.9rem', marginBottom: '1rem' }}>
              {results.length} result{results.length === 1 ? '' : 's'}
            </p>
            <div style={{ display: 'grid', gap: '1.25rem', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))' }}>
              {results.map((item) => (
                <article
                  key={item.id}
                  style={{
                    border: '1px solid var(--ifm-color-emphasis-200)',
                    borderRadius: '0.9rem',
                    padding: '1.25rem',
                    background: 'var(--ifm-background-surface-color)',
                    display: 'flex',
                    flexDirection: 'column',
                  }}
                >
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem', marginBottom: '0.6rem' }}>
                    <span style={badgeStyle(item.kind)}>{item.kind}</span>
                    <span style={NEUTRAL_BADGE}>{item.maturity}</span>
                    {item.collection ? <span style={NEUTRAL_BADGE}>{item.collection}</span> : null}
                  </div>
                  <h2 style={{ fontSize: '1.15rem', fontWeight: 600, marginTop: 0, marginBottom: '0.5rem', lineHeight: 1.3 }}>{item.name}</h2>
                  <p style={{ color: 'var(--ifm-color-emphasis-800)', marginTop: 0, marginBottom: '1rem', flex: 1 }}>{item.description}</p>
                  <code style={{ fontSize: '0.78rem', wordBreak: 'break-all', color: 'var(--ifm-color-emphasis-700)', borderTop: '1px solid var(--ifm-color-emphasis-200)', paddingTop: '0.75rem' }}>
                    {item.path}
                  </code>
                </article>
              ))}
            </div>
          </section>
        )}
      </main>
    </Layout>
  );
}

export default CatalogPage;
