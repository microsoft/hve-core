export interface CollectionCardData {
  name: string;
  description: string;
  artifacts: number;
  maturity: 'Stable' | 'Preview' | 'Experimental';
  href: string;
  extendedDescription?: string; 
}

export interface CollectionCardDefinition {
  name: string;
  description: string;
  maturity: CollectionCardData['maturity'];
  href: string;
  extendedDescription?: string; 
}

export const collectionCardDefinitions: CollectionCardDefinition[] = [
  {
    name: 'ado',
    description: 'Azure DevOps work items, builds, and pull requests',
    extendedDescription: 'Manage Azure DevOps work items, monitor builds, create pull requests, and convert requirements documents into structured work item hierarchies — all from within VS Code. This collection includes agents and prompts for Work Item Management, Build Monitoring, Pull Request Creation, PRD-to-Work-Item Conversion, and Backlog Management',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'coding-standards',
    description: 'Language-specific coding conventions',
    extendedDescription: 'Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents for catching functional defects early. This collection provides instructions for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform that are automatically applied based on file patterns.',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'data-science',
    description: 'Data specs, notebooks, and dashboards',
    extendedDescription: 'Generate data specifications, Jupyter notebooks, and Streamlit dashboards from natural language descriptions. Evaluate AI-powered data systems against Responsible AI standards. This collection includes specialized agents for data science workflows in Python and RAI assessment.',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'design-thinking',
    description: 'AI-enhanced Design Thinking coaching',
    extendedDescription: 'Coaching identity, quality constraints, and methodology instructions for AI-enhanced design thinking across nine methods. The collection supports the HVE Design Thinking pyramid structure spanning Problem, Solution, and Implementation spaces.',
    maturity: 'Preview',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'experimental',
    description: 'Preview artifacts under active development',
    extendedDescription: 'Experimental and preview artifacts not yet promoted to stable collections. Items in this collection may change or be removed without notice. This collection includes agents, skills, and instructions for Experiment Designer, PowerPoint Builder, and Video to GIF.',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'github',
    description: 'GitHub issue backlogs and triage workflows',
    extendedDescription: 'Manage GitHub issue backlogs with agents for discovery, triage, sprint planning, and execution. This collection brings structured backlog management workflows directly into VS Code.',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'gitlab',
    description: 'GitLab merge requests and pipeline workflows',
    extendedDescription: 'Use GitLab merge request and pipeline workflows from VS Code through a focused Python skill for inspecting merge requests, posting notes, triggering pipelines, and reading job logs.',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'hve-core',
    description: 'RPI workflow, planning, and implementation',
    extendedDescription: 'HVE Core provides the flagship RPI (Research, Plan, Implement, Review) workflow for completing complex tasks through a structured four-phase process. The RPI workflow dispatches specialized agents that collaborate autonomously to deliver well-researched, planned, and validated implementations. This collection also includes Git workflow prompts for commit messages, merge operations, repository setup, and pull request management.',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'jira',
    description: 'Jira backlogs, triage, and PRD-driven planning',
    extendedDescription: 'Manage Jira backlog workflows and PRD-driven issue planning from VS Code. This collection adds dedicated Jira agents, prompts, and instructions on top of the Jira skill so discovery, triage, execution, and planning workflows use the same tracking and handoff patterns as the rest of HVE Core.',
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'project-planning',
    description: 'ADRs, requirements, and architecture diagrams',
    extendedDescription: 'Create architecture decision records, requirements documents, and diagrams — all through guided AI workflows. Evaluate AI-powered systems against Responsible AI standards and conduct STRIDE-based security model analysis with automated backlog generation.',
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
  },
  {
    name: 'security',
    description: 'Security review, planning, incident response, and risk assessment',
    extendedDescription: 'Security review, planning, incident response, risk assessment, and vulnerability analysis. This collection includes specialized agents for STRIDE-based security model analysis, supply chain security assessment, and automated backlog generation.',
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
