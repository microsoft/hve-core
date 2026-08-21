// Copyright (c) 2026 Microsoft Corporation. All rights reserved.
// SPDX-License-Identifier: MIT
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, '../../..');
const openingFencePattern = /^\s*(`{3,}|~{3,})mermaid(?:\s+.*)?$/;

function normalizePath(filePath) {
  return filePath.replaceAll('\\', '/');
}

export function isDeployedDocumentationFile(filePath) {
  const normalized = normalizePath(filePath);
  const segments = normalized.split('/');
  const basename = segments.at(-1) ?? '';

  return normalized.startsWith('docs/')
    && !normalized.startsWith('docs/docusaurus/')
    && !normalized.startsWith('docs/announcements/')
    && !segments.some((segment, index) => index > 0 && segment.startsWith('_'))
    && /\.(?:md|mdx)$/i.test(basename);
}

export function discoverDocumentationFiles() {
  const output = execFileSync('git', ['ls-files', '--', 'docs'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  });

  return output
    .split(/\r?\n/)
    .filter(Boolean)
    .map(normalizePath)
    .filter(isDeployedDocumentationFile)
    .sort();
}

export function extractMermaidFences(content, file = '<memory>') {
  const lines = content.split(/\r?\n/);
  const fences = [];

  for (let index = 0; index < lines.length; index += 1) {
    const openingMatch = lines[index].match(openingFencePattern);
    if (!openingMatch) {
      continue;
    }

    const marker = openingMatch[1][0];
    const minimumLength = openingMatch[1].length;
    const closingPattern = new RegExp(`^\\s*${marker}{${minimumLength},}\\s*$`);
    const startLine = index + 1;
    const sourceLines = [];
    let closed = false;

    for (index += 1; index < lines.length; index += 1) {
      if (closingPattern.test(lines[index])) {
        closed = true;
        break;
      }
      sourceLines.push(lines[index]);
    }

    if (!closed) {
      throw new Error(`${file}:${startLine}: Mermaid fence is not closed`);
    }

    fences.push({
      file,
      startLine,
      source: sourceLines.join('\n'),
    });
  }

  return fences;
}

function activeSourceLines(source) {
  return source.split(/\r?\n/).filter((line) => !/^\s*%%/.test(line));
}

export function validateSourceMetadata(source) {
  const lines = activeSourceLines(source);
  const titleDirectives = [];
  const descriptionDirectives = [];

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const titleMatch = line.match(/^\s*accTitle\s*:\s*(.*)$/);
    if (titleMatch) {
      titleDirectives.push(titleMatch[1].trim());
      continue;
    }

    const descriptionMatch = line.match(/^\s*accDescr\s*:\s*(.*)$/);
    if (descriptionMatch) {
      descriptionDirectives.push(descriptionMatch[1].trim());
      continue;
    }

    if (/^\s*accDescr\s*\{\s*$/.test(line)) {
      const descriptionLines = [];
      let closed = false;
      for (index += 1; index < lines.length; index += 1) {
        if (/^\s*}\s*$/.test(lines[index])) {
          closed = true;
          break;
        }
        descriptionLines.push(lines[index].trim());
      }
      if (!closed) {
        throw new Error('accDescr block is not closed');
      }
      descriptionDirectives.push(descriptionLines.join(' ').trim());
    }
  }

  if (titleDirectives.length !== 1) {
    throw new Error(`expected exactly one active accTitle directive, found ${titleDirectives.length}`);
  }
  if (!titleDirectives[0]) {
    throw new Error('accTitle must contain authored text on the directive line');
  }
  if (descriptionDirectives.length !== 1) {
    throw new Error(`expected exactly one active accDescr directive, found ${descriptionDirectives.length}`);
  }
  if (!descriptionDirectives[0]) {
    throw new Error('accDescr must contain authored text');
  }

  return {
    title: titleDirectives[0],
    description: descriptionDirectives[0],
  };
}

export function collectInventory() {
  const failures = [];
  const fences = [];

  for (const file of discoverDocumentationFiles()) {
    const absolutePath = path.join(repositoryRoot, file);
    for (const fence of extractMermaidFences(readFileSync(absolutePath, 'utf8'), file)) {
      try {
        const metadata = validateSourceMetadata(fence.source);
        fences.push({ ...fence, ...metadata });
      } catch (error) {
        failures.push(`${fence.file}:${fence.startLine}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  }

  return { failures, fences };
}

async function main() {
  const { failures, fences } = collectInventory();
  if (failures.length > 0) {
    console.error(`Mermaid source accessibility validation failed: ${fences.length + failures.length} fences, ${failures.length} failures`);
    for (const failure of failures) {
      console.error(`- ${failure}`);
    }
    process.exitCode = 1;
    return;
  }

  if (process.argv.includes('--json')) {
    process.stdout.write(JSON.stringify(fences));
    return;
  }

  console.log(`Mermaid source accessibility validation passed: ${fences.length} fences have active authored titles and descriptions`);
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : '';
if (invokedPath === import.meta.url) {
  await main();
}
