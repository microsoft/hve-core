export interface CollectionCardData {
  name: string;
  description: string;
  artifacts: number;
  maturity: 'Stable' | 'Preview' | 'Experimental';
  href: string;
}

export interface CollectionCardDefinition {
  name: string;
  description: string;
  maturity: CollectionCardData['maturity'];
  href: string;
}

export const collectionCardDefinitions: CollectionCardDefinition[] = [
  {
    name: 'ado',
    description: 'Azure DevOps work items, builds, and pull requests',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'coding-standards',
    description: 'Language-specific coding conventions',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'data-science',
    description: 'Data specs, notebooks, and dashboards',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'design-thinking',
    description: 'AI-enhanced Design Thinking coaching',
    maturity: 'Preview',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'experimental',
    description: 'Preview artifacts under active development',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'github',
    description: 'GitHub issue backlogs and triage workflows',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'gitlab',
    description: 'GitLab merge requests and pipeline workflows',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'hve-core',
    description: 'RPI workflow, planning, and implementation',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'jira',
    description: 'Jira backlogs, triage, and PRD-driven planning',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'project-planning',
    description: 'ADRs, requirements, and architecture diagrams',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'rai-planning',
    description: 'Responsible AI assessment, impact analysis, and risk review',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'security',
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
