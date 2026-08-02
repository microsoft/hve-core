// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT

import * as fs from 'fs';

const componentFields = ['agents', 'commands', 'rules', 'skills', 'hooks'];

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

export function loadMarketplaceCounts(
  marketplacePath: string,
  packageNames: string[],
): Record<string, number> {
  const marketplace = JSON.parse(fs.readFileSync(marketplacePath, 'utf-8')) as {
    plugins: Array<Record<string, unknown> & { name: string }>;
  };
  const entries = new Map(
    marketplace.plugins.map((entry) => [entry.name, entry]),
  );

  return Object.fromEntries(packageNames.map((name) => {
    const entry = entries.get(name);
    if (!entry) {
      throw new Error(
        `[marketplaceCounts] Unknown marketplace package: ${name}`,
      );
    }
    return [name, countMarketplaceComponents(entry)];
  }));
}