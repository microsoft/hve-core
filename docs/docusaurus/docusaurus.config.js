// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
// @ts-check
import { themes as prismThemes } from 'prism-react-renderer';
import remarkGithubAlert from 'remark-github-blockquote-alert';
import * as fs from 'fs';
import * as path from 'path';
import { labelRegistry } from './src/data/labelRegistry';

const collectionsDir = path.resolve(__dirname, '../../collections');

/**
 * @param {string} name
 */
function countYamlPaths(name) {
  const yamlPath = path.join(collectionsDir, `${name}.collection.yml`);
  let content;
  try {
    content = fs.readFileSync(yamlPath, 'utf-8');
  } catch {
    throw new Error(
      `[docusaurus.config.js] Cannot read collection manifest: ${yamlPath}\n` +
      `Ensure "${name}" exists in the collections/ directory.`,
    );
  }
  return (content.match(/^\s*- path:/gm) || []).length;
}

const collectionNames = [
  'ado', 'coding-standards', 'data-science', 'design-thinking',
  'experimental', 'github', 'gitlab', 'hve-core', 'jira',
  'project-planning', 'security', 'hve-core-all',
];
const collectionCounts = Object.fromEntries(
  collectionNames.map((n) => [n, countYamlPaths(n)]),
);

const accessibleGithubPrismTheme = {
  ...prismThemes.github,
  styles: prismThemes.github.styles.map((entry) =>
    entry.types.includes('comment')
      ? {
          ...entry,
          style: {
            ...entry.style,
            color: '#505050',
          },
        }
      : entry,
  ),
};

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: labelRegistry.hveCore,
  tagline: 'AI-Driven Software Development Across the Full Lifecycle',
  favicon: 'img/microsoft-logo.svg',

  future: {
    v4: true,
  },

  url: 'https://microsoft.github.io',
  baseUrl: '/hve-core/',

  organizationName: 'microsoft',
  projectName: 'hve-core',

  onBrokenLinks: 'throw',

  customFields: {
    collectionCounts,
  },

  markdown: {
    format: 'detect',
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          path: '../',
          exclude: [
            'docusaurus/**',
            'announcements/**',
            '**/_*.{js,jsx,ts,tsx,md,mdx}',
            '**/_*/**',
            '**/*.test.{js,jsx,ts,tsx}',
            '**/__tests__/**',
          ],
          sidebarPath: './sidebars.js',
          showLastUpdateTime: true,
          showLastUpdateAuthor: true,
          editUrl: ({ docPath }) =>
            `https://github.com/microsoft/hve-core/tree/main/docs/${docPath}`,
          remarkPlugins: [remarkGithubAlert],
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themes: [
    [
      '@easyops-cn/docusaurus-search-local',
      /** @type {import("@easyops-cn/docusaurus-search-local").PluginOptions} */
      ({
        hashed: true,
        language: ['en'],
        highlightSearchTermsOnTargetPage: true,
        explicitSearchResultPath: true,
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/microsoft-logo.svg',
      colorMode: {
        respectPrefersColorScheme: true,
      },
      docs: {
        sidebar: {
          hideable: true,
          autoCollapseCategories: true,
        },
      },
      navbar: {
        title: labelRegistry.hveCore,
        logo: {
          alt: 'Microsoft',
          src: 'img/microsoft-logo.svg',
          width: 26,
          height: 26,
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: labelRegistry.documentation,
          },
          {
            type: 'dropdown',
            label: labelRegistry.topics,
            position: 'left',
            items: [
              { label: labelRegistry.gettingStarted, to: '/docs/getting-started/' },
              { label: labelRegistry.rpiWorkflow, to: '/docs/rpi/' },
              { label: labelRegistry.customizeAndExtend, to: '/docs/customization/' },
              { label: labelRegistry.architecture, to: '/docs/architecture/' },
            ],
          },
          {
            href: 'https://github.com/microsoft/hve-core',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: labelRegistry.documentation,
            items: [
              { label: labelRegistry.gettingStarted, to: '/docs/getting-started/' },
              { label: labelRegistry.hveGuide, to: '/docs/hve-guide/' },
              { label: labelRegistry.rpiWorkflow, to: '/docs/rpi/' },
              { label: labelRegistry.agents, to: '/docs/agents/' },
              { label: labelRegistry.architecture, to: '/docs/architecture/' },
            ],
          },
          {
            title: labelRegistry.resources,
            items: [
              { label: labelRegistry.accessibility, to: '/accessibility/' },
              { label: 'Report an accessibility issue', href: 'https://github.com/microsoft/hve-core/issues/new?labels=accessibility' },
              { label: 'Contributing', to: '/docs/contributing/' },
              { label: labelRegistry.security, to: '/docs/security/' },
              { label: labelRegistry.templates, to: '/docs/templates/' },
            ],
          },
          {
            title: labelRegistry.community,
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/microsoft/hve-core',
              },
            ],
          },
        ],
        copyright: `© Microsoft ${new Date().getFullYear()}. Built with ${labelRegistry.hveCoreExpanded}. Need help? Start with the documentation and the accessibility resources when available.`,
      },
      prism: {
        theme: accessibleGithubPrismTheme,
        darkTheme: prismThemes.dracula,
      },
    }),
};

export default config;
