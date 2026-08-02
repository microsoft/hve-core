// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import * as fs from 'fs';
import * as path from 'path';
import {
  packageCardDefinitions,
  resolvePackageCards,
  resolveMetaPackages,
} from '../packageCards';
import type { PackageCardData } from '../packageCards';
import {
  countMarketplaceComponents,
  loadMarketplaceCounts,
} from '../marketplaceCounts';

const marketplacePath = path.resolve(
  __dirname,
  '../../../../../.github/plugin/marketplace.json',
);

interface MarketplaceEntry {
  name: string;
  [field: string]: unknown;
}

const catalog = JSON.parse(
  fs.readFileSync(marketplacePath, 'utf-8'),
) as { plugins: MarketplaceEntry[] };

// Independent re-derivation of the component tally so expected values come from
// the catalog itself rather than from the function under test or a magic number.
const componentFields = ['agents', 'commands', 'rules', 'skills', 'hooks'];
function expectedComponentCount(entry: MarketplaceEntry): number {
  return componentFields.reduce((total, field) => {
    const value = entry[field];
    if (typeof value === 'string') return total + 1;
    if (Array.isArray(value)) return total + value.length;
    return total;
  }, 0);
}

const catalogEntries = new Map(catalog.plugins.map((entry) => [entry.name, entry]));
const cardNames = packageCardDefinitions.map((definition) => definition.name);
const metaPackageName = 'hve-core-all';
const counts = loadMarketplaceCounts(marketplacePath, [...cardNames, metaPackageName]);
const packageCards = resolvePackageCards(counts);
const metaPackages = resolveMetaPackages(counts);

describe('packageCardDefinitions', () => {
  it('declares a unique id for every package card', () => {
    expect(new Set(cardNames).size).toBe(cardNames.length);
  });

  it('declares unique ids in the marketplace catalog it draws from', () => {
    const catalogNames = catalog.plugins.map((entry) => entry.name);
    expect(new Set(catalogNames).size).toBe(catalogNames.length);
  });

  it.each(cardNames)('%s resolves to a marketplace catalog package', (name) => {
    expect(catalogEntries.has(name)).toBe(true);
  });

  it.each(
    packageCardDefinitions.map((definition): [string, string] => [
      definition.name,
      definition.href,
    ]),
  )('%s links to the packages route', (_name, href) => {
    expect(href).toBe('/docs/getting-started/packages');
  });

  it.each(
    packageCards.map((card): [string, PackageCardData] => [card.name, card]),
  )('%s declares a description and a supported maturity', (_name, card) => {
    expect(card.description.length).toBeGreaterThan(0);
    expect(['Stable', 'Preview', 'Experimental']).toContain(card.maturity);
  });

  it.each(
    packageCards.map((card): [string, PackageCardData] => [card.name, card]),
  )('%s declares a non-empty title', (_name, card) => {
    expect(card.title.length).toBeGreaterThan(0);
  });
});

describe('countMarketplaceComponents', () => {
  it('counts a string component field as one component', () => {
    expect(countMarketplaceComponents({ hooks: 'hooks/shared/telemetry.json' })).toBe(1);
  });

  it('counts an array component field by its length', () => {
    expect(countMarketplaceComponents({ agents: ['a.md', 'b.md', 'c.md'] })).toBe(3);
  });

  it('sums every declared component field', () => {
    expect(
      countMarketplaceComponents({
        agents: ['a.md', 'b.md'],
        commands: ['c.md'],
        rules: [],
        skills: ['s'],
        hooks: 'hooks/shared/telemetry.json',
      }),
    ).toBe(5);
  });

  it('ignores fields that are neither a string nor an array', () => {
    expect(countMarketplaceComponents({ agents: ['a.md'], version: 3, author: {} })).toBe(1);
  });

  it('returns zero for an entry with no component fields', () => {
    expect(countMarketplaceComponents({ name: 'empty' })).toBe(0);
  });

  it('counts a catalog package that declares hooks as a single string', () => {
    const withStringHooks = catalog.plugins.filter(
      (entry) => typeof entry.hooks === 'string',
    );
    expect(withStringHooks.length).toBeGreaterThan(0);

    for (const entry of withStringHooks) {
      const withoutHooks = { ...entry, hooks: undefined };
      expect(countMarketplaceComponents(entry)).toBe(
        countMarketplaceComponents(withoutHooks) + 1,
      );
    }
  });
});

describe('loadMarketplaceCounts', () => {
  it.each(cardNames)('%s count matches its catalog membership', (name) => {
    expect(counts[name]).toBe(expectedComponentCount(catalogEntries.get(name)!));
  });

  it('resolves the meta package count from the catalog', () => {
    expect(metaPackages[metaPackageName]).toBe(
      expectedComponentCount(catalogEntries.get(metaPackageName)!),
    );
  });

  it('returns a count for every requested package and nothing more', () => {
    expect(Object.keys(counts).sort()).toEqual([...cardNames, metaPackageName].sort());
  });

  it('fails loudly for an unknown package id', () => {
    expect(() => loadMarketplaceCounts(marketplacePath, ['not-a-package'])).toThrow(
      'Unknown marketplace package: not-a-package',
    );
  });
});

describe('resolvePackageCards against the catalog', () => {
  it.each(
    packageCards.map((card): [string, PackageCardData] => [card.name, card]),
  )('%s reports a positive integer artifact count', (_name, card) => {
    expect(Number.isInteger(card.artifacts)).toBe(true);
    expect(card.artifacts).toBeGreaterThan(0);
  });

  it.each(
    packageCards.map((card): [string, PackageCardData] => [card.name, card]),
  )('%s artifact count matches the catalog tally', (name, card) => {
    expect(card.artifacts).toBe(expectedComponentCount(catalogEntries.get(name)!));
  });
});
