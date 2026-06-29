// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import Fuse from 'fuse.js';

export interface CatalogInteraction {
  argumentHint: string;
  model: string;
  agent: string;
  applyTo: string;
}

export interface CatalogItem {
  id: string;
  name: string;
  description: string;
  kind: string;
  path: string;
  collection: string | null;
  tags: string[];
  maturity: string;
  interaction: CatalogInteraction;
  intro: string;
  headings: string[];
}

export interface CatalogFilters {
  kind?: string;
  collection?: string;
  maturity?: string;
  applyTo?: string;
}

function normalize(value: string | null | undefined): string {
  return (value ?? '').trim().toLowerCase();
}

function matchesFilters(item: CatalogItem, filters: CatalogFilters): boolean {
  if (filters.kind && normalize(filters.kind) !== 'all' && normalize(item.kind) !== normalize(filters.kind)) {
    return false;
  }

  if (filters.collection && normalize(filters.collection) !== 'all' && normalize(item.collection) !== normalize(filters.collection)) {
    return false;
  }

  if (filters.maturity && normalize(filters.maturity) !== 'all' && normalize(item.maturity) !== normalize(filters.maturity)) {
    return false;
  }

  if (filters.applyTo && normalize(filters.applyTo) !== 'all' && normalize(item.interaction.applyTo) !== normalize(filters.applyTo)) {
    return false;
  }

  return true;
}

function includesQuery(item: CatalogItem, query: string): boolean {
  const haystacks = [
    item.name,
    item.description,
    item.kind,
    item.collection ?? '',
    item.path,
    item.intro,
    ...(item.headings ?? []),
    ...(item.tags ?? []),
  ];

  return haystacks.some((value) => normalize(value).includes(query));
}

export function searchCatalog(items: CatalogItem[], query: string, filters: CatalogFilters = {}): CatalogItem[] {
  const normalizedQuery = normalize(query);
  const filteredItems = items.filter((item) => matchesFilters(item, filters));

  if (!normalizedQuery) {
    return filteredItems;
  }

  const substringMatches = filteredItems.filter((item) => includesQuery(item, normalizedQuery));
  const seenIds = new Set(substringMatches.map((item) => item.id));
  const fuzzyCandidates = filteredItems.filter((item) => !seenIds.has(item.id));

  if (fuzzyCandidates.length === 0) {
    return substringMatches;
  }

  const fuse = new Fuse(fuzzyCandidates, {
    includeScore: true,
    threshold: 0.4,
    ignoreLocation: true,
    minMatchCharLength: 2,
    keys: [
      { name: 'name', weight: 0.4 },
      { name: 'description', weight: 0.25 },
      { name: 'intro', weight: 0.2 },
      { name: 'headings', weight: 0.1 },
      { name: 'path', weight: 0.05 },
    ],
  });

  const fuzzyMatches = fuse.search(normalizedQuery).map((result) => result.item);

  return [...substringMatches, ...fuzzyMatches];
}
