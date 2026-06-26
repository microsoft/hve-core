import { collectionCardDefinitions, resolveCollectionCards, resolveMetaCollections } from '../collectionCards';
import type { CollectionCardData } from '../collectionCards';
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

const collectionsDir =
  process.env.COLLECTIONS_DIR ??
  path.resolve(__dirname, '../../../../../collections');

interface ManifestArtifact {
  collections?: string[];
}

interface CoreManifest {
  collections: Record<string, unknown>;
  agents?: Record<string, ManifestArtifact>;
  prompts?: Record<string, ManifestArtifact>;
  instructions?: Record<string, ManifestArtifact>;
  skills?: Record<string, ManifestArtifact>;
}

const ARTIFACT_KINDS = ['agents', 'prompts', 'instructions', 'skills'] as const;

function loadCoreManifest(): CoreManifest {
  const manifestPath = path.join(collectionsDir, 'core-manifest.yml');
  const content = fs.readFileSync(manifestPath, 'utf-8');
  return yaml.load(content) as CoreManifest;
}

const manifest = loadCoreManifest();

// Derive each collection's artifact count from manifest membership, the same
// source the rendered site counts via the projected collections/*.collection.yml
// files. hve-core-all is a regular collection name in membership, so the same
// counting logic applies to it.
function getArtifactCount(collectionName: string): number {
  let count = 0;
  for (const kind of ARTIFACT_KINDS) {
    const section = manifest[kind] ?? {};
    for (const artifact of Object.values(section)) {
      if (artifact.collections?.includes(collectionName)) {
        count += 1;
      }
    }
  }
  return count;
}

const counts = Object.fromEntries(
  [...collectionCardDefinitions.map((c) => c.name), 'hve-core-all'].map(
    (name) => [name, getArtifactCount(name)],
  ),
);
const collectionCards = resolveCollectionCards(counts);
const metaCollections = resolveMetaCollections(counts);

describe('collectionCards', () => {
  const expectedNames = [
    'ado',
    'coding-standards',
    'data-science',
    'design-thinking',
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

  it('has positive integer values', () => {
    for (const [, value] of Object.entries(metaCollections)) {
      expect(Number.isInteger(value)).toBe(true);
      expect(value).toBeGreaterThan(0);
    }
  });
});
