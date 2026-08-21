// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import {
  extractMermaidFences,
  isDeployedDocumentationFile,
  validateSourceMetadata,
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

  test('rejects an unclosed Mermaid fence with its source location', () => {
    assert.throws(
      () => extractMermaidFences('```mermaid\nflowchart LR', 'docs/example.md'),
      /docs\/example\.md:1: Mermaid fence is not closed/,
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
