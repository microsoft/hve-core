// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { resolvePackageMaturity } from '../packageCards';
import { loadPackageCards } from '../marketplaceCounts';

let fixtureRoot: string;
let fixtureIndex = 0;

beforeAll(() => {
  fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'hve-marketplace-'));
});

afterAll(() => {
  fs.rmSync(fixtureRoot, { recursive: true, force: true });
});

type Entry = Record<string, unknown>;

function entry(name: string, overrides: Entry = {}): Entry {
  const { 'x-hve': overlay, ...rest } = overrides;
  return {
    name,
    description: `${name} description`,
    agents: [`agents/${name}/first.md`, `agents/${name}/second.md`],
    skills: [`skills/${name}/only`],
    hooks: `hooks/${name}/telemetry.json`,
    ...rest,
    'x-hve': {
      displayName: `HVE Core - ${name}`,
      documentation: `docs/plugins/${name}.md`,
      ...((overlay ?? {}) as Entry),
    },
  };
}

function withoutKey(source: Entry, key: string): Entry {
  const copy = { ...source };
  delete copy[key];
  return copy;
}

function loadFixture(plugins: unknown) {
  const file = path.join(fixtureRoot, `catalog-${(fixtureIndex += 1)}.json`);
  fs.writeFileSync(file, JSON.stringify({ plugins }), 'utf-8');
  return loadPackageCards(file);
}

describe('resolvePackageMaturity', () => {
  it('treats an absent maturity as stable', () => {
    expect(resolvePackageMaturity(undefined)).toEqual({
      kind: 'active',
      maturity: 'Stable',
    });
  });

  it.each([
    ['stable', 'Stable'],
    ['preview', 'Preview'],
    ['experimental', 'Experimental'],
  ])('normalizes %s to %s', (raw, label) => {
    expect(resolvePackageMaturity(raw)).toEqual({ kind: 'active', maturity: label });
  });

  it.each(['deprecated', 'removed'])('retires %s', (raw) => {
    expect(resolvePackageMaturity(raw)).toEqual({ kind: 'retired' });
  });

  it.each([['beta'], [''], [7], [null], [{}], [['stable']]])(
    'rejects the unsupported value %p',
    (raw) => {
      expect(resolvePackageMaturity(raw)).toEqual({ kind: 'unsupported' });
    },
  );
});

describe('loadPackageCards cardinality', () => {
  it('builds a complete card from one entry', () => {
    expect(loadFixture([entry('solo')])).toEqual([
      {
        name: 'solo',
        title: 'HVE Core - solo',
        description: 'solo description',
        artifacts: 4,
        maturity: 'Stable',
        href: '/docs/plugins/solo',
      },
    ]);
  });

  it('builds one card per entry sorted ordinally by name', () => {
    const cards = loadFixture([entry('zebra'), entry('alpha'), entry('alpha-two')]);
    expect(cards.map((card) => card.name)).toEqual(['alpha', 'alpha-two', 'zebra']);
  });

  it('derives fields and counts from each entry', () => {
    const cards = loadFixture([
      entry('one', {
        description: 'first description',
        'x-hve': { displayName: 'First Package', maturity: 'preview' },
      }),
      entry('two', {
        agents: 'agents/two/single.md',
        commands: ['commands/two/a.md', 'commands/two/b.md'],
        rules: [],
        skills: undefined,
        hooks: undefined,
        'x-hve': { displayName: 'Second Package', maturity: 'experimental' },
      }),
    ]);

    expect(cards).toEqual([
      expect.objectContaining({
        name: 'one', title: 'First Package', description: 'first description',
        artifacts: 4, maturity: 'Preview', href: '/docs/plugins/one',
      }),
      expect.objectContaining({
        name: 'two', title: 'Second Package', artifacts: 3,
        maturity: 'Experimental', href: '/docs/plugins/two',
      }),
    ]);
  });
});

describe('loadPackageCards retirement', () => {
  it.each(['deprecated', 'removed'])('drops a %s entry', (maturity) => {
    const cards = loadFixture([
      entry('kept'),
      entry('retired', { 'x-hve': { maturity } }),
    ]);
    expect(cards.map((card) => card.name)).toEqual(['kept']);
  });

  it('returns no cards when every entry is retired', () => {
    expect(loadFixture([
      entry('gone', { 'x-hve': { maturity: 'removed' } }),
      entry('old', { 'x-hve': { maturity: 'deprecated' } }),
    ])).toEqual([]);
  });
});

describe('loadPackageCards failures', () => {
  it('rejects a missing plugins array', () => {
    const file = path.join(fixtureRoot, 'no-plugins.json');
    fs.writeFileSync(file, JSON.stringify({ name: 'hve-core' }), 'utf-8');
    expect(() => loadPackageCards(file)).toThrow('plugins must be an array');
  });

  it('rejects a non-object entry', () => {
    expect(() => loadFixture([null])).toThrow('plugins[0]: entry must be an object');
  });

  it('rejects a missing name', () => {
    expect(() => loadFixture([withoutKey(entry('solo'), 'name')])).toThrow(
      'plugins[0]: name must be a non-empty string',
    );
  });

  it('rejects duplicate names', () => {
    expect(() => loadFixture([entry('twin'), entry('twin')])).toThrow(
      'duplicate package name: twin',
    );
  });

  it('rejects missing required card metadata', () => {
    expect(() => loadFixture([entry('solo', { description: undefined })])).toThrow(
      'solo: description must be a non-empty string',
    );
    expect(() => loadFixture([withoutKey(entry('solo'), 'x-hve')])).toThrow(
      'solo: x-hve must be an object',
    );
    expect(() => loadFixture([
      entry('solo', { 'x-hve': { displayName: undefined } }),
    ])).toThrow('solo: x-hve.displayName must be a non-empty string');
  });

  it('rejects an incorrect documentation path', () => {
    expect(() => loadFixture([
      entry('solo', { 'x-hve': { documentation: 'docs/plugins/other.md' } }),
    ])).toThrow('solo: x-hve.documentation must be docs/plugins/solo.md');
  });

  it('rejects unsupported active maturity', () => {
    expect(() => loadFixture([
      entry('solo', { 'x-hve': { maturity: 'beta' } }),
    ])).toThrow('solo: unsupported package maturity: beta');
  });
});
