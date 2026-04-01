export interface CollectionDetailData {
  name: string;
  shortDescription: string;
  detailedDescription: string;
  artifacts: number;
  maturity: 'Stable' | 'Preview' | 'Experimental';
  href: string;
  includes: string[];
}

/**
 * Collection details extracted from *.collection.md files
 * for use in the CollectionTableWithDescriptions component.
 * 
 * This data enables hover tooltips and expandable detail rows
 * as requested in issue #1266.
 */
export const collectionDetails: CollectionDetailData[] = [
  {
    name: 'ado',
    shortDescription: 'Manage Azure DevOps work items, monitor builds, create pull requests, and convert requirements documents into structured work item hierarchies',
    detailedDescription: 'Manage Azure DevOps work items, monitor builds, create pull requests, and convert requirements documents into structured work item hierarchies — all from within VS Code. This collection includes agents and prompts for Work Item Management, Build Monitoring, Pull Request Creation, PRD-to-Work-Item Conversion, and Backlog Management.',
    artifacts: 21,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'Work Item Management',
      'Build Monitoring',
      'Pull Request Creation',
      'PRD-to-Work-Item Conversion',
      'Backlog Management',
    ],
  },
  {
    name: 'coding-standards',
    shortDescription: 'Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents',
    detailedDescription: 'Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents for catching functional defects early. This collection provides instructions for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform that are automatically applied based on file patterns.',
    artifacts: 14,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'Code Review Functional',
      'Code Review Standards',
      'Code Review Full',
      'Bash, Bicep, C# instructions',
      'PowerShell, Python, Rust, Terraform',
    ],
  },
  {
    name: 'data-science',
    shortDescription: 'Generate data specifications, Jupyter notebooks, and Streamlit dashboards from natural language descriptions',
    detailedDescription: 'Generate data specifications, Jupyter notebooks, and Streamlit dashboards from natural language descriptions. Evaluate AI-powered data systems against Responsible AI standards. This collection includes specialized agents for data science workflows in Python and RAI assessment.',
    artifacts: 19,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'Data Specification Generation',
      'Jupyter Notebook Generation',
      'Streamlit Dashboard Generation',
      'Dashboard Testing',
      'RAI Planner',
    ],
  },
  {
    name: 'design-thinking',
    shortDescription: 'AI-enhanced design thinking coaching across nine methods',
    detailedDescription: 'Coaching identity, quality constraints, and methodology instructions for AI-enhanced design thinking across nine methods. The collection supports the HVE Design Thinking pyramid structure spanning Problem, Solution, and Implementation spaces.',
    artifacts: 58,
    maturity: 'Preview',
    href: '/docs/getting-started/collections',
    includes: [
      'DT Start Project',
      'DT Resume Coaching',
      'DT Method Next',
      'DT Handoff Implementation Space',
      'DT Handoff Problem Space',
    ],
  },
  {
    name: 'experimental',
    shortDescription: 'Experimental and preview artifacts not yet promoted to stable collections',
    detailedDescription: 'Experimental and preview artifacts not yet promoted to stable collections. Items in this collection may change or be removed without notice. This collection includes agents, skills, and instructions for Experiment Designer, PowerPoint Builder, and Video to GIF.',
    artifacts: 8,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
    includes: [
      'Experiment Designer',
      'PowerPoint Builder',
      'Video to GIF',
    ],
  },
  {
    name: 'github',
    shortDescription: 'Manage GitHub issue backlogs with agents for discovery, triage, sprint planning, and execution',
    detailedDescription: 'Manage GitHub issue backlogs with agents for discovery, triage, sprint planning, and execution. This collection brings structured backlog management workflows directly into VS Code.',
    artifacts: 13,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'Issue Discovery',
      'Triage',
      'Sprint Planning',
      'Backlog Execution',
    ],
  },
  {
    name: 'gitlab',
    shortDescription: 'Run GitLab merge request and pipeline workflows through a focused skill package',
    detailedDescription: 'Use GitLab merge request and pipeline workflows from VS Code through a focused Python skill for inspecting merge requests, posting notes, triggering pipelines, and reading job logs.',
    artifacts: 2,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'GitLab Skill',
    ],
  },
  {
    name: 'hve-core',
    shortDescription: 'Flagship collection: RPI (Research, Plan, Implement, Review) workflow for complex tasks with Git workflow prompts',
    detailedDescription: 'HVE Core provides the flagship RPI (Research, Plan, Implement, Review) workflow for completing complex tasks through a structured four-phase process. The RPI workflow dispatches specialized agents that collaborate autonomously to deliver well-researched, planned, and validated implementations. This collection also includes Git workflow prompts for commit messages, merge operations, repository setup, and pull request management.',
    artifacts: 40,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'RPI Agent',
      'Task Researcher',
      'Task Planner',
      'Task Implementor',
      'Task Reviewer',
    ],
  },
  {
    name: 'hve-core-all',
    shortDescription: 'Complete collection of all artifacts across all domains',
    detailedDescription: 'HVE Core provides the complete collection of AI chat agents, prompts, instructions, and skills for VS Code with GitHub Copilot. This edition includes every artifact across all domains: development workflows, architecture, Azure DevOps, GitHub and Jira backlog workflows, data science, design thinking, security, and more.',
    artifacts: 221,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'All domain collections',
      'Security and planning agents',
      'Code review agents',
      'Supporting subagents',
      'All skills',
    ],
  },
  {
    name: 'installer',
    shortDescription: 'Deploy HVE artifacts across workspace configurations with decision-driven setup',
    detailedDescription: 'Deploy HVE Core artifacts across workspace configurations with the hve-core-installer skill. This collection provides decision-driven setup for selecting and installing collections, agents, prompts, and instructions via the VS Code extension or clone-based methods.',
    artifacts: 2,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'HVE Core Installer',
    ],
  },
  {
    name: 'jira',
    shortDescription: 'Manage Jira backlogs, plan PRD-driven issue hierarchies, and execute issue operations',
    detailedDescription: 'Manage Jira backlog workflows and PRD-driven issue planning from VS Code. This collection adds dedicated Jira agents, prompts, and instructions on top of the Jira skill so discovery, triage, execution, and planning workflows use the same tracking and handoff patterns as the rest of HVE Core.',
    artifacts: 13,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'Jira Backlog Manager agent',
      'Jira PRD to WIT planning agent',
      'Jira prompts for backlog workflows',
      'Jira planning instructions',
      'The Jira skill',
    ],
  },
  {
    name: 'project-planning',
    shortDescription: 'Create architecture decision records, requirements documents, and diagrams through guided AI workflows',
    detailedDescription: 'Create architecture decision records, requirements documents, and diagrams — all through guided AI workflows. Evaluate AI-powered systems against Responsible AI standards and conduct STRIDE-based security model analysis with automated backlog generation.',
    artifacts: 49,
    maturity: 'Stable',
    href: '/docs/getting-started/collections',
    includes: [
      'Agile Coach',
      'Product Manager Advisor',
      'UX/UI Designer',
      'Architecture Decision Records',
      'Architecture Diagrams',
    ],
  },
  {
    name: 'rai-planning',
    shortDescription: 'Assess AI systems against Responsible AI standards and capture standards-aligned backlog work',
    detailedDescription: 'Assess AI systems against Responsible AI standards and capture standards-aligned backlog work. This collection provides specialized agents and prompts for sensitive uses screening, security model analysis, impact assessment, and dual-format backlog handoff.',
    artifacts: 13,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
    includes: [
      'RAI Planner',
      'Sensitive uses screening',
      'Security model analysis',
      'Impact assessment',
      'Dual-format backlog handoff',
    ],
  },
  {
    name: 'security',
    shortDescription: 'Security review, planning, incident response, risk assessment, and vulnerability analysis',
    detailedDescription: 'Security review, planning, incident response, risk assessment, and vulnerability analysis. This collection includes specialized agents for STRIDE-based security model analysis, supply chain security assessment, and automated backlog generation.',
    artifacts: 47,
    maturity: 'Experimental',
    href: '/docs/getting-started/collections',
    includes: [
      'Security Planner',
      'SSSC Planner',
      'STRIDE-based analysis',
      'Supply chain security assessment',
      'Automated backlog generation',
    ],
  },
];