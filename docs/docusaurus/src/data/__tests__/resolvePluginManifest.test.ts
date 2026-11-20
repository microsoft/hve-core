// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { loadPackageCards } from '../pluginManifestCards';

let fixtureRoot: string;
let fixtureIndex = 0;

beforeAll(() => {
  fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'hve-plugin-manifest-'));
});

afterAll(() => {
  fs.rmSync(fixtureRoot, { recursive: true, force: true });
});

type JsonObject = Record<string, unknown>;

function locator(overrides: JsonObject = {}): JsonObject {
  return {
    name: 'hve-core',
    source: '.',
    version: '1.2.3',
    ...overrides,
  };
}

function manifest(overrides: JsonObject = {}): JsonObject {
  return {
    name: 'hve-core',
    description: 'HVE Core description',
    version: '1.2.3',
    agents: ['.github/agents/one.agent.md', '.github/agents/two.agent.md'],
    commands: ['.github/commands/one.prompt.md'],
    rules: [],
    skills: ['.github/skills/one'],
    ...overrides,
  };
}

function writeFixture(
  catalog: JsonObject,
  pluginManifest: JsonObject | null = manifest(),
  additional: Record<string, JsonObject> = {},
): string {
  const root = path.join(fixtureRoot, `fixture-${(fixtureIndex += 1)}`);
  const pluginLocatorDirectory = path.join(root, '.github', 'plugin');
  fs.mkdirSync(pluginLocatorDirectory, { recursive: true });
  const pluginLocatorPath = path.join(pluginLocatorDirectory, 'marketplace.json');
  fs.writeFileSync(pluginLocatorPath, JSON.stringify(catalog), 'utf-8');
  if (pluginManifest !== null) {
    fs.writeFileSync(
      path.join(root, 'plugin.json'),
      JSON.stringify(pluginManifest),
      'utf-8',
    );
  }
  for (const [source, content] of Object.entries(additional)) {
    fs.mkdirSync(path.join(root, source), { recursive: true });
    fs.writeFileSync(path.join(root, source, 'plugin.json'), JSON.stringify(content));
  }
  return pluginLocatorPath;
}

function catalog(plugins: unknown, version = '1.2.3'): JsonObject {
  return { metadata: { version }, plugins };
}

describe('loadPackageCards plugin manifest resolution', () => {
  it('builds one stable card from the resolved plugin manifest', () => {
    expect(loadPackageCards(writeFixture(catalog([locator()])))).toEqual([{
      name: 'hve-core',
      title: 'HVE Core',
      description: 'HVE Core description',
      artifacts: 4,
      contents: [
        { kind: 'agents', label: 'Agents', count: 2, href: '/docs/reference/agents' },
        { kind: 'prompts', label: 'Prompts', count: 1, href: '/docs/reference/prompts' },
        { kind: 'skills', label: 'Skills', count: 1, href: '/docs/reference/skills' },
      ],
      maturity: 'Stable',
      href: '/docs/plugins/hve-core',
    }]);
  });

  it('reads each source in catalog order, even when the All plugin is last', () => {
    const extra = locator({ name: 'focus', source: './fixture/subdir' });
    const file = writeFixture(catalog([extra, locator()]), manifest(), {
      'fixture/subdir': manifest({ name: 'focus', description: 'Subset', agents: [], commands: [], skills: ['one'] }),
    });
    expect(loadPackageCards(file).map(({ name, title, description, artifacts }) =>
      [name, title, description, artifacts])).toEqual([
      ['focus', 'focus', 'Subset', 1],
      ['hve-core', 'HVE Core', 'HVE Core description', 4],
    ]);
  });
});

describe('loadPackageCards failures', () => {
  it('rejects a missing plugins array', () => {
    const file = writeFixture({ metadata: { version: '1.2.3' } });
    expect(() => loadPackageCards(file)).toThrow('plugins must be an array');
  });

  it('rejects an empty catalog', () => {
    expect(() => loadPackageCards(writeFixture(catalog([])))).toThrow(
      'must contain at least one plugin locator',
    );
  });

  it.each([
    locator({ name: 'different', source: './' }),
    locator({ name: 'HVE-CORE', source: 'other' }),
  ])('rejects a repeated name or source', (extra) => {
    const file = writeFixture(catalog([locator(), extra]), manifest(), { other: manifest({ name: 'HVE-CORE' }) });
    expect(() => loadPackageCards(file)).toThrow('duplicate plugin name or source');
  });

  it('rejects a non-object locator', () => {
    expect(() => loadPackageCards(writeFixture(catalog([null])))).toThrow(
      'plugins[0]: entry must be an object',
    );
  });

  it.each(['/absolute', '../outside', '..\\outside'])(
    'rejects escaping source %s',
    (source) => {
      const file = writeFixture(catalog([locator({ source })]));
      expect(() => loadPackageCards(file)).toThrow('source escapes the repository');
    },
  );

  it('rejects a missing plugin manifest', () => {
    const file = writeFixture(catalog([locator()]), null);
    expect(() => loadPackageCards(file)).toThrow('plugin manifest not found');
  });

  it('does not follow a linked manifest outside its source', () => {
    const file = writeFixture(catalog([locator(), locator({ name: 'focus', source: 'linked' })]));
    const root = path.resolve(path.dirname(file), '../..');
    fs.mkdirSync(path.join(root, 'linked'));
    fs.symlinkSync(path.join(root, 'plugin.json'), path.join(root, 'linked/plugin.json'));
    expect(() => loadPackageCards(file)).toThrow('manifest path contains a symbolic link');
  });

  it('rejects locator and manifest name drift', () => {
    const file = writeFixture(catalog([locator()]), manifest({ name: 'other' }));
    expect(() => loadPackageCards(file)).toThrow(
      'locator name hve-core does not match manifest name other',
    );
  });

  it('rejects catalog and manifest version drift', () => {
    const locatorDrift = writeFixture(catalog([locator({ version: '2.0.0' })]));
    expect(() => loadPackageCards(locatorDrift)).toThrow(
      'catalog and manifest versions must match',
    );

    const metadataDrift = writeFixture(catalog([locator()], '2.0.0'));
    expect(() => loadPackageCards(metadataDrift)).toThrow(
      'catalog and manifest versions must match',
    );
  });

  it('rejects missing manifest description', () => {
    const file = writeFixture(catalog([locator()]), manifest({ description: undefined }));
    expect(() => loadPackageCards(file)).toThrow(
      'manifest.description must be a non-empty string',
    );
  });
});
