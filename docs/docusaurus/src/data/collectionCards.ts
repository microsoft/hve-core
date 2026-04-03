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
    artifacts: 21,
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
    artifacts: 13,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'gitlab',
    description: 'GitLab merge requests and pipeline workflows',
    artifacts: 2,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'hve-core',
    description: 'RPI workflow, planning, and implementation',
    artifacts: 40,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'jira',
    description: 'Jira backlogs, triage, and PRD-driven planning',
    artifacts: 13,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'project-planning',
    description: 'ADRs, requirements, and architecture diagrams',
    artifacts: 48,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'rai-planning',
    description: 'Responsible AI assessment, impact analysis, and risk review',
    artifacts: 12,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'security',
    description: 'Security review, planning, incident response, and risk assessment',
    artifacts: 46,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
];

export interface MetaCollections {
  'hve-core-all': number;
}

export const metaCollections: MetaCollections = {
  'hve-core-all': 228,
};
