import { collectionCards, metaCollections } from '../collectionCards';
import type { CollectionCardData } from '../collectionCards';
import * as fs from 'fs';
import * as path from 'path';

const collectionsDir = path.resolve(__dirname, '../../../../../collections');

describe('collectionCards', () => {
  const expectedNames = [
    'ado',
    'coding-standards',
    'data-science',
    'design-thinking',
    'experimental',
    'github',
    'gitlab',
    'hve-core',
    'jira',
    'project-planning',
    'rai-planning',
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

  it('has positive integer values', () => {
    for (const [key, value] of Object.entries(metaCollections)) {
      expect(Number.isInteger(value)).toBe(true);
      expect(value).toBeGreaterThan(0);
    }
  });
});

describe('artifact count cross-validation', () => {
  function countYamlPaths(collectionName: string): number {
    const yamlPath = path.join(
      collectionsDir,
      `${collectionName}.collection.yml`,
    );
    const content = fs.readFileSync(yamlPath, 'utf-8');
    return (content.match(/^\s*- path:/gm) || []).length;
  }

  it.each(collectionCards.map((c): [string] => [c.name]))(
    '%s artifact count matches YAML manifest',
    (name) => {
      const card = collectionCards.find((c) => c.name === name)!;
      const yamlCount = countYamlPaths(name);
      expect(card.artifacts).toBe(yamlCount);
    },
  );

  it('hve-core-all count matches YAML manifest', () => {
    const yamlCount = countYamlPaths('hve-core-all');
    expect(metaCollections['hve-core-all']).toBe(yamlCount);
  });
});
