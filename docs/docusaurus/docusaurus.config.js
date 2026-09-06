// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
// @ts-check
import { themes as prismThemes } from 'prism-react-renderer';
import remarkGithubAlert from 'remark-github-blockquote-alert';
import remarkDirective from 'remark-directive';
import * as path from 'path';
import { labelRegistry } from './src/data/labelRegistry';
import { loadPackageCards } from './src/data/pluginManifestCards';
import remarkTableCaption from './plugins/remark-table-caption.mjs';
import rehypeTableScope from './plugins/rehype-table-scope.mjs';

const packageCards = loadPackageCards(
  path.resolve(__dirname, '../../.github/plugin/marketplace.json'),
);

const accessibleGithubPrismTheme = {
  ...prismThemes.github,
  styles: prismThemes.github.styles.map((entry) =>
    entry.types.includes('comment') || entry.types.includes('url')
      ? {
          ...entry,
          style: {
            ...entry.style,
            color: entry.types.includes('comment') ? '#505050' : '#00756f',
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
    packageCards,
  },

  markdown: {
    format: 'detect',
    mermaid: true,
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
          remarkPlugins: [remarkGithubAlert, remarkDirective, remarkTableCaption],
          rehypePlugins: [rehypeTableScope],
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themes: [
    '@docusaurus/theme-mermaid',
    [
      '@easyops-cn/docusaurus-search-local',
      /** @type {import("@easyops-cn/docusaurus-search-local").PluginOptions} */
      ({
        hashed: true,
        docsDir: '../',
        indexBlog: false,
        language: ['en'],
        // Disabled: highlighting search terms on the target page injects <mark>
        // elements and auto-scrolls to them, which disrupts screen readers
        // (spurious "highlight" announcements + focus/scroll jumps) with no
        // keyboard affordance to dismiss it.
        highlightSearchTermsOnTargetPage: false,
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
      mermaid: {
        theme: { light: 'neutral', dark: 'dark' },
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
