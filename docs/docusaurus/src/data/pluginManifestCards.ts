// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import * as fs from 'fs';
import * as path from 'path';

import type { PackageCardData } from './packageCards';
import { labelRegistry } from './labelRegistry';

const componentFields = ['agents', 'commands', 'rules', 'skills', 'hooks'];
const errorPrefix = '[pluginManifestCards]';

export function countPluginComponents(
  entry: Record<string, unknown>,
): number {
  return componentFields.reduce((count, field) => {
    const value = entry[field];
    if (typeof value === 'string') {
      return count + 1;
    }
    if (Array.isArray(value)) {
      return count + value.length;
    }
    return count;
  }, 0);
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
  pluginLocatorPath: string,
  source: string,
): string {
  if (
    path.isAbsolute(source)
    || source.includes('\\')
    || source.split('/').includes('..')
  ) {
    throw new Error(`${errorPrefix} source escapes the repository: ${source}`);
  }

  const repositoryRoot = path.resolve(path.dirname(pluginLocatorPath), '../..');
  const pluginRoot = path.resolve(repositoryRoot, ...source.split('/'));
  const relative = path.relative(repositoryRoot, pluginRoot);
  if (
    relative === '..'
    || relative.startsWith(`..${path.sep}`)
    || path.isAbsolute(relative)
  ) {
    throw new Error(`${errorPrefix} source escapes the repository: ${source}`);
  }

  return path.join(pluginRoot, 'plugin.json');
}

export function loadPackageCards(pluginLocatorPath: string): PackageCardData[] {
  const catalog = readObject(pluginLocatorPath, 'catalog');
  const plugins = catalog.plugins;

  if (!Array.isArray(plugins)) {
    throw new Error(`${errorPrefix} ${pluginLocatorPath}: plugins must be an array`);
  }
  if (plugins.length !== 1) {
    throw new Error(
      `${errorPrefix} marketplace must contain exactly one plugin locator`,
    );
  }

  const entry = requireObject(plugins[0], 'plugins[0]: entry');
  const name = requireText(entry.name, 'name', 'plugins[0]');
  const source = requireText(entry.source, 'source', name);
  const entryVersion = requireText(entry.version, 'version', name);
  const metadata = requireObject(catalog.metadata, 'metadata');
  const catalogVersion = requireText(metadata.version, 'metadata.version', name);
  const manifestPath = resolvePluginManifestPath(pluginLocatorPath, source);
  if (!fs.existsSync(manifestPath)) {
    throw new Error(
      `${errorPrefix} ${name}: plugin manifest not found: ${source}/plugin.json`,
    );
  }

  const manifest = readObject(manifestPath, `${name}: plugin manifest`);
  const manifestName = requireText(manifest.name, 'manifest.name', name);
  const manifestVersion = requireText(manifest.version, 'manifest.version', name);
  if (manifestName !== name) {
    throw new Error(
      `${errorPrefix} locator name ${name} does not match manifest name ${manifestName}`,
    );
  }
  if (entryVersion !== manifestVersion || catalogVersion !== manifestVersion) {
    throw new Error(
      `${errorPrefix} ${name}: catalog and manifest versions must match`,
    );
  }

  return [{
    name,
    title: labelRegistry.hveCore,
    description: requireText(manifest.description, 'manifest.description', name),
    artifacts: countPluginComponents(manifest),
    maturity: labelRegistry.stable,
    href: `/docs/plugins/${name}`,
  }];
}