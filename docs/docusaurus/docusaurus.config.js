// @ts-check
import {themes as prismThemes} from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'HVE Core',
  tagline: 'AI-Driven Software Development Across the Full Lifecycle',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://jakkaj.github.io',
  baseUrl: '/hve-core/',

  organizationName: 'jakkaj',
  projectName: 'hve-core',

  onBrokenLinks: 'throw',

  markdown: {
    mermaid: true,
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
          sidebarPath: './sidebars.js',
          showLastUpdateTime: true,
          showLastUpdateAuthor: true,
          editUrl:
            'https://github.com/microsoft/hve-core/tree/main/docs/docusaurus/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themes: ['@docusaurus/theme-mermaid'],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/docusaurus-social-card.jpg',
      announcementBar: {
        id: 'draft_notice',
        content: '⚠️ <strong>Draft Content</strong> — This documentation site is under active development. Content is preliminary and subject to change.',
        backgroundColor: '#fff3cd',
        textColor: '#664d03',
        isCloseable: false,
      },
      colorMode: {
        respectPrefersColorScheme: true,
      },
      navbar: {
        title: 'HVE Core',
        logo: {
          alt: 'Microsoft',
          src: 'img/microsoft-logo.svg',
          width: 24,
          height: 24,
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            type: 'dropdown',
            label: 'Topics',
            position: 'left',
            items: [
              { label: 'Agents & Prompts', to: '/docs/category/agents-and-prompts' },
              { label: 'Workflows', to: '/docs/category/workflows' },
              { label: 'Design Thinking', to: '/docs/category/design-thinking' },
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
            title: 'Documentation',
            items: [
              {
                label: 'Introduction',
                to: '/docs/intro',
              },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/microsoft/hve-core',
              },
              {
                label: 'Contributing',
                href: 'https://github.com/microsoft/hve-core/blob/main/CONTRIBUTING.md',
              },
            ],
          },
        ],
        copyright: `© Microsoft ${new Date().getFullYear()}. Built with HVE.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
      },
    }),
};

export default config;
