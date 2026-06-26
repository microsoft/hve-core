// @ts-check
import { themes as prismThemes } from 'prism-react-renderer';
import remarkGithubAlert from 'remark-github-blockquote-alert';
import * as fs from 'fs';
import * as path from 'path';

const coreManifestPath = path.resolve(__dirname, '../../collections/core-manifest.yml');

/**
 * Counts shippable artifacts per collection from the central manifest.
 *
 * Mirrors the in-memory projection used elsewhere in the repo: an artifact
 * counts toward a collection when its `collections` membership includes the
 * collection id and its maturity is shippable (stable, preview, or
 * experimental). Deprecated, removed, or unknown maturities are excluded.
 *
 * @returns {Record<string, number>}
 */
function computeCollectionCounts() {
  let content;
  try {
    content = fs.readFileSync(coreManifestPath, 'utf-8');
  } catch {
    throw new Error(
      `[docusaurus.config.js] Cannot read core manifest: ${coreManifestPath}\n` +
      'Ensure collections/core-manifest.yml exists in the collections/ directory.',
    );
  }

  const artifactSections = new Set(['agents', 'prompts', 'instructions', 'skills']);
  const shippableMaturities = new Set(['stable', 'preview', 'experimental']);
  /** @type {Record<string, number>} */
  const counts = {};

  let inArtifactSection = false;
  /** @type {string | null} */
  let currentMaturity = null;
  /** @type {string[]} */
  let currentCollections = [];
  let collectingCollections = false;

  const flush = () => {
    if (currentMaturity && shippableMaturities.has(currentMaturity)) {
      for (const id of currentCollections) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    currentMaturity = null;
    currentCollections = [];
    collectingCollections = false;
  };

  for (const line of content.split(/\r?\n/)) {
    const topLevel = line.match(/^([A-Za-z][\w-]*):\s*$/);
    if (topLevel) {
      flush();
      inArtifactSection = artifactSections.has(topLevel[1]);
      continue;
    }
    if (!inArtifactSection) {
      continue;
    }

    if (/^ {2}\S.*:\s*$/.test(line)) {
      flush();
      continue;
    }

    const maturityMatch = line.match(/^ {4}maturity:\s*(\S+)\s*$/);
    if (maturityMatch) {
      currentMaturity = maturityMatch[1].toLowerCase();
      collectingCollections = false;
      continue;
    }

    if (/^ {4}collections:\s*$/.test(line)) {
      collectingCollections = true;
      continue;
    }

    if (collectingCollections) {
      const item = line.match(/^ {4}- (\S+)\s*$/);
      if (item) {
        currentCollections.push(item[1]);
        continue;
      }
      collectingCollections = false;
    }
  }
  flush();

  return counts;
}

const collectionCounts = computeCollectionCounts();

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

  themes:
    /** @type {import('@docusaurus/types').PluginConfig[]} */ ([
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
    ]),

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
