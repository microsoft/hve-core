import React from 'react';
import {
  GettingStartedIcon,
  AgentsPromptsIcon,
  InstructionsSkillsIcon,
  WorkflowsIcon,
  DesignThinkingIcon,
  TemplatesExamplesIcon,
  VsCodeExtensionIcon
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
    href: '/docs/getting-started/',
    description: 'Install, configure, and run your first AI-assisted workflow',
  },

  { 
    icon:<VsCodeExtensionIcon/>,
    supertitle : 'Install',
    title :'VS Code Extension',
    href : 'https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core',
    description: 'Install the HVE Core extension from the VS Code Marketplace',

  },

  {
    icon: <DesignThinkingIcon />,
    supertitle: 'HVE Guide',
    title: 'Project lifecycle',
    href: '/docs/hve-guide/',
    description: 'Explore the HVE project lifecycle stages and role-specific guides',
  },
  {
    icon: <WorkflowsIcon />,
    supertitle: 'RPI Workflow',
    title: 'Research-Plan-Implement',
    href: '/docs/rpi/',
    description: 'The Research-Plan-Implement loop for structured AI-assisted development',
  },
  {
    icon: <AgentsPromptsIcon />,
    supertitle: 'Agents',
    title: 'Custom AI agents',
    href: '/docs/agents/',
    description: 'Build and configure specialized agents for your development tasks',
  },
  {
    icon: <InstructionsSkillsIcon />,
    supertitle: 'Architecture',
    title: 'System design',
    href: '/docs/architecture/',
    description: 'Architecture decisions, design patterns, and system design references',
  },
  {
    icon: <TemplatesExamplesIcon />,
    supertitle: 'Templates',
    title: 'Reusable patterns',
    href: '/docs/templates/',
    description: 'Ready-to-use templates for ADRs, BRDs, agents, and instructions',
  },
];

export const boxCards: BoxCardData[] = [
  {
    icon: '/img/icons/i_quickstart.svg',
    title: 'Quick Start',
    description: 'Get up and running in minutes',
    links: [
      { label: 'Installation guide', href: '/docs/getting-started/' },
      { label: 'Your first workflow', href: '/docs/rpi/' },
      { label: 'Browse templates', href: '/docs/templates/' },
    ],
  },
  {
    icon: '/img/icons/i_build-ai.svg',
    title: 'Build with AI',
    description: 'Leverage AI across the development lifecycle',
    links: [
      { label: 'Configure agents', href: '/docs/agents/' },
      { label: 'Write instructions', href: '/docs/customization/' },
      { label: 'Architecture', href: '/docs/architecture/' },
    ],
  },
  {
    icon: '/img/icons/i_plan-architect.svg',
    title: 'Plan & Architect',
    description: 'Structure work before coding',
    links: [
      { label: 'Explore and specify', href: '/docs/hve-guide/' },
      { label: 'RPI workflow', href: '/docs/rpi/' },
      { label: 'Architecture patterns', href: '/docs/architecture/' },
    ],
  },
  {
    icon: '/img/icons/i_customize.svg',
    title: 'Customize & Extend',
    description: 'Tailor HVE Core to your team',
    links: [
      { label: 'Custom agents', href: '/docs/agents/' },
      { label: 'Skill packages', href: '/docs/customization/' },
      { label: 'Template library', href: '/docs/templates/' },
    ],
  },
];
