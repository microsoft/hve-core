// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { describe, test } from 'node:test';
import {
  buildGraphicsReviewTemplate,
  extractMermaidFences,
  groupRouteCases,
  isDeployedDocumentationFile,
  validateSourceMetadata,
  writeGraphicsReviewTemplate,
} from './validate-mermaid-accessibility.mjs';

describe('Mermaid source inventory', () => {
  test('matches the Docusaurus Markdown deployment boundary', () => {
    const deployedFiles = [
      'docs/example.md',
      'docs/guides/example.test.md',
      'docs/guides/example.spec.mdx',
    ];
    const excludedFiles = [
      'docs/announcements/example.md',
      'docs/docusaurus/example.md',
      'docs/_draft.md',
      'docs/guides/_draft/example.md',
      'docs/example.ts',
    ];

    for (const file of deployedFiles) {
      assert.equal(isDeployedDocumentationFile(file), true, file);
    }
    for (const file of excludedFiles) {
      assert.equal(isDeployedDocumentationFile(file), false, file);
    }
  });

  test('extracts fenced source with its file and opening line', () => {
    assert.deepEqual(
      extractMermaidFences(`Before

\`\`\`mermaid
flowchart LR
  accTitle: Example
  accDescr: A moves to B.
  A --> B
\`\`\`
`, 'docs/example.md'),
      [{
        file: 'docs/example.md',
        source: 'flowchart LR\n  accTitle: Example\n  accDescr: A moves to B.\n  A --> B',
        startLine: 3,
      }],
    );
  });

  test('ignores Mermaid examples nested inside a larger code fence', () => {
    assert.deepEqual(
      extractMermaidFences(`\`\`\`\`markdown
Example structure:

\`\`\`mermaid
flowchart LR
  accTitle: Nested example
  accDescr: A moves to B.
  A --> B
\`\`\`
\`\`\`\`
`, 'docs/example.md'),
      [],
    );
  });

  test('rejects an unclosed Mermaid fence with its source location', () => {
    assert.throws(
      () => extractMermaidFences('```mermaid\nflowchart LR', 'docs/example.md'),
      /docs\/example\.md:1: Mermaid fence is not closed/,
    );
  });
});

describe('Mermaid route inventory', () => {
  const documents = [
    {
      source: '@site/../planning/adrs/0001-long-title.md',
      permalink: '/hve-core/docs/planning/adrs/0001',
    },
    {
      source: '@site/../guides/example.md',
      permalink: '/hve-core/docs/guides/example',
    },
    {
      source: '@site/../guides/README.md',
      permalink: '/hve-core/docs/guides/',
    },
  ];

  test('groups fences by canonical Docusaurus permalink', () => {
    assert.deepEqual(
      groupRouteCases([
        { file: 'docs/planning/adrs/0001-long-title.md' },
        { file: 'docs/guides/example.md' },
        { file: 'docs/guides/example.md' },
        { file: 'docs/guides/README.md' },
      ], documents),
      [
        {
          name: 'docs/planning/adrs/0001-long-title.md',
          path: '/hve-core/docs/planning/adrs/0001',
          diagramCount: 1,
        },
        {
          name: 'docs/guides/example.md',
          path: '/hve-core/docs/guides/example',
          diagramCount: 2,
        },
        {
          name: 'docs/guides/README.md',
          path: '/hve-core/docs/guides/',
          diagramCount: 1,
        },
      ],
    );
  });

  test('rejects an inventory source without generated route metadata', () => {
    assert.throws(
      () => groupRouteCases([{ file: 'docs/missing.md' }], documents),
      /No Docusaurus permalink found for docs\/missing\.md/,
    );
  });
});

describe('Mermaid source metadata controls', () => {
  test('accepts one active title and multiline description', () => {
    assert.deepEqual(
      validateSourceMetadata(`flowchart LR
        accTitle: Valid metadata
        accDescr {
          A moves to B through
          an authored description block.
        }
        A --> B`),
      {
        title: 'Valid metadata',
        description: 'A moves to B through an authored description block.',
      },
    );
  });

  test('rejects a missing title', () => {
    assert.throws(
      () => validateSourceMetadata(`flowchart LR
        accDescr: A moves to B.
        A --> B`),
      /exactly one active accTitle directive, found 0/,
    );
  });

  test('rejects a description without a title', () => {
    assert.throws(
      () => validateSourceMetadata(`graph LR
        accDescr: A dependency points to its consumer.
        Dependency --> Consumer`),
      /exactly one active accTitle directive, found 0/,
    );
  });

  test('rejects a commented title', () => {
    assert.throws(
      () => validateSourceMetadata(`flowchart LR
        %% accTitle: Commented title
        accDescr: A moves to B.
        A --> B`),
      /exactly one active accTitle directive, found 0/,
    );
  });

  test('rejects an empty title before Mermaid statements can be consumed', () => {
    assert.throws(
      () => validateSourceMetadata(`flowchart LR
        accTitle:
        accDescr: A moves to B.
        A --> B`),
      /authored text on the directive line/,
    );
  });
});

describe('Mermaid graphics review template', () => {
  const fences = [
    {
      file: 'docs/example.md',
      startLine: 4,
      source: 'flowchart LR\n  accTitle: First diagram\n  accDescr: A reaches B.\n  A --> B',
      title: 'First diagram',
      description: 'A reaches B.',
    },
    {
      file: 'docs/example.md',
      startLine: 10,
      source: 'journey\n  accTitle: Second diagram\n  accDescr: A journey advances.\n  section Work',
      title: 'Second diagram',
      description: 'A journey advances.',
    },
  ];
  const documents = [{ source: '@site/../example.md', permalink: '/hve-core/docs/example' }];
  const source = '# Example\n\n## First context\n```mermaid\n...\n```\n\n## Second context\n```mermaid\n...\n```\n';

  test('renders stable source-order rows with observable and not-verified fields', () => {
    const first = buildGraphicsReviewTemplate(fences, documents, () => source);
    const second = buildGraphicsReviewTemplate(fences, documents, () => source);

    assert.equal(first, second);
    assert.match(first, /\| 1 \| docs\/example\.md \| Mermaid fence 1 \|/);
    assert.match(first, /\| 2 \| docs\/example\.md \| Mermaid fence 2 \|/);
    assert.match(first, /\| flowchart \| First diagram \| A reaches B\. \| First context \|/);
    assert.match(first, /\| journey \| Second diagram \| A journey advances\. \| Second context \|/);
    assert.equal((first.match(/\| not verified/g) ?? []).length, 18);
  });

  test('reports no drift and refuses to overwrite a verified disposition', () => {
    const root = mkdtempSync(path.join(tmpdir(), 'mermaid-review-'));
    const outputPath = path.join(root, 'review.md');
    const content = buildGraphicsReviewTemplate(fences, documents, () => source);

    try {
      assert.equal(writeGraphicsReviewTemplate(outputPath, content), 'Wrote');
      assert.equal(writeGraphicsReviewTemplate(outputPath, content, true), 'NoDrift');
      writeFileSync(outputPath, `${readFileSync(outputPath, 'utf8')}\n| verified pass |\n`, 'utf8');
      assert.throws(
        () => writeGraphicsReviewTemplate(outputPath, content),
        /Refusing to overwrite completed human dispositions/,
      );
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});