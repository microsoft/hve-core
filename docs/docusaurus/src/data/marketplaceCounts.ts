// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import * as fs from 'fs';

import type { PackageCardData } from './packageCards';
import { resolvePackageMaturity } from './packageCards';

const componentFields = ['agents', 'commands', 'rules', 'skills', 'hooks'];
const errorPrefix = '[marketplacePackages]';

export function countMarketplaceComponents(
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

export function loadPackageCards(marketplacePath: string): PackageCardData[] {
  const catalog = JSON.parse(
    fs.readFileSync(marketplacePath, 'utf-8'),
  ) as Record<string, unknown>;
  const plugins = catalog.plugins;

  if (!Array.isArray(plugins)) {
    throw new Error(`${errorPrefix} ${marketplacePath}: plugins must be an array`);
  }

  const seen = new Set<string>();
  const cards: PackageCardData[] = [];

  plugins.forEach((candidate, index) => {
    const position = `plugins[${index}]`;
    if (
      typeof candidate !== 'object'
      || candidate === null
      || Array.isArray(candidate)
    ) {
      throw new Error(`${errorPrefix} ${position}: entry must be an object`);
    }

    const entry = candidate as Record<string, unknown>;
    const name = requireText(entry.name, 'name', position);
    if (seen.has(name)) {
      throw new Error(`${errorPrefix} duplicate package name: ${name}`);
    }
    seen.add(name);

    const overlay = entry['x-hve'];
    if (
      typeof overlay !== 'object'
      || overlay === null
      || Array.isArray(overlay)
    ) {
      throw new Error(`${errorPrefix} ${name}: x-hve must be an object`);
    }
    const hve = overlay as Record<string, unknown>;

    const resolution = resolvePackageMaturity(hve.maturity);
    if (resolution.kind === 'retired') {
      return;
    }
    if (resolution.kind === 'unsupported') {
      throw new Error(
        `${errorPrefix} ${name}: unsupported package maturity: ${String(hve.maturity)}`,
      );
    }

    const description = requireText(entry.description, 'description', name);
    const title = requireText(hve.displayName, 'x-hve.displayName', name);
    const documentation = requireText(
      hve.documentation,
      'x-hve.documentation',
      name,
    );
    const expectedDocumentation = `docs/plugins/${name}.md`;
    if (documentation !== expectedDocumentation) {
      throw new Error(
        `${errorPrefix} ${name}: x-hve.documentation must be ${expectedDocumentation} but was ${documentation}`,
      );
    }

    cards.push({
      name,
      title,
      description,
      artifacts: countMarketplaceComponents(entry),
      maturity: resolution.maturity,
      href: `/docs/plugins/${name}`,
    });
  });

  return cards.sort((left, right) => {
    if (left.name < right.name) return -1;
    if (left.name > right.name) return 1;
    return 0;
  });
}
