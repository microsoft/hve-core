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
    icon: <AgentsPromptsIcon />,
    supertitle: 'Agents & Prompts',
    title: 'Custom AI agents',
    href: '/docs/category/agents-and-prompts',
    description: 'Build and configure specialized agents for your development tasks',
  },
  {
    icon: <InstructionsSkillsIcon />,
    supertitle: 'Instructions & Skills',
    title: 'Coding guidelines',
    href: '/docs/category/instructions-and-skills',
    description: 'Auto-applied coding standards and reusable skill packages',
  },
  {
    icon: <WorkflowsIcon />,
    supertitle: 'Workflows',
    title: 'Development flows',
    href: '/docs/category/workflows',
    description: 'The RPI workflow and structured AI-assisted development patterns',
  },
  {
    icon: <DesignThinkingIcon />,
    supertitle: 'Design Thinking',
    title: 'Shape the work',
    href: '/docs/category/design-thinking',
    description: 'Plan, specify, and architect features before implementation',
  },
  {
    icon: <TemplatesExamplesIcon />,
    supertitle: 'Templates & Examples',
    title: 'Reusable patterns',
    href: '/docs/category/templates-and-examples',
    description: 'Ready-to-use templates for agents, prompts, and instructions',
  },
];

export const boxCards: BoxCardData[] = [
  {
    title: 'Quick Start',
    description: 'Get up and running in minutes',
    links: [
      { label: 'Installation guide', href: '/docs/category/getting-started' },
      { label: 'Your first workflow', href: '/docs/category/workflows' },
      { label: 'Browse templates', href: '/docs/category/templates-and-examples' },
    ],
  },
  {
    title: 'Build with AI',
    description: 'Leverage AI across the development lifecycle',
    links: [
      { label: 'Configure agents', href: '/docs/category/agents-and-prompts' },
      { label: 'Write instructions', href: '/docs/category/instructions-and-skills' },
      { label: 'Design thinking', href: '/docs/category/design-thinking' },
    ],
  },
  {
    title: 'Plan & Architect',
    description: 'Structure work before coding',
    links: [
      { label: 'Explore and specify', href: '/docs/category/design-thinking' },
      { label: 'RPI workflow', href: '/docs/category/workflows' },
      { label: 'Architecture patterns', href: '/docs/category/templates-and-examples' },
    ],
  },
  {
    title: 'Customize & Extend',
    description: 'Tailor HVE Core to your team',
    links: [
      { label: 'Custom agents', href: '/docs/category/agents-and-prompts' },
      { label: 'Skill packages', href: '/docs/category/instructions-and-skills' },
      { label: 'Template library', href: '/docs/category/templates-and-examples' },
    ],
  },
];
