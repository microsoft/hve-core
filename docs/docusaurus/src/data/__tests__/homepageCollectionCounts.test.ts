import { collectionCardDefinitions } from '../collectionCards';
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

// Guard test for the homepage collection-count contract.
//
// docusaurus.config.js derives customFields.collectionCounts directly from
// collections/core-manifest.yml, counting each artifact's collection membership
// but only when its maturity is shippable. This test mirrors that projection so
// manifest drift (a renamed/removed collection, or all of a collection's
// artifacts becoming deprecated) fails fast instead of silently zeroing the
// homepage cards.

const collectionsDir =
  process.env.COLLECTIONS_DIR ??
  path.resolve(__dirname, '../../../../../collections');

// Mirrors the shippable maturity filter applied in docusaurus.config.js.
const SHIPPABLE_MATURITIES = new Set(['stable', 'preview', 'experimental']);

const ARTIFACT_KINDS = ['agents', 'prompts', 'instructions', 'skills'] as const;

// Collections that exist in the manifest but are intentionally not rendered on
// the homepage. They must never appear in collectionCardDefinitions.
const STALE_HOMEPAGE_COLLECTIONS = ['experimental', 'gitlab', 'jira'];

interface ManifestArtifact {
  maturity?: string;
  collections?: string[];
}

interface CoreManifest {
  collections: Record<string, unknown>;
  agents?: Record<string, ManifestArtifact>;
  prompts?: Record<string, ManifestArtifact>;
  instructions?: Record<string, ManifestArtifact>;
  skills?: Record<string, ManifestArtifact>;
}

function loadCoreManifest(): CoreManifest {
  const manifestPath = path.join(collectionsDir, 'core-manifest.yml');
  const content = fs.readFileSync(manifestPath, 'utf-8');
  return yaml.load(content) as CoreManifest;
}

const manifest = loadCoreManifest();

function computeShippableCount(collectionName: string): number {
  let count = 0;
  for (const kind of ARTIFACT_KINDS) {
    const section = manifest[kind] ?? {};
    for (const artifact of Object.values(section)) {
      if (!SHIPPABLE_MATURITIES.has(artifact.maturity ?? '')) {
        continue;
      }
      if (artifact.collections?.includes(collectionName)) {
        count += 1;
      }
    }
  }
  return count;
}

const expectedHomepageCollections = [
  ...collectionCardDefinitions.map((c) => c.name),
  'hve-core-all',
];

describe('homepage collection counts', () => {
  it('renders exactly nine collections', () => {
    expect(new Set(expectedHomepageCollections).size).toBe(9);
  });

  it.each(expectedHomepageCollections)(
    '%s is declared in the manifest collections map',
    (name) => {
      expect(manifest.collections).toHaveProperty(name);
    },
  );

  it.each(expectedHomepageCollections)(
    '%s has a positive integer shippable artifact count',
    (name) => {
      const count = computeShippableCount(name);
      expect(Number.isInteger(count)).toBe(true);
      expect(count).toBeGreaterThan(0);
    },
  );

  it.each(STALE_HOMEPAGE_COLLECTIONS)(
    '%s is excluded from the rendered homepage cards',
    (name) => {
      const cardNames = collectionCardDefinitions.map((c) => c.name);
      expect(cardNames).not.toContain(name);
    },
  );
});
