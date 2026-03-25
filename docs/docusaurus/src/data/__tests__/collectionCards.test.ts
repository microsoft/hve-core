import { collectionCards, metaCollections } from '../collectionCards';
import type { CollectionCardData } from '../collectionCards';

describe('collectionCards', () => {
  const expectedNames = [
    'ado',
    'coding-standards',
    'data-science',
    'design-thinking',
    'experimental',
    'github',
    'hve-core',
    'project-planning',
    'security',
  ];

  it('contains all expected collections', () => {
    const names = collectionCards.map((c) => c.name);
    expect(names).toEqual(expect.arrayContaining(expectedNames));
    expect(names).toHaveLength(expectedNames.length);
  });

  it('has unique names', () => {
    const names = collectionCards.map((c) => c.name);
    expect(new Set(names).size).toBe(names.length);
  });

  it.each(
    collectionCards.map((c): [string, CollectionCardData] => [c.name, c]),
  )('%s has a non-empty description', (_name, card) => {
    expect(card.description.length).toBeGreaterThan(0);
  });

  it.each(
    collectionCards.map((c): [string, CollectionCardData] => [c.name, c]),
  )('%s has a positive integer artifact count', (_name, card) => {
    expect(Number.isInteger(card.artifacts)).toBe(true);
    expect(card.artifacts).toBeGreaterThan(0);
  });

  it.each(
    collectionCards.map((c): [string, CollectionCardData] => [c.name, c]),
  )('%s has a valid maturity value', (_name, card) => {
    expect(['Stable', 'Preview', 'Experimental']).toContain(card.maturity);
  });

  it.each(
    collectionCards.map((c): [string, CollectionCardData] => [c.name, c]),
  )('%s has a non-empty href', (_name, card) => {
    expect(card.href.length).toBeGreaterThan(0);
  });
});

describe('metaCollections', () => {
  it('contains hve-core-all entry', () => {
    expect(metaCollections).toHaveProperty('hve-core-all');
  });

  it('contains installer entry', () => {
    expect(metaCollections).toHaveProperty('installer');
  });

  it('has positive integer values', () => {
    for (const [key, value] of Object.entries(metaCollections)) {
      expect(Number.isInteger(value)).toBe(true);
      expect(value).toBeGreaterThan(0);
    }
  });
});
