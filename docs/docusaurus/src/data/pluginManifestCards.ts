// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import * as fs from 'fs';
import * as path from 'path';

import type {
  PackageCardData,
  PackageContentKind,
  PackageContentSummary,
} from './packageCards';
import { labelRegistry } from './labelRegistry';

interface ComponentDefinition {
  field: string;
  kind: PackageContentKind;
  label: string;
  href: string;
}

const componentDefinitions: ComponentDefinition[] = [
  { field: 'agents', kind: 'agents', label: 'Agents', href: '/docs/reference/agents' },
  { field: 'commands', kind: 'prompts', label: 'Prompts', href: '/docs/reference/prompts' },
  { field: 'rules', kind: 'instructions', label: 'Instructions', href: '/docs/reference/instructions' },
  { field: 'skills', kind: 'skills', label: 'Skills', href: '/docs/reference/skills' },
];
const errorPrefix = '[pluginManifestCards]';

function countComponents(value: unknown): number {
  if (typeof value === 'string') {
    return 1;
  }
  if (Array.isArray(value)) {
    return value.length;
  }
  return 0;
}

export function countPluginComponents(
  entry: Record<string, unknown>,
): number {
  return componentDefinitions.reduce(
    (count, definition) => count + countComponents(entry[definition.field]),
    0,
  );
}

export function summarizePluginComponents(
  entry: Record<string, unknown>,
): PackageContentSummary[] {
  return componentDefinitions.flatMap((definition) => {
    const count = countComponents(entry[definition.field]);
    return count === 0 ? [] : [{
      kind: definition.kind,
      label: definition.label,
      count,
      href: definition.href,
    }];
  });
}

function requireText(value: unknown, field: string, context: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(
      `${errorPrefix} ${context}: ${field} must be a non-empty string`,
    );
  }
  return value;
}

function requireObject(value: unknown, context: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error(`${errorPrefix} ${context} must be an object`);
  }
  return value as Record<string, unknown>;
}

function readObject(pathname: string, context: string): Record<string, unknown> {
  return requireObject(JSON.parse(fs.readFileSync(pathname, 'utf-8')), context);
}

function resolvePluginManifestPath(
  repositoryRoot: string,
  source: string,
): string {
  if (
    path.isAbsolute(source)
    || /^[A-Za-z]:/.test(source)
    || source.includes('\\')
    || source.split('/').includes('..')
  ) {
    throw new Error(`${errorPrefix} source escapes the repository: ${source}`);
  }

  const manifestPath = path.resolve(repositoryRoot, source, 'plugin.json');
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`${errorPrefix} plugin manifest not found: ${source}/plugin.json`);
  }
  if (fs.realpathSync(manifestPath) !== manifestPath) {
    throw new Error(`${errorPrefix} manifest path contains a symbolic link: ${source}`);
  }
  return manifestPath;
}

/** Reads one card per local manifest, preserving catalog order. Invalid or repeated locators fail the build. */
export function loadPackageCards(pluginLocatorPath: string): PackageCardData[] {
  const catalog = readObject(pluginLocatorPath, 'catalog');
  const plugins = catalog.plugins;

  if (!Array.isArray(plugins)) {
    throw new Error(`${errorPrefix} ${pluginLocatorPath}: plugins must be an array`);
  }
  if (plugins.length === 0) {
    throw new Error(`${errorPrefix} marketplace must contain at least one plugin locator`);
  }

  const repositoryRoot = fs.realpathSync(path.resolve(path.dirname(pluginLocatorPath), '../..'));
  const rootManifest = path.join(repositoryRoot, 'plugin.json');
  const metadata = requireObject(catalog.metadata, 'metadata');
  const catalogVersion = requireText(metadata.version, 'metadata.version', 'catalog');
  const names = new Set<string>();
  const manifests = new Set<string>();
  const cards = plugins.map((value, index) => {
    const context = `plugins[${index}]`;
    const entry = requireObject(value, `${context}: entry`);
    const name = requireText(entry.name, 'name', context);
    const source = requireText(entry.source, 'source', name);
    const manifestPath = resolvePluginManifestPath(repositoryRoot, source);
    if (names.has(name.toLowerCase()) || manifests.has(manifestPath)) {
      throw new Error(`${errorPrefix} duplicate plugin name or source: ${name} (${source})`);
    }
    names.add(name.toLowerCase());
    manifests.add(manifestPath);

    const manifest = readObject(manifestPath, `${name}: plugin manifest`);
    const manifestName = requireText(manifest.name, 'manifest.name', name);
    const manifestVersion = requireText(manifest.version, 'manifest.version', name);
    if (manifestName !== name) {
      throw new Error(
        `${errorPrefix} locator name ${name} does not match manifest name ${manifestName}`,
      );
    }
    if (requireText(entry.version, 'version', name) !== manifestVersion || catalogVersion !== manifestVersion) {
      throw new Error(`${errorPrefix} ${name}: catalog and manifest versions must match`);
    }

    return {
      name,
      title: manifestPath === rootManifest ? labelRegistry.hveCore : name,
      description: requireText(manifest.description, 'manifest.description', name),
      artifacts: countPluginComponents(manifest),
      contents: summarizePluginComponents(manifest),
      maturity: labelRegistry.stable,
      href: `/docs/plugins/${name}`,
    };
  });
  if (!manifests.has(rootManifest)) {
    throw new Error(`${errorPrefix} marketplace is missing the root plugin locator`);
  }
  return cards;
}
