export interface CollectionCardData {
  name: string;
  description: string;
  artifacts: number;
  maturity: 'Stable' | 'Preview' | 'Experimental';
  href: string;
}

export const collectionCards: CollectionCardData[] = [
  {
    name: 'ado',
    description: 'Azure DevOps work items, builds, and pull requests',
    artifacts: 21,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'coding-standards',
    description: 'Language-specific coding conventions',
    artifacts: 15,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'data-science',
    description: 'Data specs, notebooks, and dashboards',
    artifacts: 19,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'design-thinking',
    description: 'AI-enhanced Design Thinking coaching',
    artifacts: 58,
    maturity: 'Preview',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'experimental',
    description: 'Preview artifacts under active development',
    artifacts: 8,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'github',
    description: 'GitHub issue backlogs and triage workflows',
    artifacts: 14,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'hve-core',
    description: 'RPI workflow, planning, and implementation',
    artifacts: 42,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'project-planning',
    description: 'ADRs, requirements, and architecture diagrams',
    artifacts: 49,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'security',
    description: 'Security review, planning, incident response, and risk assessment',
    artifacts: 47,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
];

export interface MetaCollections {
  'hve-core-all': number;
}

export const metaCollections: MetaCollections = {
  'hve-core-all': 225,
};
