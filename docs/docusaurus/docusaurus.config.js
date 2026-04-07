// @ts-check
import { themes as prismThemes } from 'prism-react-renderer';
import remarkGithubAlert from 'remark-github-blockquote-alert';
import * as fs from 'fs';
import * as path from 'path';

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
  'project-planning', 'rai-planning', 'security', 'hve-core-all',
];
const collectionCounts = Object.fromEntries(
  collectionNames.map((n) => [n, countYamlPaths(n)]),
);

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'HVE Core',
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
        title: 'HVE Core',
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
            label: 'Documentation',
          },
          {
            type: 'dropdown',
            label: 'Topics',
            position: 'left',
            items: [
              { label: 'Get Started', to: '/docs/getting-started/' },
              { label: 'Workflows', to: '/docs/rpi/' },
              { label: 'Customize', to: '/docs/customization/' },
              { label: 'Reference', to: '/docs/architecture/' },
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
              { label: 'Getting Started', to: '/docs/getting-started/' },
              { label: 'HVE Guide', to: '/docs/hve-guide/' },
              { label: 'RPI Workflow', to: '/docs/rpi/' },
              { label: 'Agents', to: '/docs/agents/' },
              { label: 'Architecture', to: '/docs/architecture/' },
            ],
          },
          {
            title: 'Resources',
            items: [
              { label: 'Contributing', to: '/docs/contributing/' },
              { label: 'Security', to: '/docs/security/' },
              { label: 'Templates', to: '/docs/templates/' },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/microsoft/hve-core',
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
