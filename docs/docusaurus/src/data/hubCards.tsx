import React from 'react';
import {
  GettingStartedIcon,
  AgentsPromptsIcon,
  InstructionsSkillsIcon,
  WorkflowsIcon,
  DesignThinkingIcon,
  TemplatesExamplesIcon,
} from '../components/Icons';

export interface IconCardData {
  icon: React.ReactNode;
  supertitle: string;
  title: string;
  href: string;
  description: string;
}

export interface BoxCardData {
  title: string;
  description: string;
  links: { label: string; href: string }[];
  icon?: string;
}

export const iconCards: IconCardData[] = [
  {
    icon: <GettingStartedIcon />,
    supertitle: 'Getting Started',
    title: 'Set up HVE Core',
    href: '/docs/category/getting-started',
    description: 'Install, configure, and run your first AI-assisted workflow',
  },
  {
    icon: <DesignThinkingIcon />,
    supertitle: 'HVE Guide',
    title: 'Project lifecycle',
    href: '/docs/category/hve-guide',
    description: 'Explore the HVE project lifecycle stages and role-specific guides',
  },
  {
    icon: <WorkflowsIcon />,
    supertitle: 'RPI Workflow',
    title: 'Research-Plan-Implement',
    href: '/docs/category/rpi',
    description: 'The Research-Plan-Implement loop for structured AI-assisted development',
  },
  {
    icon: <AgentsPromptsIcon />,
    supertitle: 'Agents',
    title: 'Custom AI agents',
    href: '/docs/category/agents',
    description: 'Build and configure specialized agents for your development tasks',
  },
  {
    icon: <InstructionsSkillsIcon />,
    supertitle: 'Architecture',
    title: 'System design',
    href: '/docs/category/architecture',
    description: 'Architecture decisions, design patterns, and system design references',
  },
  {
    icon: <TemplatesExamplesIcon />,
    supertitle: 'Templates',
    title: 'Reusable patterns',
    href: '/docs/category/templates',
    description: 'Ready-to-use templates for ADRs, BRDs, agents, and instructions',
  },
];

export const boxCards: BoxCardData[] = [
  {
    icon: '/img/icons/i_quickstart.svg',
    title: 'Quick Start',
    description: 'Get up and running in minutes',
    links: [
      { label: 'Installation guide', href: '/docs/category/getting-started' },
      { label: 'Your first workflow', href: '/docs/category/rpi' },
      { label: 'Browse templates', href: '/docs/category/templates' },
    ],
  },
  {
    icon: '/img/icons/i_build-ai.svg',
    title: 'Build with AI',
    description: 'Leverage AI across the development lifecycle',
    links: [
      { label: 'Configure agents', href: '/docs/category/agents' },
      { label: 'Write instructions', href: '/docs/category/contributing' },
      { label: 'Architecture', href: '/docs/category/architecture' },
    ],
  },
  {
    icon: '/img/icons/i_plan-architect.svg',
    title: 'Plan & Architect',
    description: 'Structure work before coding',
    links: [
      { label: 'Explore and specify', href: '/docs/category/hve-guide' },
      { label: 'RPI workflow', href: '/docs/category/rpi' },
      { label: 'Architecture patterns', href: '/docs/category/architecture' },
    ],
  },
  {
    icon: '/img/icons/i_customize.svg',
    title: 'Customize & Extend',
    description: 'Tailor HVE Core to your team',
    links: [
      { label: 'Custom agents', href: '/docs/category/agents' },
      { label: 'Skill packages', href: '/docs/category/contributing' },
      { label: 'Template library', href: '/docs/category/templates' },
    ],
  },
];
