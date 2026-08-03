// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { labelRegistry } from './labelRegistry';

export interface PackageCardData {
  name: string;
  title: string;
  description: string;
  artifacts: number;
  maturity: 'Stable' | 'Preview' | 'Experimental';
  href: string;
}

export interface PackageCardDefinition {
  name: string;
  title: string;
  description: string;
  maturity: PackageCardData['maturity'];
  href: string;
}

// hve-core is the only marketplace identity. Per-component lifecycle labels are
// disclosed on the identity page, so the card carries the identity's own maturity.
export const packageCardDefinitions: PackageCardDefinition[] = [
  {
    name: 'hve-core',
    title: labelRegistry.hveCore,
    description: 'All active agents, prompts, instructions, skills, and hooks in one identity',
    maturity: 'Stable',
    href: '/docs/getting-started/packages',
  },
];

export function resolvePackageCards(
  counts: Record<string, number>,
): PackageCardData[] {
  return packageCardDefinitions.map((def) => ({
    ...def,
    artifacts: counts[def.name] ?? 0,
  }));
}
