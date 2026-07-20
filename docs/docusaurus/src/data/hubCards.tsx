// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
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
import { labelRegistry } from '../data/labelRegistry';

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
    supertitle: labelRegistry.gettingStarted,
    title: labelRegistry.setUpHveCore,
    href: '/docs/getting-started/',
    description: 'Install, configure, and run your first AI-assisted workflow',
  },

  {
    icon:<VsCodeExtensionIcon/>,
    supertitle: labelRegistry.install,
    title: labelRegistry.vsCodeExtension,
    href: 'https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core',
    description: 'Install the HVE Core extension from the VS Code Marketplace',
  },

  {
    icon: <DesignThinkingIcon />,
    supertitle: labelRegistry.hveGuide,
    title: labelRegistry.projectLifecycle,
    href: '/docs/hve-guide/',
    description: 'Explore the HVE project lifecycle stages and role-specific guides',
  },
  {
    icon: <WorkflowsIcon />,
    supertitle: labelRegistry.rpiWorkflow,
    title: labelRegistry.researchPlanImplement,
    href: '/docs/rpi/',
    description: 'The Research-Plan-Implement loop for structured AI-assisted development',
  },
  {
    icon: <AgentsPromptsIcon />,
    supertitle: labelRegistry.agents,
    title: labelRegistry.customAiAgents,
    href: '/docs/agents/',
    description: 'Build and configure specialized agents for your development tasks',
  },
  {
    icon: <InstructionsSkillsIcon />,
    supertitle: labelRegistry.architecture,
    title: labelRegistry.systemDesign,
    href: '/docs/architecture/',
    description: 'Architecture decisions, design patterns, and system design references',
  },
  {
    icon: <TemplatesExamplesIcon />,
    supertitle: labelRegistry.templates,
    title: labelRegistry.reusablePatterns,
    href: '/docs/templates/',
    description: 'Ready-to-use templates for ADRs, BRDs, agents, and instructions',
  },
];

export const boxCards: BoxCardData[] = [
  {
    icon: '/img/icons/i_quickstart.svg',
    title: labelRegistry.quickStart,
    description: 'Get up and running in minutes',
    links: [
      { label: 'Installation guide', href: '/docs/getting-started/' },
      { label: 'Your first workflow', href: '/docs/rpi/' },
      { label: 'Browse templates', href: '/docs/templates/' },
    ],
  },
  {
    icon: '/img/icons/i_build-ai.svg',
    title: labelRegistry.buildWithAi,
    description: 'Leverage AI across the development lifecycle',
    links: [
      { label: 'Configure agents', href: '/docs/agents/' },
      { label: 'Write instructions', href: '/docs/customization/' },
      { label: 'Architecture', href: '/docs/architecture/' },
    ],
  },
  {
    icon: '/img/icons/i_plan-architect.svg',
    title: labelRegistry.planAndArchitect,
    description: 'Structure work before coding',
    links: [
      { label: 'Explore and specify', href: '/docs/hve-guide/' },
      { label: 'RPI workflow', href: '/docs/rpi/' },
      { label: 'Architecture patterns', href: '/docs/architecture/' },
    ],
  },
  {
    icon: '/img/icons/i_customize.svg',
    title: labelRegistry.customizeAndExtend,
    description: 'Tailor HVE Core to your team',
    links: [
      { label: 'Custom agents', href: '/docs/agents/' },
      { label: 'Skill packages', href: '/docs/customization/' },
      { label: 'Template library', href: '/docs/templates/' },
    ],
  },
];
