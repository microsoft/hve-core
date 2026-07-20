// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { labelRegistry } from './labelRegistry';

export interface CollectionCardData {
  name: string;
  title: string;
  description: string;
  artifacts: number;
  maturity: 'Stable' | 'Preview' | 'Experimental';
  href: string;
}

export interface CollectionCardDefinition {
  name: string;
  title: string;
  description: string;
  maturity: CollectionCardData['maturity'];
  href: string;
}

export const collectionCardDefinitions: CollectionCardDefinition[] = [
  {
    name: 'ado',
    title: labelRegistry.azureDevOps,
    description: 'Azure DevOps work items, builds, and pull requests',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'coding-standards',
    title: labelRegistry.codingStandards,
    description: 'Language-specific coding conventions',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'data-science',
    title: labelRegistry.dataScience,
    description: 'Data specs, notebooks, and dashboards',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'design-thinking',
    title: labelRegistry.designThinking,
    description: 'AI-enhanced Design Thinking coaching',
    maturity: 'Preview',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'experimental',
    title: labelRegistry.experimentalCollection,
    description: 'Preview artifacts under active development',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'github',
    title: labelRegistry.github,
    description: 'GitHub issue backlogs and triage workflows',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'gitlab',
    title: labelRegistry.gitlab,
    description: 'GitLab merge requests and pipeline workflows',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'hve-core',
    title: labelRegistry.hveCore,
    description: 'RPI workflow, planning, and implementation',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'jira',
    title: labelRegistry.jira,
    description: 'Jira backlogs, triage, and PRD-driven planning',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'project-planning',
    title: labelRegistry.projectPlanning,
    description: 'ADRs, requirements, and architecture diagrams',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'security',
    title: labelRegistry.security,
    description: 'Security review, planning, incident response, and risk assessment',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
];

export interface MetaCollections {
  'hve-core-all': number;
}

export function resolveCollectionCards(
  counts: Record<string, number>,
): CollectionCardData[] {
  return collectionCardDefinitions.map((def) => ({
    ...def,
    artifacts: counts[def.name] ?? 0,
  }));
}

export function resolveMetaCollections(
  counts: Record<string, number>,
): MetaCollections {
  return {
    'hve-core-all': counts['hve-core-all'] ?? 0,
  };
}
